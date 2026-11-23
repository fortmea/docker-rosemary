# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow
`<Docker version>-<module revision>`.

## [Unreleased]

### Added
- Homepage at https://fortmea.github.io/docker-rosemary/ (English and Portuguese).
- MMRL repository: add `https://fortmea.github.io/docker-rosemary/` in MMRL to install and
  update the module from there. `json/modules.json` is regenerated on every release.
- Documentation in English (now the default); the Portuguese version moved to `docs/pt-BR/`,
  `README.pt-BR.md`, `CONTRIBUTING.pt-BR.md` and `THIRD_PARTY.pt-BR.md`.
- The kernel's full license text (`rosemary-docker-kernel-GPL-2.0` and
  `rosemary-docker-kernel-Linux-syscall-note`) is attached to releases next to `COPYING`.

### Changed
- Module description in English.

## [29.10.0-4] - 2026-11-22

### Added
- Updates from the Magisk app: `updateJson` in `module.prop` and an `update.json` published
  with every release.
- Prebuilt kernel in releases (`rosemary-docker-Image.gz`, `.config`, SHA-256 and license),
  built by the release workflow with the same container as `kernel/build.sh`.

### Changed
- Docker's network pool leaves out `172.28.0.0/16` (Droidspaces' default NAT range).
  Applies to new installs only: the existing `daemon.json` is not overwritten. On an older
  install, copy `default-address-pools` from the module's `daemon.json` into
  `/data/docker/daemon.json` and run `dockerctl restart`.

### Fixed
- `kernel/build.sh` exited with SIGPIPE (141) when printing the kernel version.

## [29.10.0-3] - 2026-11-22

First public release.

### Added
- Docker Engine 29.10.0 and Docker Compose v5.8.0 (official static arm64 binaries).
- Magisk module (KernelSU/APatch compatible): `dockerd` in its own mount namespace,
  `docker`/`dockerctl` in PATH, data in `/data/docker`, autostart on boot.
- Kernel option check at install time.
- Policy routes for the `172.16.0.0/12` pool and automatic DNS (`net.sh`).
- `docker-uidfw`: allows container UIDs through Android's eBPF firewall.
- `ip-forward-no-drop` to keep hotspot/tethering working.
- Kernel config fragment (`kernel/docker.config`) and LineageOS kernel build script.
- Build (`scripts/build-module.sh`) and version bump (`scripts/bump-versions.sh`) scripts,
  CI and automatic releases.

[Unreleased]: https://github.com/fortmea/docker-rosemary/compare/v29.10.0-4...HEAD
[29.10.0-4]: https://github.com/fortmea/docker-rosemary/compare/v29.10.0-3...v29.10.0-4
[29.10.0-3]: https://github.com/fortmea/docker-rosemary/releases/tag/v29.10.0-3
