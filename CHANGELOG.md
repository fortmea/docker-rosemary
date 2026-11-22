# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/). Versões
seguem `<versão do Docker>-<revisão do módulo>`.

## [Não lançado]

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

[Não lançado]: https://github.com/fortmea/docker-rosemary/compare/v29.10.0-3...HEAD
[29.10.0-3]: https://github.com/fortmea/docker-rosemary/releases/tag/v29.10.0-3
