## What changes

<!-- Describe the change and why. Reference the issue: "Closes #123". English or Portuguese. -->

## Type

- [ ] Fix
- [ ] Feature
- [ ] Version bump (Docker/Compose/Go)
- [ ] Documentation
- [ ] Kernel

## Tested on

<!-- Phone, ROM/version, root manager. "Not tested on the phone" if that is the case. -->

## Checklist

- [ ] No binaries committed
- [ ] `module/` scripts compatible with Android's `sh` (no bashisms)
- [ ] `go test ./...` in `uidfw/` and `scripts/build-module.sh` pass
- [ ] [On-device test checklist](../blob/main/CONTRIBUTING.md#on-device-test-checklist) (changes to module/uidfw/kernel/versions)
- [ ] Documentation (English and Portuguese) and `CHANGELOG.md` updated
