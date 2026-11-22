# Kernel

O kernel do LineageOS para o rosemary (Linux 4.19, `rosemary_defconfig`) não tem estas
opções, sem as quais o Docker não inicia ou não cria redes:

| Opção | Para quê |
|---|---|
| `CONFIG_SYSVIPC`, `CONFIG_POSIX_MQUEUE`, `CONFIG_IPC_NS` | namespace IPC de cada contêiner |
| `CONFIG_CGROUP_PIDS`, `CONFIG_CGROUP_DEVICE` | controladores de cgroup exigidos pelo runc |
| `CONFIG_NETFILTER_XT_MATCH_ADDRTYPE` | regras iptables de portas publicadas |

[`kernel/docker.config`](../kernel/docker.config) traz essas e mais algumas recomendadas.
Nenhum patch de código é necessário — só configuração.

## Código de terceiros usado

Nada disso é redistribuído aqui; o script baixa direto das fontes oficiais:

| Componente | Origem | Licença |
|---|---|---|
| Kernel | [LineageOS/android_kernel_xiaomi_mt6785](https://github.com/LineageOS/android_kernel_xiaomi_mt6785), branch `lineage-24.0` | GPL-2.0 |
| Clang r416183b (o mesmo que o LineageOS usa para este aparelho, `TARGET_KERNEL_CLANG_VERSION`) | [LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b](https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b) | Apache-2.0 com exceção LLVM |
| `magiskboot` (reempacotar o boot) | já incluído no Magisk instalado: `/data/adb/magisk/magiskboot` | GPL-3.0 |

Não há componentes proprietários envolvidos: o boot que você vai reempacotar é o do seu
próprio aparelho, e o ramdisk, DTB e cmdline dele são mantidos.

> **Por que não há `boot.img` pronto nos releases?** O boot contém o ramdisk da sua build do
> LineageOS e do seu Magisk; um boot de outra pessoa pode não iniciar. Trocar só o kernel
> dentro do seu boot é mais seguro.

## 1. Compilar

Precisa de ~15 GB livres e Docker (no macOS com Apple Silicon roda emulado como amd64,
mais lento — 30 a 90 min). Em um Linux x86_64 dá para rodar `kernel/build.sh` direto
(instale os pacotes do [`kernel/Dockerfile`](../kernel/Dockerfile) e defina `WORK`/`HOST`).

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
adb shell uname -r                                            # termina em -docker
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
2. Recompile o kernel (o script já puxa o último commit do branch) e repita os passos 2 e 3
   com o boot do novo slot ativo.

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
