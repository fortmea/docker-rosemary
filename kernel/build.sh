#!/usr/bin/env bash
# Compila o kernel do LineageOS para o rosemary com o fragmento docker.config.
# Roda dentro de um contêiner linux/amd64 (veja kernel/README.md); qualquer Linux x86_64
# com as dependências do Dockerfile também serve.
#
#   /work   volume persistente (fontes, clang, saída de compilação)
#   /host   este diretório (docker.config, patches/ opcionais; recebe Image.gz)
#
# Variáveis: KERNEL_BRANCH (padrão lineage-24.0), KERNEL_COMMIT (opcional: um commit
# desse branch em vez do mais recente), LOCALVERSION (padrão -docker).
set -euo pipefail

KERNEL_REPO=https://github.com/LineageOS/android_kernel_xiaomi_mt6785
KERNEL_BRANCH=${KERNEL_BRANCH:-lineage-24.0}
CLANG_REPO=https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b
CLANG_BRANCH=lineage-20.0
WORK=${WORK:-/work}
HOST=${HOST:-/host}

mkdir -p "$WORK"
if [ ! -x "$WORK/clang/bin/clang" ]; then
    rm -rf "$WORK/clang"
    git clone --depth 1 -b "$CLANG_BRANCH" "$CLANG_REPO" "$WORK/clang"
fi
if [ ! -d "$WORK/kernel" ]; then
    git init -q "$WORK/kernel"
    git -C "$WORK/kernel" remote add origin "$KERNEL_REPO"
fi
git -C "$WORK/kernel" fetch --depth 1 origin "${KERNEL_COMMIT:-$KERNEL_BRANCH}"
git -C "$WORK/kernel" reset -q --hard FETCH_HEAD
git -C "$WORK/kernel" clean -qfdx
echo "Kernel: $KERNEL_BRANCH @ $(git -C "$WORK/kernel" log -1 --format='%h %cs %s')"

cd "$WORK/kernel"
# Patches opcionais (não são necessários para o Docker); aplicação idempotente.
for p in "$HOST"/patches/*.patch; do
    [ -e "$p" ] || continue
    patch -p1 -R --dry-run -s < "$p" >/dev/null 2>&1 || patch -p1 -s < "$p"
done

export PATH=$WORK/clang/bin:$PATH
OUT=$WORK/out
M=(make -j"$(nproc)" O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang
   CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-
   CLANG_TRIPLE=aarch64-linux-gnu-)

"${M[@]}" rosemary_defconfig
scripts/kconfig/merge_config.sh -m -O "$OUT" "$OUT/.config" "$HOST/docker.config"
scripts/config --file "$OUT/.config" --set-str LOCALVERSION "${LOCALVERSION:--docker}"
"${M[@]}" olddefconfig

# merge_config/olddefconfig descartam em silêncio opções com dependências não satisfeitas.
MISSING=$(grep -E '^CONFIG_' "$HOST/docker.config" | while read -r l; do
    grep -qxF "$l" "$OUT/.config" || echo "$l"; done)
[ -z "$MISSING" ] || { echo "Opções que não ficaram ativas:"; echo "$MISSING"; exit 1; }

"${M[@]}" Image.gz
cp "$OUT/.config" "$HOST/docker.built.config"
cp "$OUT/arch/arm64/boot/Image.gz" "$HOST/Image.gz"
# Sem pipe: com pipefail, "strings | grep -m1" termina em SIGPIPE (141).
grep -a -o -m1 'Linux version [[:print:]]*' "$OUT/vmlinux"
echo "Pronto: kernel/Image.gz"
