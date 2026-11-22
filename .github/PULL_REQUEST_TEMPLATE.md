## O que muda

<!-- Descreva a mudança e o motivo. Referencie a issue: "Fecha #123". -->

## Tipo

- [ ] Correção
- [ ] Funcionalidade
- [ ] Atualização de versão (Docker/Compose/Go)
- [ ] Documentação
- [ ] Kernel

## Testado em

<!-- Aparelho, ROM/versão, gerenciador de root. "Não testado no aparelho" se for o caso. -->

## Checklist

- [ ] Sem binários commitados
- [ ] Scripts de `module/` compatíveis com `sh` do Android (sem bash-ismos)
- [ ] `go test ./...` em `uidfw/` e `scripts/build-module.sh` passam
- [ ] [Checklist de teste no aparelho](../blob/main/CONTRIBUTING.md#checklist-de-teste-no-aparelho) (mudanças em módulo/uidfw/kernel/versões)
- [ ] Documentação e `CHANGELOG.md` atualizados
