# Contributing

**English** · [Português](CONTRIBUTING.pt-BR.md)

Thanks for your interest! This is a small project maintained in spare time; focused
contributions tested on the device are the most useful.

## Before you start

- **Question or support?** Read [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) and search the
  [issues](https://github.com/fortmea/docker-rosemary/issues?q=is%3Aissue) (closed ones too).
- **Bug?** Open an issue with the "Bug" template and every output it asks for. Without logs
  it is hard to help.
- **Big change** (new feature, change in network behavior, support for another phone)? Open
  an issue first to discuss it.

Issues and PRs in English or Portuguese are both welcome.

## Layout

| Path | Contents |
|---|---|
| `module/` | Magisk module scripts (no binaries; the zip is built by `scripts/build-module.sh`) |
| `uidfw/` | `docker-uidfw` in Go (no external dependencies) |
| `kernel/` | config fragment and kernel build |
| `scripts/` | zip build, version bumps, site build |
| `site/` | homepage (published with the MMRL repository by `pages.yml`) |
| `versions.env` | Docker/Compose versions and SHA-256 |
| `docs/` | documentation (English; Portuguese in `docs/pt-BR/`) |

## Rules for changes

- **Do not commit binaries** (Docker, Compose, `docker-uidfw`, boot images, `Image.gz`).
  Everything is downloaded from an official source with pinned SHA-256 or built from source.
- **Module scripts run on Android's `sh` (mksh/toybox) and on the root manager's busybox.**
  No bashisms in `module/`. Use `$BB` (set in `common.sh`) for commands toybox lacks
  (`unshare`, `pivot_root`, `mount --make-rslave`...).
- **Nothing hardcoded for one phone or ROM**: detect at runtime (as `common.sh`, `net.sh`
  and `docker-uidfw` do).
- **Do not touch Android's namespace** beyond what is needed: `dockerd` runs isolated in
  `nsroot.sh`; network rules stay within the `172.16.0.0/12` pool.
- **Security**: `docker-uidfw` must never allow UIDs of installed apps; the daemon must not
  listen on TCP by default.
- User-facing messages (installer, `dockerctl`) are currently in Portuguese; code comments in
  English or Portuguese, following the file's style.
- Changed visible behavior? Update the documentation in both languages (if you cannot write
  one of them, say so in the PR) and `CHANGELOG.md` (section `## [Unreleased]`).

## Local checks

```sh
(cd uidfw && go vet ./... && go test ./...)
shellcheck -s sh module/*.sh module/system/bin/*     # optional, CI runs it at severity "error"
shellcheck scripts/*.sh kernel/build.sh
scripts/build-module.sh                              # the zip must build without errors
```

CI ([`ci.yml`](.github/workflows/ci.yml)) runs the same on every PR.

## On-device test checklist

For changes to `module/`, `uidfw/`, `kernel/` or versions, state the phone, the LineageOS
and root manager versions in the PR, and confirm:

- [ ] the zip installs from Magisk and the phone reboots normally
- [ ] `dockerctl status` shows Docker running after boot
- [ ] `docker run --rm hello-world`
- [ ] network + DNS + TLS: `docker run --rm alpine wget -qO- https://example.com`
- [ ] non-root user: `docker run --rm --user 65532 alpine wget -qO- https://example.com`
- [ ] published port reachable from another device on the network (`docker run -d -p 8080:80 nginx`)
- [ ] `docker compose up -d` with a simple file
- [ ] Wi-Fi reconnected (off/on) and container networking comes back within ~15 s
- [ ] Android hotspot keeps working with Docker running
- [ ] `dockerctl restart` and a phone reboot keep containers with `restart: unless-stopped`

## Commits and PRs

- One topic per PR; small commits with descriptive messages
  (suggestion: [Conventional Commits](https://www.conventionalcommits.org/), e.g.
  `fix(net): re-apply rule 6102 when the network changes`).
- Fill in the PR template.
- By contributing you agree to license your contribution under the project's
  [MIT license](LICENSE) (kernel patches in `kernel/patches/` follow the kernel's GPL-2.0).

## Releases

Done by the maintainer as described in [docs/UPDATING.md](docs/UPDATING.md#for-maintainers-publishing-a-new-version).

## Conduct

Be respectful and to the point. Personal attacks, harassment or spam lead to removal from
the project.
