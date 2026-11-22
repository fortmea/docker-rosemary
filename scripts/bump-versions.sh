#!/usr/bin/env bash
# Atualiza versions.env para novas versões do Docker e/ou do Compose.
#
#   scripts/bump-versions.sh                 # últimas versões estáveis
#   scripts/bump-versions.sh 29.11.0         # Docker específico, Compose mais recente
#   scripts/bump-versions.sh 29.11.0 5.9.0   # ambos específicos
#
# O SHA-256 do Docker é calculado sobre o tgz baixado de download.docker.com (o site não
# publica checksums); o do Compose é conferido contra o .sha256 publicado no release.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../versions.env
. "$ROOT/versions.env"
OLD_DOCKER=$DOCKER_VERSION

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

NEW_DOCKER=${1:-$(curl -fsSL https://download.docker.com/linux/static/stable/aarch64/ |
    grep -oE 'docker-[0-9]+\.[0-9]+\.[0-9]+\.tgz' | sed 's/docker-//; s/\.tgz//' | sort -uV | tail -1)}
NEW_COMPOSE=${2:-$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest |
    sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')}
[[ $NEW_DOCKER =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Versão do Docker inválida: $NEW_DOCKER" >&2; exit 1; }
[[ $NEW_COMPOSE =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Versão do Compose inválida: $NEW_COMPOSE" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "- Docker $NEW_DOCKER"
curl -fL --retry 3 -o "$TMP/docker.tgz" \
    "https://download.docker.com/linux/static/stable/aarch64/docker-$NEW_DOCKER.tgz"
NEW_DOCKER_SHA=$(sha256 "$TMP/docker.tgz")

echo "- Compose $NEW_COMPOSE"
BASE=https://github.com/docker/compose/releases/download/v$NEW_COMPOSE/docker-compose-linux-aarch64
curl -fL --retry 3 -o "$TMP/compose" "$BASE"
NEW_COMPOSE_SHA=$(sha256 "$TMP/compose")
PUBLISHED=$(curl -fsSL "$BASE.sha256" | cut -d' ' -f1)
[ "$PUBLISHED" = "$NEW_COMPOSE_SHA" ] || { echo "! SHA-256 do Compose não confere com o publicado" >&2; exit 1; }

REV=$MODULE_REVISION
[ "$NEW_DOCKER" = "$OLD_DOCKER" ] || REV=1

sed -i.bak \
    -e "s/^DOCKER_VERSION=.*/DOCKER_VERSION=$NEW_DOCKER/" \
    -e "s/^DOCKER_SHA256=.*/DOCKER_SHA256=$NEW_DOCKER_SHA/" \
    -e "s/^COMPOSE_VERSION=.*/COMPOSE_VERSION=$NEW_COMPOSE/" \
    -e "s/^COMPOSE_SHA256=.*/COMPOSE_SHA256=$NEW_COMPOSE_SHA/" \
    -e "s/^MODULE_REVISION=.*/MODULE_REVISION=$REV/" \
    "$ROOT/versions.env"
rm -f "$ROOT/versions.env.bak"

echo "- versions.env atualizado:"
grep -v '^#' "$ROOT/versions.env"
echo "Próximos passos: scripts/build-module.sh, testar no aparelho, atualizar CHANGELOG.md."
