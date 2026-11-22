# Docker no Xiaomi rosemary

Docker Engine e Docker Compose oficiais rodando nativamente no **Redmi Note 10S / Poco M5s
(codinome `rosemary`, MediaTek Helio G95 / MT6785)** com LineageOS e root — sem Termux,
sem chroot e sem máquina virtual.

O projeto tem duas partes:

| Parte | O que é | Onde |
|---|---|---|
| **Kernel** | O kernel padrão do LineageOS não tem algumas opções exigidas pelo Docker. Há um fragmento de configuração, um script que compila o kernel a partir do código oficial do LineageOS e o kernel já compilado em cada release. | [`kernel/`](kernel/), [docs/KERNEL.md](docs/KERNEL.md) |
| **Módulo Magisk** | Binários estáticos oficiais do Docker (`download.docker.com`) + Compose + scripts que adaptam o Docker ao Android (mount namespace, rotas, DNS, firewall eBPF). | [`module/`](module/), [`uidfw/`](uidfw/) |

O zip do módulo e o kernel compilado estão nos [Releases](https://github.com/fortmea/docker-rosemary/releases).
Depois de instalado, o módulo recebe atualizações pelo próprio app Magisk.

## Estado

Testado no aparelho com:

- LineageOS 24 (nightly 2026-11-04), slot A/B
- Magisk 31.1 (o módulo também detecta KernelSU e APatch)
- Kernel `4.19.325` do LineageOS (`lineage-24.0`) + [`kernel/docker.config`](kernel/docker.config)
- Docker Engine 29.10.0, Compose v5.8.0 — imagens arm64, redes bridge, portas publicadas,
  volumes, `docker compose`, Portainer, Nextcloud AIO

## Início rápido

> Requer bootloader desbloqueado, LineageOS instalado e Magisk funcionando.
> Trocar o kernel pode deixar o aparelho sem iniciar se feito errado: **faça backup do boot**.
> Siga o passo a passo completo em [docs/INSTALACAO.md](docs/INSTALACAO.md).

1. Verifique se o kernel atual já serve (normalmente **não**, no LineageOS padrão):
   ```sh
   adb shell su -c 'zcat /proc/config.gz' | grep -E 'CONFIG_(SYSVIPC|POSIX_MQUEUE|IPC_NS|CGROUP_PIDS|CGROUP_DEVICE|NETFILTER_XT_MATCH_ADDRTYPE)='
   ```
   Se faltar alguma das 6 linhas, grave um kernel com as opções de
   [`kernel/docker.config`](kernel/docker.config): o `rosemary-docker-Image.gz` pronto dos
   Releases, ou compilado por você (script em contêiner ou manual). Veja
   [docs/KERNEL.md](docs/KERNEL.md).
2. Baixe `docker-magisk-<versão>.zip` dos Releases e instale pelo app Magisk
   (Módulos → Instalar do armazenamento). O instalador recusa kernels incompatíveis.
3. Reinicie e teste:
   ```sh
   adb shell
   su
   dockerctl status
   docker run --rm hello-world
   ```

## Uso

Todos os comandos rodam como root (`su`):

| Comando | Função |
|---|---|
| `docker ...`, `docker compose ...` | CLI normal do Docker |
| `dockerctl start\|stop\|restart` | controla o `dockerd` |
| `dockerctl status` | estado e contêineres em execução |
| `dockerctl logs [n]` | últimas linhas de `/data/docker/log/dockerd.log` |
| `dockerctl net` | reaplica as regras de rota (também é feito a cada 15 s) |

Arquivos no aparelho:

- `/data/docker/lib` — imagens, volumes, contêineres (mantido ao desinstalar o módulo)
- `/data/docker/daemon.json` — configuração do daemon (copiada do módulo só na primeira vez)
- `/data/docker/log/` — `dockerd.log`, `uidfw.log`
- `/data/docker/run/docker.sock` — socket no Android; os contêineres veem o caminho padrão
  `/var/run/docker.sock`, então arquivos compose comuns (Portainer etc.) funcionam sem mudança.

Portas publicadas (`-p 8080:80`) ficam acessíveis no IP do aparelho na rede local.
O daemon não escuta em TCP por padrão; para controlá-lo pela rede, adicione um host `tcp://`
**com TLS** em `/data/docker/daemon.json` (veja a
[documentação do Docker](https://docs.docker.com/engine/security/protect-access/)).

## Como funciona

O Android não é uma distribuição Linux comum; o módulo resolve as diferenças assim:

- **Raiz somente leitura** — `nsroot.sh` executa o `dockerd` num mount namespace privado
  (`unshare -m`) cuja raiz espelha a do Android (rbind) e acrescenta `/run`, `/var/run` e
  `/etc` graváveis (o `dockerd` usa `/run/docker` fixo e precisa de `/etc/resolv.conf`).
  Nada muda no namespace do próprio Android.
- **cgroup v2** — se o Android não montar cgroup2 em `/sys/fs/cgroup`, ele é montado dentro
  do namespace do Docker.
- **Roteamento por políticas** — o Android descarta tráfego encaminhado das bridges
  (`32000: unreachable`). `net.sh` adiciona regras `ip rule` para `172.16.0.0/12` (o pool de
  endereços do Docker) apontando para a tabela da conexão ativa, e as reaplica a cada 15 s
  (reconexões de Wi-Fi recriam as tabelas). O pool deixa de fora `172.28.0.0/16`, a faixa
  NAT padrão do Droidspaces, para os dois poderem rodar juntos.
- **DNS** — `net.sh` mantém `/data/docker/resolv.conf` com os DNS da rede atual
  (`dumpsys connectivity`) e reservas públicas.
- **Firewall eBPF por UID** — o Android bloqueia tráfego de qualquer UID ≥ 10000 que não seja
  um app liberado (modo de rede restrita, segundo plano, soneca). Processos de contêiner
  rodando como, por exemplo, UID 65532 ficam sem rede. `docker-uidfw` ([`uidfw/`](uidfw/))
  dá os bits de permissão no `uid_owner_map` do netd apenas aos UIDs de processos dentro do
  cgroup `docker`, nunca a UIDs de apps instalados.
- **Ponto de acesso / ancoragem** — `ip-forward-no-drop` em `daemon.json` impede o Docker de
  mudar a política FORWARD para DROP, o que quebraria o hotspot.
- **Certificados** — `SSL_CERT_DIR` aponta para o repositório de CAs do Android.

## Limitações conhecidas

- Apenas imagens **arm64** (`linux/arm64`). O kernel não tem `BINFMT_MISC`, então não há
  emulação amd64 via QEMU.
- Docker Swarm / redes overlay não funcionam (`VXLAN`, `IP_VS` ausentes).
- Atualizações OTA do LineageOS trocam o boot e **removem o kernel customizado**; refaça
  o procedimento do kernel após cada atualização ([docs/KERNEL.md](docs/KERNEL.md#após-uma-atualização-do-lineageos)).
- Outros aparelhos arm64 podem funcionar (nada no módulo é específico do rosemary), mas só o
  rosemary é testado.

## Documentação

- [Instalação completa](docs/INSTALACAO.md)
- [Kernel: compilar, gravar e reverter](docs/KERNEL.md)
- [Atualizar a versão do Docker](docs/ATUALIZAR.md)
- [Problemas frequentes](docs/PROBLEMAS.md)
- [Como contribuir](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)
- [Código de terceiros e licenças](THIRD_PARTY.md)

## Licença

Scripts e código deste repositório: [MIT](LICENSE). Docker, Compose e o kernel são de
terceiros, com licenças próprias — veja [THIRD_PARTY.md](THIRD_PARTY.md).
Projeto não oficial, sem relação com Docker Inc., Xiaomi ou LineageOS.
