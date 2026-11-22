#!/usr/bin/env bash
# Monta o zip do módulo Magisk: baixa os binários estáticos oficiais do Docker e do
# Compose (versões e SHA-256 fixados em versions.env), compila o docker-uidfw e
# empacota tudo com os scripts de module/.
#
# Requisitos: bash, curl, tar, zip, go (versão de uidfw/go.mod), sha256sum ou shasum.
# Saída: out/docker-magisk-<docker>-<rev>.zip e o .sha256 correspondente.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../versions.env
. "$ROOT/versions.env"

CACHE=$ROOT/build/cache
STAGE=$ROOT/build/stage
OUT=$ROOT/out
VERSION=$DOCKER_VERSION-$MODULE_REVISION
ZIP=$OUT/docker-magisk-$VERSION.zip

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

fetch() { # fetch <url> <arquivo> <sha256>
    local url=$1 file=$2 want=$3
    if [ ! -f "$file" ] || [ "$(sha256 "$file")" != "$want" ]; then
        echo "- Baixando $url"
        curl -fL --retry 3 -o "$file.part" "$url"
        mv "$file.part" "$file"
    fi
    local got
    got=$(sha256 "$file")
    if [ "$got" != "$want" ]; then
        echo "! SHA-256 não confere para $file" >&2
        echo "!   esperado $want" >&2
        echo "!   obtido   $got" >&2
        rm -f "$file"
        exit 1
    fi
}

mkdir -p "$CACHE" "$OUT"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/cli-plugins"

DOCKER_TGZ=$CACHE/docker-$DOCKER_VERSION.tgz
COMPOSE_BIN=$CACHE/docker-compose-$COMPOSE_VERSION-linux-aarch64
fetch "https://download.docker.com/linux/static/stable/aarch64/docker-$DOCKER_VERSION.tgz" \
    "$DOCKER_TGZ" "$DOCKER_SHA256"
fetch "https://github.com/docker/compose/releases/download/v$COMPOSE_VERSION/docker-compose-linux-aarch64" \
    "$COMPOSE_BIN" "$COMPOSE_SHA256"

echo "- Montando o módulo $VERSION"
cp -R "$ROOT/module/." "$STAGE/"
rm "$STAGE/module.prop.in"
tar -xzf "$DOCKER_TGZ" -C "$STAGE/bin" --strip-components=1
cp "$COMPOSE_BIN" "$STAGE/cli-plugins/docker-compose"
cp "$ROOT/README.md" "$ROOT/THIRD_PARTY.md" "$ROOT/LICENSE" "$STAGE/"
cp -R "$ROOT/licenses" "$STAGE/licenses"

echo "- Compilando docker-uidfw"
(cd "$ROOT/uidfw" && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
    go build -trimpath -ldflags '-s -w' -o "$STAGE/bin/docker-uidfw" .)

IFS=. read -r MA MI PA <<<"$DOCKER_VERSION"
VERSION_CODE=$((MA * 1000000 + MI * 10000 + PA * 100 + MODULE_REVISION))
sed -e "s/@DOCKER_VERSION@/$DOCKER_VERSION/g" \
    -e "s/@COMPOSE_VERSION@/$COMPOSE_VERSION/g" \
    -e "s/@MODULE_REVISION@/$MODULE_REVISION/g" \
    -e "s/@VERSION_CODE@/$VERSION_CODE/g" \
    "$ROOT/module/module.prop.in" > "$STAGE/module.prop"

chmod 0755 "$STAGE"/bin/* "$STAGE"/cli-plugins/* "$STAGE"/system/bin/* "$STAGE"/*.sh

rm -f "$ZIP"
(cd "$STAGE" && zip -q -r -X "$ZIP" .)
(cd "$OUT" && echo "$(sha256 "$ZIP")  ${ZIP##*/}" > "${ZIP##*/}.sha256")
echo "- Pronto: $ZIP"
cat "$ZIP.sha256"
