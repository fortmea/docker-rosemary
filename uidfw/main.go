// docker-uidfw: exempts the UIDs used by Docker container processes from Android's
// eBPF network allowlist chains (restricted networking mode, background, doze,
// power save, low-power standby). Android treats every UID >= 10000 as an app and
// drops its traffic unless the UID has the chain's allow bit in netd's
// uid_owner_map; container users such as 65532 (distroless "nonroot") never get it.
//
// Portable across Android versions: the map path, its value layout and the chain
// bit positions are detected at runtime (the bits moved between Connectivity
// mainline trains; e.g. bit 6 is IIF_MATCH on S but LOW_POWER_STANDBY on T+, and
// setting a deny/IIF bit would cut the UID off). Unknown layouts fall back to the
// bits that never moved (doze, power save) or to doing nothing.
//
// Only UIDs of processes in Docker cgroups (v1 or v2) are touched, and never a UID
// that belongs to an installed package, so per-app network blocks keep working.
// The system may rewrite the map (e.g. on package changes); the loop re-applies.
package main

import (
	"bufio"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

var mapPaths = []string{
	"/sys/fs/bpf/netd_shared/map_netd_uid_owner_map", // Android 13+ (Connectivity mainline)
	"/sys/fs/bpf/map_netd_uid_owner_map",             // Android 10-12 (netd)
}

const (
	pkgList = "/data/system/packages.list"

	sysBPF        = 280 // arm64
	bpfLookupElem = 1
	bpfUpdateElem = 2
	bpfObjGet     = 7
	bpfObjGetInfo = 15

	// Allowlist chain bits (packages/modules/Connectivity bpf_shared.h).
	dozableMatch    = 1 << 2  // all versions
	powersaveMatch  = 1 << 4  // all versions
	restrictedMatch = 1 << 5  // S+ (train 31); IIF_MATCH on R
	lowPowerMatch   = 1 << 6  // T+ (train 33); IIF_MATCH on S
	backgroundMatch = 1 << 12 // V+ (train 35)

	appStart = 10000
)

// allowBitsFor maps the Connectivity (tethering APEX) train to its allowlist bits.
func allowBitsFor(train int) uint32 {
	b := uint32(dozableMatch | powersaveMatch)
	if train >= 31 {
		b |= restrictedMatch
	}
	if train >= 33 {
		b |= lowPowerMatch
	}
	if train >= 35 {
		b |= backgroundMatch
	}
	return b
}

// connectivityTrain returns the first two digits of the tethering APEX versionCode
// (e.g. 370399999 -> 37), falling back to the platform SDK level.
func connectivityTrain() int {
	out, _ := exec.Command("/system/bin/pm", "list", "packages", "--apex-only", "--show-versioncode").Output()
	for _, line := range strings.Split(string(out), "\n") {
		if strings.Contains(line, "tethering") {
			if i := strings.Index(line, "versionCode:"); i >= 0 {
				if v, err := strconv.Atoi(strings.TrimSpace(line[i+12:])); err == nil && v >= 100000000 {
					return v / 10000000
				}
			}
		}
	}
	sdk, _ := exec.Command("/system/bin/getprop", "ro.build.version.sdk").Output()
	v, _ := strconv.Atoi(strings.TrimSpace(string(sdk)))
	return v
}

type uidOwnerValue struct {
	Iif  uint32
	Rule uint32
}

func bpf(cmd uintptr, attr unsafe.Pointer, size uintptr) (uintptr, error) {
	r, _, e := syscall.Syscall(sysBPF, cmd, uintptr(attr), size)
	if e != 0 {
		return r, e
	}
	return r, nil
}

func objGet(path string) (uint32, error) {
	p, err := syscall.BytePtrFromString(path)
	if err != nil {
		return 0, err
	}
	attr := struct {
		Pathname uint64
		Fd       uint32
		Flags    uint32
	}{Pathname: uint64(uintptr(unsafe.Pointer(p)))}
	fd, err := bpf(bpfObjGet, unsafe.Pointer(&attr), unsafe.Sizeof(attr))
	return uint32(fd), err
}

// openMap opens netd's uid owner map and checks it has the expected
// key (uint32 uid) and value ({uint32 iif; uint32 rule}) sizes.
func openMap() (uint32, string, error) {
	for _, path := range mapPaths {
		if _, err := os.Stat(path); err != nil {
			continue
		}
		fd, err := objGet(path)
		if err != nil {
			return 0, path, err
		}
		var info struct {
			Type, ID, KeySize, ValueSize, MaxEntries, Flags uint32
			_                                               [64]byte
		}
		attr := struct {
			Fd      uint32
			InfoLen uint32
			Info    uint64
		}{Fd: fd, InfoLen: uint32(unsafe.Sizeof(info)), Info: uint64(uintptr(unsafe.Pointer(&info)))}
		if _, err := bpf(bpfObjGetInfo, unsafe.Pointer(&attr), unsafe.Sizeof(attr)); err != nil {
			return 0, path, err
		}
		if info.KeySize != 4 || info.ValueSize != 8 {
			return 0, path, fmt.Errorf("unexpected layout key=%d value=%d", info.KeySize, info.ValueSize)
		}
		return fd, path, nil
	}
	return 0, "", fmt.Errorf("uid owner map not found (no eBPF firewall: nothing to do)")
}

type elemAttr struct {
	MapFd uint32
	_     uint32
	Key   uint64
	Value uint64
	Flags uint64
}

func lookup(fd, uid uint32) (uidOwnerValue, bool, error) {
	var v uidOwnerValue
	a := elemAttr{MapFd: fd, Key: uint64(uintptr(unsafe.Pointer(&uid))), Value: uint64(uintptr(unsafe.Pointer(&v)))}
	_, err := bpf(bpfLookupElem, unsafe.Pointer(&a), unsafe.Sizeof(a))
	if err == syscall.ENOENT {
		return v, false, nil
	}
	return v, err == nil, err
}

func update(fd, uid uint32, v uidOwnerValue) error {
	a := elemAttr{MapFd: fd, Key: uint64(uintptr(unsafe.Pointer(&uid))), Value: uint64(uintptr(unsafe.Pointer(&v)))}
	_, err := bpf(bpfUpdateElem, unsafe.Pointer(&a), unsafe.Sizeof(a))
	return err
}

// packageUIDs returns the app IDs of installed packages (never exempted).
func packageUIDs() map[uint32]bool {
	m := map[uint32]bool{}
	f, err := os.Open(pkgList)
	if err != nil {
		return m
	}
	defer f.Close()
	s := bufio.NewScanner(f)
	for s.Scan() {
		if fl := strings.Fields(s.Text()); len(fl) > 1 {
			if u, err := strconv.ParseUint(fl[1], 10, 32); err == nil {
				m[uint32(u)%100000] = true
			}
		}
	}
	return m
}

// dockerCgroupDirs returns "<mountpoint>/docker" for every cgroup v1/v2 mount.
func dockerCgroupDirs() []string {
	var dirs []string
	b, _ := os.ReadFile("/proc/self/mounts")
	for _, line := range strings.Split(string(b), "\n") {
		f := strings.Fields(line)
		if len(f) > 2 && (f[2] == "cgroup2" || f[2] == "cgroup") {
			if st, err := os.Stat(f[1] + "/docker"); err == nil && st.IsDir() {
				dirs = append(dirs, f[1]+"/docker")
			}
		}
	}
	return dirs
}

// containerUIDs returns real/effective/saved/fs UIDs of all processes in Docker cgroups.
func containerUIDs() map[uint32]bool {
	m := map[uint32]bool{}
	for _, dir := range dockerCgroupDirs() {
		walkProcs(dir, m)
	}
	return m
}

func walkProcs(dir string, m map[uint32]bool) {
	filepath.WalkDir(dir, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || d.Name() != "cgroup.procs" {
			return nil
		}
		b, _ := os.ReadFile(p)
		for _, pid := range strings.Fields(string(b)) {
			st, err := os.ReadFile("/proc/" + pid + "/status")
			if err != nil {
				continue
			}
			for _, line := range strings.Split(string(st), "\n") {
				if strings.HasPrefix(line, "Uid:") {
					for _, f := range strings.Fields(line)[1:] {
						if u, err := strconv.ParseUint(f, 10, 32); err == nil {
							m[uint32(u)] = true
						}
					}
					break
				}
			}
		}
		return nil
	})
}

