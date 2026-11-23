# Como contribuir

[English](CONTRIBUTING.md) · **Português**

Obrigado pelo interesse! Issues e PRs em português ou inglês são bem-vindos. Este projeto é pequeno e mantido nas horas vagas; contribuições
focadas e testadas no aparelho são as mais úteis.

## Antes de começar

- **Dúvida ou suporte?** Leia [docs/PROBLEMAS.md](docs/pt-BR/PROBLEMAS.md) e procure nas
  [issues](https://github.com/fortmea/docker-rosemary/issues?q=is%3Aissue) (inclusive fechadas).
- **Bug?** Abra uma issue com o modelo "Bug" e todas as saídas pedidas. Sem logs fica
  difícil ajudar.
- **Mudança grande** (nova funcionalidade, mudança no comportamento de rede, suporte a outro
  aparelho)? Abra uma issue antes para discutir.

## Estrutura

| Caminho | Conteúdo |
|---|---|
| `module/` | scripts do módulo Magisk (sem binários; o zip é montado por `scripts/build-module.sh`) |
| `uidfw/` | `docker-uidfw` em Go (sem dependências externas) |
| `kernel/` | fragmento de configuração e build do kernel |
| `scripts/` | montagem do zip, atualização de versões e do site |
| `site/` | página inicial (publicada com o repositório MMRL pelo `pages.yml`) |
| `versions.env` | versões e SHA-256 do Docker/Compose |
| `docs/` | documentação (inglês; português em `docs/pt-BR/`) |

## Regras para mudanças

- **Não commite binários** (Docker, Compose, `docker-uidfw`, imagens de boot, `Image.gz`).
  Tudo é baixado de fonte oficial com SHA-256 fixado ou compilado a partir do código.
- **Scripts do módulo rodam no `sh` do Android (mksh/toybox) e no busybox do gerenciador de
  root.** Nada de bash-ismos em `module/`. Use `$BB` (definido em `common.sh`) para comandos
  que o toybox não tem (`unshare`, `pivot_root`, `mount --make-rslave`...).
- **Nada específico de um aparelho ou ROM fixo no código**: detecte em tempo de execução
  (como `common.sh`, `net.sh` e `docker-uidfw` fazem).
- **Não mexa no namespace do Android** além do necessário: o `dockerd` roda isolado em
  `nsroot.sh`; regras de rede ficam restritas ao pool `172.16.0.0/12`.
- **Segurança**: o `docker-uidfw` nunca pode liberar UIDs de apps instalados; o daemon não
  deve escutar em TCP por padrão.
- Mensagens para o usuário (instalador, `dockerctl`) em português; comentários de código em
  inglês ou português, mantendo o estilo do arquivo.
- Mudou comportamento visível? Atualize a documentação nos dois idiomas (se não conseguir
  escrever em um deles, avise no PR) e o `CHANGELOG.md` (em inglês, seção `## [Unreleased]`).

## Verificações locais

```sh
(cd uidfw && go vet ./... && go test ./...)
shellcheck -s sh module/*.sh module/system/bin/*     # opcional, o CI roda com severidade "error"
shellcheck scripts/*.sh kernel/build.sh
scripts/build-module.sh                              # o zip precisa ser gerado sem erro
```

O CI ([`ci.yml`](.github/workflows/ci.yml)) roda o mesmo em todo PR.

## Checklist de teste no aparelho

Para mudanças em `module/`, `uidfw/`, `kernel/` ou versões, descreva no PR o aparelho, a
versão do LineageOS e do gerenciador de root, e confirme:

- [ ] o zip instala pelo Magisk e o aparelho reinicia normalmente
- [ ] `dockerctl status` mostra o Docker rodando após o boot
- [ ] `docker run --rm hello-world`
- [ ] rede + DNS + TLS: `docker run --rm alpine wget -qO- https://example.com`
- [ ] usuário não-root: `docker run --rm --user 65532 alpine wget -qO- https://example.com`
- [ ] porta publicada acessível de outro dispositivo da rede (`docker run -d -p 8080:80 nginx`)
- [ ] `docker compose up -d` com um arquivo simples
- [ ] Wi-Fi reconectado (desligar/ligar) e a rede dos contêineres volta em até ~15 s
- [ ] hotspot do Android continua funcionando com o Docker ativo
- [ ] `dockerctl restart` e reinício do aparelho mantêm contêineres com `restart: unless-stopped`

## Commits e PRs

- Um assunto por PR; commits pequenos com mensagem descritiva
  (sugestão: [Conventional Commits](https://www.conventionalcommits.org/pt-br/), ex.
  `fix(net): reaplicar regra 6102 ao trocar de rede`).
- Preencha o modelo de PR.
- Ao contribuir, você concorda em licenciar sua contribuição sob a [licença MIT](LICENSE)
  do projeto (patches de kernel em `kernel/patches/` seguem a GPL-2.0 do kernel).

## Releases

Feitos pelo mantenedor conforme [docs/ATUALIZAR.md](docs/pt-BR/ATUALIZAR.md#para-mantenedores-publicar-uma-versão-nova).

## Conduta

Seja respeitoso e objetivo. Ataques pessoais, assédio ou spam resultam em remoção da
participação no projeto.
