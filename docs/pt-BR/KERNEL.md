# Kernel

[English](../KERNEL.md) · **Português**

O kernel do LineageOS para o rosemary (Linux 4.19, `rosemary_defconfig`) não tem estas
opções, sem as quais o Docker não inicia ou não cria redes:

| Opção | Para quê |
|---|---|
| `CONFIG_SYSVIPC`, `CONFIG_POSIX_MQUEUE`, `CONFIG_IPC_NS` | namespace IPC de cada contêiner |
| `CONFIG_CGROUP_PIDS`, `CONFIG_CGROUP_DEVICE` | controladores de cgroup exigidos pelo runc |
| `CONFIG_NETFILTER_XT_MATCH_ADDRTYPE` | regras iptables de portas publicadas |

**O arquivo de configurações é [`kernel/docker.config`](../../kernel/docker.config)**: um
fragmento de Kconfig com essas opções e algumas recomendadas, cada uma comentada. Nenhum
patch de código é necessário, só configuração. Você pode baixar o kernel pronto ou compilar:

- **[Pronto](#1c-kernel-pronto-dos-releases)**: cada release traz o `Image.gz` compilado
  pelo CI a partir do branch `lineage-24.0` com esse fragmento. É o caminho mais rápido.
- **[Compilação automática](#1a-compilação-automática-contêiner)**: `kernel/build.sh` baixa o código e o
  compilador, aplica o fragmento, confere e compila. É o caminho testado.
- **[Compilação manual](#1b-compilação-manual)**: os mesmos passos à mão, em qualquer árvore de kernel
  (outra ROM, outro aparelho, um kernel customizado que você já usa).

## Código de terceiros usado

Nada disso é redistribuído aqui; o script baixa direto das fontes oficiais:

| Componente | Origem | Licença |
|---|---|---|
| Kernel | [LineageOS/android_kernel_xiaomi_mt6785](https://github.com/LineageOS/android_kernel_xiaomi_mt6785), branch `lineage-24.0` | GPL-2.0 |
| Clang r416183b (o mesmo que o LineageOS usa para este aparelho, `TARGET_KERNEL_CLANG_VERSION`) | [LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b](https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b) | Apache-2.0 com exceção LLVM |
| `magiskboot` (reempacotar o boot) | já incluído no Magisk instalado: `/data/adb/magisk/magiskboot` | GPL-3.0 |

Não há componentes proprietários envolvidos: o boot que você vai reempacotar é o do seu
próprio aparelho, e o ramdisk, DTB e cmdline dele são mantidos.

> **Por que só o kernel, e não um `boot.img` pronto?** O boot contém o ramdisk da sua build
> do LineageOS e do seu Magisk; um boot de outra pessoa pode não iniciar. Trocar só o kernel
> dentro do seu boot é mais seguro.

## 1a. Compilação automática (contêiner)

Precisa de ~15 GB livres e Docker (no macOS com Apple Silicon roda emulado como amd64,
mais lento — 30 a 90 min). Em um Linux x86_64 dá para rodar `kernel/build.sh` direto
(instale os pacotes do [`kernel/Dockerfile`](../../kernel/Dockerfile) e defina `WORK`/`HOST`).

```sh
cd docker-rosemary/kernel
docker build -t rosemary-kernel-builder .
docker run --rm -v rosemary-kernel:/work -v "$PWD":/host rosemary-kernel-builder
```

Resultado: `kernel/Image.gz` e `kernel/docker.built.config`. O script falha se alguma
opção do fragmento não ficar ativa.

Variáveis (passe com `-e`): `KERNEL_BRANCH` (padrão `lineage-24.0`; use o branch da sua
versão do LineageOS), `KERNEL_COMMIT` (opcional: um commit específico desse branch) e
`LOCALVERSION` (padrão `-docker`, aparece em `uname -r`).
Patches extras (`*.patch`) colocados em `kernel/patches/` são aplicados antes de compilar.

O volume `rosemary-kernel` guarda fontes e objetos; recompilações são incrementais e o
script atualiza o código para o último commit do branch (ou para `KERNEL_COMMIT`).

## 1b. Compilação manual

Em Linux x86_64 (Ubuntu/Debian; em outro sistema use o contêiner do `kernel/Dockerfile`
com `--entrypoint bash`).

**Dependências:**

```sh
sudo apt install make bc bison flex libssl-dev libelf-dev python3 cpio kmod git \
    binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi perl xz-utils gzip curl
```

**Código e compilador.** Use o branch da sua versão do LineageOS e o clang que a ROM usa
(`TARGET_KERNEL_CLANG_VERSION` no `BoardConfig.mk` do aparelho; para o rosemary, r416183b).
Outro clang pode compilar, mas também pode gerar um kernel que não inicia.

```sh
git clone --depth 1 -b lineage-24.0 https://github.com/LineageOS/android_kernel_xiaomi_mt6785 kernel
git clone --depth 1 -b lineage-20.0 https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b clang
export PATH=$PWD/clang/bin:$PATH
cd kernel
```

**Configuração.** Parta do defconfig do aparelho e mescle o fragmento:

```sh
MK="make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang \
    CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- CLANG_TRIPLE=aarch64-linux-gnu-"
$MK rosemary_defconfig
scripts/kconfig/merge_config.sh -m -O out out/.config /caminho/para/docker-rosemary/kernel/docker.config
scripts/config --file out/.config --set-str LOCALVERSION -docker
$MK olddefconfig
```

**Confira se tudo ficou ativo.** `olddefconfig` descarta *sem avisar* opções cujas
dependências não estão satisfeitas:

```sh
grep '^CONFIG_' /caminho/para/docker-rosemary/kernel/docker.config | while read -r l; do
    grep -qxF "$l" out/.config || echo "FALTANDO: $l"; done
```

Se algo faltar, `$MK menuconfig` e procure a opção com `/`: a tela mostra de quais outras
ela depende (`Depends on:`). Ative as dependências e confira de novo.

Opcional: o Docker mantém um verificador completo que classifica cada opção como
obrigatória ou opcional:

```sh
curl -fsSLO https://raw.githubusercontent.com/moby/moby/master/contrib/check-config.sh
bash check-config.sh out/.config
```

O script é feito para distribuições Linux comuns, então num kernel Android algumas opções
aparecem como `missing` sem impedir o Docker de rodar (por exemplo drivers de armazenamento
que o módulo não usa, `VXLAN`/`IP_VS` do Swarm). Use-o para descobrir o que falta e decidir;
o critério deste projeto é o `docker.config` e o
[checklist de teste](../../CONTRIBUTING.pt-BR.md#checklist-de-teste-no-aparelho).

**Compilar:**

```sh
$MK -j"$(nproc)" Image.gz
ls -l out/arch/arm64/boot/Image.gz
```

**Adaptar a outro aparelho ou kernel**: troque o repositório, o branch, o defconfig e o
clang pelos da sua ROM (todos estão no `BoardConfig.mk` da árvore do aparelho:
`TARGET_KERNEL_SOURCE`, `TARGET_KERNEL_CONFIG`, `TARGET_KERNEL_CLANG_VERSION`,
`BOARD_KERNEL_IMAGE_NAME`). O fragmento `docker.config` é o mesmo. Em kernels 5.x/GKI
várias opções já vêm ativas e algumas mudaram de nome; o `check-config.sh` mostra o que
falta.

**Alternativa sem `merge_config.sh`**: acrescente as linhas do fragmento ao final do
defconfig (`arch/arm64/configs/rosemary_defconfig`) e rode `$MK rosemary_defconfig`. Para
um kernel já em execução, `zcat /proc/config.gz > out/.config` é uma base, mas só use se
tiver certeza de que é do mesmo código-fonte.

## 1c. Kernel pronto dos Releases

Cada [release](https://github.com/fortmea/docker-rosemary/releases) inclui:

| Arquivo | Conteúdo |
|---|---|
| `rosemary-docker-Image.gz` | kernel compilado pelo [workflow de release](../../.github/workflows/release.yml) com o mesmo contêiner da compilação automática |
| `rosemary-docker.config` | configuração completa usada (`.config`) |
| `rosemary-docker-kernel.sha256` | SHA-256 dos dois |
| `rosemary-docker-kernel-COPYING`, `rosemary-docker-kernel-GPL-2.0`, `rosemary-docker-kernel-Linux-syscall-note` | licença do kernel, copiada da árvore compilada (as duas últimas a partir do release 29.10.0-5) |

As notas do release dizem de qual commit do `lineage-24.0` ele foi compilado. Ele serve
para o LineageOS 24 do rosemary; se a sua build for bem mais antiga ou mais nova que esse
commit, leia [Kernel e módulos do vendor](#kernel-e-módulos-do-vendor) e, se algo do
hardware falhar, compile você mesmo com o commit certo.

```sh
B=https://github.com/fortmea/docker-rosemary/releases/latest/download
curl -fLO $B/rosemary-docker-Image.gz -fLO $B/rosemary-docker.config -fLO $B/rosemary-docker-kernel.sha256
shasum -a 256 -c rosemary-docker-kernel.sha256
mkdir -p kernel && mv rosemary-docker-Image.gz kernel/Image.gz
```

Siga para o passo 2 (os comandos usam `kernel/Image.gz`).

Código-fonte correspondente: o repositório do LineageOS no commit indicado nas notas, mais
`rosemary-docker.config` (veja [THIRD_PARTY.md](../../THIRD_PARTY.pt-BR.md)).

## 2. Reempacotar o boot (no aparelho)

O aparelho é A/B; trabalhe com o slot ativo. Os comandos abaixo mantêm o ramdisk do Magisk,
então o root continua funcionando.

```sh
adb push kernel/Image.gz /data/local/tmp/
adb shell
su
cd /data/local/tmp
S=$(getprop ro.boot.slot_suffix)            # _a ou _b
dd if=/dev/block/by-name/boot$S of=boot$S-backup.img
mkdir -p kr && cd kr
/data/adb/magisk/magiskboot unpack ../boot$S-backup.img
/data/adb/magisk/magiskboot decompress ../Image.gz kernel   # substitui o kernel extraído
/data/adb/magisk/magiskboot repack ../boot$S-backup.img ../boot$S-docker.img
cd .. && rm -rf kr
exit; exit
```

`repack` recomprime o kernel no formato original e mantém DTB, ramdisk e cmdline.

**Copie o backup para o PC** antes de continuar (é o que salva o aparelho se não iniciar):

```sh
S=$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')
adb pull /data/local/tmp/boot$S-backup.img
adb pull /data/local/tmp/boot$S-docker.img
```

## 3. Gravar

```sh
adb reboot bootloader
fastboot flash boot$S boot$S-docker.img
fastboot reboot
```

Confira depois de iniciar:

```sh
adb shell uname -r                                            # contém -docker
adb shell su -c 'zcat /proc/config.gz' | grep -c -E 'CONFIG_(SYSVIPC|POSIX_MQUEUE|IPC_NS|CGROUP_PIDS|CGROUP_DEVICE|NETFILTER_XT_MATCH_ADDRTYPE)=y'   # 6
```

Teste também Wi-Fi, chamadas, câmera e carregamento antes de seguir.

## Reverter

Se o aparelho não iniciar (ou algo do hardware parar de funcionar), entre no fastboot
(desligado: **Volume −** + **Power**) e grave o backup:

```sh
fastboot flash boot$S boot$S-backup.img
fastboot reboot
```

## Após uma atualização do LineageOS

A OTA grava um boot novo (com o kernel padrão) no outro slot. Depois de atualizar:

1. Reinstale o Magisk no boot novo, se ainda não fez (Magisk → Instalar → "Instalar no slot
   inativo" antes de reiniciar, ou pelo método normal após a atualização).
2. Baixe o kernel do release mais recente (ou recompile: o script já puxa o último commit
   do branch) e repita os passos 2 e 3 com o boot do novo slot ativo.

Até lá, o módulo Docker fica instalado, mas o `dockerd` não inicia (veja `dockerctl logs`).

## Kernel e módulos do vendor

O kernel tem `CONFIG_MODVERSIONS`; módulos `.ko` carregados pelo vendor precisam bater com o
kernel. Compilar a partir do mesmo branch e de um commit próximo ao da sua build evita
problemas. Se depois de gravar algo deixar de funcionar (Wi-Fi, áudio, sensores), reverta e
compile o commit mais próximo da data da sua build (veja o histórico em
[github.com/LineageOS/android_kernel_xiaomi_mt6785/commits/lineage-24.0](https://github.com/LineageOS/android_kernel_xiaomi_mt6785/commits/lineage-24.0)):

```sh
docker run --rm -e KERNEL_COMMIT=<sha> -v rosemary-kernel:/work -v "$PWD":/host rosemary-kernel-builder
```
