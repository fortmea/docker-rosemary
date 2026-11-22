# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/). Versões
seguem `<versão do Docker>-<revisão do módulo>`.

## [Não lançado]

## [29.10.0-4] - 2026-11-22

### Incluído
- Atualização pelo app Magisk: `updateJson` no `module.prop` e `update.json` publicado em
  cada release.
- Kernel compilado nos releases (`rosemary-docker-Image.gz`, `.config`, SHA-256 e licença),
  feito pelo workflow de release com o mesmo contêiner de `kernel/build.sh`.

### Alterado
- O pool de redes do Docker deixa de fora `172.28.0.0/16` (faixa NAT padrão do Droidspaces).
  Vale só para instalações novas: o `daemon.json` existente não é sobrescrito. Numa
  instalação antiga, copie `default-address-pools` do `daemon.json` do módulo para
  `/data/docker/daemon.json` e rode `dockerctl restart`.

## [29.10.0-3] - 2026-11-22

Primeiro release público.

### Incluído
- Docker Engine 29.10.0 e Docker Compose v5.8.0 (binários estáticos oficiais arm64).
- Módulo Magisk (compatível com KernelSU/APatch): `dockerd` em mount namespace próprio,
  `docker`/`dockerctl` no PATH, dados em `/data/docker`, início automático no boot.
- Verificação das opções do kernel na instalação.
- Rotas por política para o pool `172.16.0.0/12` e DNS automático (`net.sh`).
- `docker-uidfw`: libera UIDs de contêineres no firewall eBPF do Android.
- `ip-forward-no-drop` para manter hotspot/ancoragem funcionando.
- Fragmento de kernel (`kernel/docker.config`) e script de compilação do kernel LineageOS.
- Scripts de montagem (`scripts/build-module.sh`) e atualização de versões
  (`scripts/bump-versions.sh`), CI e release automático.

[Não lançado]: https://github.com/fortmea/docker-rosemary/compare/v29.10.0-4...HEAD
[29.10.0-4]: https://github.com/fortmea/docker-rosemary/compare/v29.10.0-3...v29.10.0-4
[29.10.0-3]: https://github.com/fortmea/docker-rosemary/releases/tag/v29.10.0-3
