# Atualizar a versão do Docker

As versões empacotadas ficam em [`versions.env`](../versions.env), com o SHA-256 de cada
download. Os binários vêm sempre das fontes oficiais:

- Docker Engine: `https://download.docker.com/linux/static/stable/aarch64/docker-X.Y.Z.tgz`
  ([notas de versão](https://docs.docker.com/engine/release-notes/))
- Docker Compose: `https://github.com/docker/compose/releases/download/vX.Y.Z/docker-compose-linux-aarch64`
  ([releases](https://github.com/docker/compose/releases))

## Para usuários: instalar uma versão nova

1. Baixe o zip novo nos [Releases](https://github.com/fortmea/docker-rosemary/releases).
2. Instale por cima pelo Magisk (não precisa remover o antigo) e reinicie.

Imagens, volumes, contêineres e `/data/docker/daemon.json` são mantidos. Contêineres com
política `restart` voltam sozinhos.

Antes de pular versões *major* do Docker, leia as notas de versão: mudanças no formato de
armazenamento ou opções removidas do `daemon.json` podem exigir ajustes. Para não perder
nada, faça backup de `/data/docker` antes (com o Docker parado):

```sh
su
dockerctl stop
tar -C /data -czf /sdcard/docker-backup.tgz docker
```

### Trocar só os binários, sem gerar zip

Útil para testar uma versão antes de existir release:

```sh
# no PC
curl -LO https://download.docker.com/linux/static/stable/aarch64/docker-X.Y.Z.tgz
adb push docker-X.Y.Z.tgz /data/local/tmp/
# no aparelho
su
dockerctl stop
tar -xzf /data/local/tmp/docker-X.Y.Z.tgz -C /data/adb/modules/docker/bin --strip-components=1
chmod 0755 /data/adb/modules/docker/bin/*
dockerctl start && docker version
```

Para o Compose, substitua `/data/adb/modules/docker/cli-plugins/docker-compose` pelo
`docker-compose-linux-aarch64` novo. A versão em `module.prop` continua a antiga até você
instalar um zip.

## Para mantenedores: publicar uma versão nova

```sh
scripts/bump-versions.sh                   # últimas versões estáveis do Docker e do Compose
# ou: scripts/bump-versions.sh 29.11.0 5.9.0
scripts/build-module.sh                    # gera out/docker-magisk-<versão>.zip
```

`bump-versions.sh` baixa os arquivos, calcula o SHA-256 (e confere o do Compose com o
publicado), atualiza `versions.env` e volta `MODULE_REVISION` para 1 quando a versão do
Docker muda. Se só os scripts do módulo mudaram, incremente `MODULE_REVISION` à mão.

Depois:

1. Instale o zip no aparelho e passe pelo [checklist de teste](../CONTRIBUTING.md#checklist-de-teste-no-aparelho).
2. Adicione a seção da versão no [`CHANGELOG.md`](../CHANGELOG.md) (o título deve ser
   `## [<docker>-<rev>]`, por exemplo `## [29.11.0-1]`).
3. Abra um PR. Depois do merge, crie a tag — o workflow
   [`release.yml`](../.github/workflows/release.yml) compila o zip e publica o release com
   as notas do changelog:
   ```sh
   git tag v29.11.0-1 && git push origin v29.11.0-1
   ```

O workflow recusa a tag se ela não bater com `versions.env` ou se faltar a seção no changelog.

## Atualizar o Go do docker-uidfw

Mude a linha `go` em [`uidfw/go.mod`](../uidfw/go.mod) e rode `go test ./...` em `uidfw/`.
O CI usa a mesma versão.