func sync(fd uint32, allowBits uint32, pkgs map[uint32]bool) {
	for uid := range containerUIDs() {
		if uid%100000 < appStart || pkgs[uid%100000] {
			continue
		}
		v, _, err := lookup(fd, uid)
		if err != nil {
			fmt.Fprintf(os.Stderr, "lookup %d: %v\n", uid, err)
			continue
		}
		if v.Rule&allowBits == allowBits {
			continue
		}
		v.Rule |= allowBits
		if err := update(fd, uid, v); err != nil {
			fmt.Fprintf(os.Stderr, "update %d: %v\n", uid, err)
			continue
		}
		fmt.Printf("%s allowed uid %d\n", time.Now().Format(time.RFC3339), uid)
	}
}

func main() {
	fd, path, err := openMap()
	if err != nil {
		fmt.Fprintf(os.Stderr, "docker-uidfw: %s: %v\n", path, err)
		os.Exit(1)
	}
	train := connectivityTrain()
	allowBits := allowBitsFor(train)
	fmt.Printf("%s docker-uidfw: map %s, connectivity train %d, allow bits %#x\n",
		time.Now().Format(time.RFC3339), path, train, allowBits)
	if len(os.Args) > 1 && os.Args[1] == "once" {
		sync(fd, allowBits, packageUIDs())
		return
	}
	var pkgStamp time.Time
	var pkgs map[uint32]bool
	for {
		if fi, err := os.Stat(pkgList); err == nil && fi.ModTime() != pkgStamp {
			pkgStamp, pkgs = fi.ModTime(), packageUIDs()
		} else if pkgs == nil {
			pkgs = packageUIDs()
		}
		sync(fd, allowBits, pkgs)
		time.Sleep(3 * time.Second)
	}
}
