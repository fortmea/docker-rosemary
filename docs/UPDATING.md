# Updating Docker

**English** · [Português](pt-BR/ATUALIZAR.md)

The packaged versions live in [`versions.env`](../versions.env), with the SHA-256 of every
download. The binaries always come from the official sources:

- Docker Engine: `https://download.docker.com/linux/static/stable/aarch64/docker-X.Y.Z.tgz`
  ([release notes](https://docs.docker.com/engine/release-notes/))
- Docker Compose: `https://github.com/docker/compose/releases/download/vX.Y.Z/docker-compose-linux-aarch64`
  ([releases](https://github.com/docker/compose/releases))

## For users: installing a new version

Magisk → Modules → **Update** on the Docker module, then reboot (from 29.10.0-4 on; the app
reads the latest release's `update.json`). If you added the repository in MMRL, update from
there instead.

Or by hand: download the new zip from [Releases](https://github.com/fortmea/docker-rosemary/releases),
install it over the old one in Magisk (no need to remove it first) and reboot.

Images, volumes, containers and `/data/docker/daemon.json` are kept. Containers with a
`restart` policy come back on their own.

Before skipping Docker *major* versions, read the release notes: storage format changes or
options removed from `daemon.json` may need adjustments. To be safe, back up `/data/docker`
first (with Docker stopped):

```sh
su
dockerctl stop
tar -C /data -czf /sdcard/docker-backup.tgz docker
```

### Swapping only the binaries, without a zip

Useful to try a version before a release exists:

```sh
# on the computer
curl -LO https://download.docker.com/linux/static/stable/aarch64/docker-X.Y.Z.tgz
adb push docker-X.Y.Z.tgz /data/local/tmp/
# on the phone
su
dockerctl stop
tar -xzf /data/local/tmp/docker-X.Y.Z.tgz -C /data/adb/modules/docker/bin --strip-components=1
chmod 0755 /data/adb/modules/docker/bin/*
dockerctl start && docker version
```

For Compose, replace `/data/adb/modules/docker/cli-plugins/docker-compose` with the new
`docker-compose-linux-aarch64`. The version in `module.prop` stays the old one until you
install a zip.

## For maintainers: publishing a new version

```sh
scripts/bump-versions.sh                   # latest stable Docker and Compose
# or: scripts/bump-versions.sh 29.11.0 5.9.0
scripts/build-module.sh                    # builds out/docker-magisk-<version>.zip
```

`bump-versions.sh` downloads the files, computes the SHA-256 (and checks Compose's against the
published one), updates `versions.env` and resets `MODULE_REVISION` to 1 when the Docker
version changes. If only the module scripts changed, bump `MODULE_REVISION` by hand.

Then:

1. Install the zip on the phone and go through the [test checklist](../CONTRIBUTING.md#on-device-test-checklist).
2. Add the version's section to [`CHANGELOG.md`](../CHANGELOG.md) (the heading must be
   `## [<docker>-<rev>]`, for example `## [29.11.0-1]`).
3. Open a PR. After merging, create the tag. The
   [`release.yml`](../.github/workflows/release.yml) workflow builds the kernel (~15 min) and
   the zip, publishes the release with the changelog notes and the `update.json` the Magisk
   app reads, and then redeploys the homepage and the MMRL repository
   ([`pages.yml`](../.github/workflows/pages.yml)):
   ```sh
   git tag v29.11.0-1 && git push origin v29.11.0-1
   ```

The workflow refuses the tag if it does not match `versions.env` or if the changelog section
is missing.

## Homepage and MMRL repository

[`site/`](../site/) holds the homepage. `scripts/build-site.py` copies it and generates
`json/modules.json` (the MMRL repository index) and one changelog per version from the
GitHub releases and `CHANGELOG.md`. Preview locally:

```sh
GH_TOKEN=$(gh auth token) python3 scripts/build-site.py _site
python3 -m http.server -d _site 8000
```

## Updating the Go used by docker-uidfw

Change the `go` line in [`uidfw/go.mod`](../uidfw/go.mod) and run `go test ./...` in `uidfw/`.
CI uses the same version.
