# Código de terceiros

[English](THIRD_PARTY.md) · **Português**

Este repositório contém apenas scripts, o código do `docker-uidfw` e documentação (licença
[MIT](LICENSE)). Nenhum binário de terceiros é commitado: eles são baixados das fontes
oficiais durante a montagem, com SHA-256 fixado em [`versions.env`](versions.env), ou
compilados pelo CI a partir do código oficial.

## Incluído no zip do módulo (releases)

| Componente | Arquivos no zip | Origem | Licença |
|---|---|---|---|
| Docker Engine (Moby), CLI, `docker-proxy` | `bin/dockerd`, `bin/docker`, `bin/docker-proxy` | [download.docker.com/linux/static/stable/aarch64](https://download.docker.com/linux/static/stable/aarch64/) · código: [moby/moby](https://github.com/moby/moby), [docker/cli](https://github.com/docker/cli) | Apache-2.0 ([texto](licenses/Apache-2.0.txt), [NOTICE](licenses/NOTICE-moby.txt)) |
| containerd, `ctr`, shim | `bin/containerd`, `bin/ctr`, `bin/containerd-shim-runc-v2` | mesmo tgz · [containerd/containerd](https://github.com/containerd/containerd) | Apache-2.0 |
| runc | `bin/runc` | mesmo tgz · [opencontainers/runc](https://github.com/opencontainers/runc) | Apache-2.0 |
| tini | `bin/docker-init` | mesmo tgz · [krallin/tini](https://github.com/krallin/tini) | MIT ([texto](licenses/MIT-tini.txt)) |
| Docker Compose | `cli-plugins/docker-compose` | [docker/compose releases](https://github.com/docker/compose/releases) | Apache-2.0 |
| docker-uidfw | `bin/docker-uidfw` | compilado de [`uidfw/`](uidfw/) com a biblioteca padrão do Go ([licença BSD](https://go.dev/LICENSE)) | MIT |

Os textos de licença vão dentro do zip em `licenses/`. "Docker" é marca da Docker, Inc.;
este projeto não é afiliado nem endossado por ela.

## Kernel compilado (releases)

| Componente | Arquivos no release | Código-fonte correspondente | Licença |
|---|---|---|---|
| Kernel Linux do LineageOS para MT6785 | `rosemary-docker-Image.gz`, `rosemary-docker.config` | [LineageOS/android_kernel_xiaomi_mt6785](https://github.com/LineageOS/android_kernel_xiaomi_mt6785), branch `lineage-24.0`, no commit indicado nas notas do release, com a configuração `rosemary-docker.config` (= `rosemary_defconfig` + [`kernel/docker.config`](kernel/docker.config)); compilado por [`kernel/build.sh`](kernel/build.sh) | GPL-2.0 (`rosemary-docker-kernel-COPYING` no release) |

## Usado, mas não redistribuído

| Componente | Uso | Origem | Licença |
|---|---|---|---|
| Clang r416183b | compilador do kernel | [LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b](https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b) | Apache-2.0 com exceção LLVM |
| Ubuntu 22.04 + pacotes de build | imagem do contêiner de compilação ([`kernel/Dockerfile`](kernel/Dockerfile)) | Docker Hub `ubuntu` | várias (livres) |
| Magisk / `magiskboot` | root e reempacotamento do boot | [topjohnwu/Magisk](https://github.com/topjohnwu/Magisk) | GPL-3.0 |
| LineageOS | sistema do aparelho | [lineageos.org](https://lineageos.org) | Apache-2.0 e outras |

## Componentes proprietários

Nenhum componente proprietário é necessário nem distribuído. O boot reempacotado é o do
próprio aparelho do usuário (ramdisk, DTB e cmdline são mantidos); firmwares e blobs do
vendor continuam os que vieram com a ROM instalada. Desbloquear o bootloader exige a
ferramenta oficial Mi Unlock da Xiaomi, obtida diretamente da Xiaomi.

Se você distribuir um `Image.gz`/`boot.img` compilado por você, a GPL-2.0 exige oferecer o
código-fonte correspondente: aponte para o commit do LineageOS usado e para a configuração,
como os releases deste projeto fazem.
