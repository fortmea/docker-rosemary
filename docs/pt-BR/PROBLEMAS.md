# Problemas frequentes

[English](../TROUBLESHOOTING.md) · **Português**

Antes de tudo, colete:

```sh
su
dockerctl status
dockerctl logs 50
tail -20 /data/docker/log/uidfw.log
ip rule show | grep -E '^60(89|10[12]):'
cat /data/docker/resolv.conf
uname -r
```

Ao abrir uma issue, cole essas saídas ([modelo de bug](https://github.com/fortmea/docker-rosemary/issues/new?template=bug.yml)).

---

### O instalador do módulo aborta com "O kernel não tem opções necessárias"

O kernel em execução não tem as opções listadas. Compile e grave o kernel conforme
[KERNEL.md](KERNEL.md). Se você já gravou e o erro continua, confira `uname -r` (deve
conter `-docker`) — o aparelho pode ter iniciado pelo outro slot ou uma OTA trocou o boot.

### `docker: rode como root (su -c docker ...)`

Os comandos `docker` e `dockerctl` só funcionam como root. Use `su` antes, ou
`su -c 'docker ps'`. Em apps de terminal, conceda root ao app no Magisk.

### `Docker não respondeu em 60 s`

O `dockerd` não subiu. Veja `dockerctl logs 50`. Causas comuns:

- **Mensagens sobre cgroup, `ipc namespace` ou `iptables ... addrtype`** — kernel sem as
  opções (veja acima). Comum depois de uma atualização do LineageOS.
- **`overlay2` não suportado** — confira `grep overlay /proc/filesystems`. Como último
  recurso, troque `"storage-driver": "overlay2"` por `"vfs"` em `/data/docker/daemon.json`
  (funciona, mas gasta muito mais espaço; imagens já baixadas precisam ser baixadas de novo).
- **`daemon.json` inválido** depois de uma edição sua — valide o JSON. Para voltar ao padrão:
  `rm /data/docker/daemon.json && dockerctl start` (ele é recopiado do módulo).

### `dockerd (PID n) existe mas não responde`

O processo travou. `kill -9 <PID>` e `dockerctl start`. Se repetir, veja os logs.

### Contêineres sem internet (ping/wget falham) ou `network unreachable`

O Android descarta o tráfego das bridges sem as regras de rota do módulo.

1. `ip rule show | grep -E '^60(89|10[12]):'` deve listar 3 regras. Se faltar, rode
   `dockerctl net`. O módulo reaplica a cada 15 s; se elas somem sempre, outro app/módulo
   (VPN, firewall, outro gerenciador de contêiner) pode estar mexendo nas regras.
2. A regra `6102` aponta para a tabela da conexão atual. Sem conexão de dados/Wi-Fi ativa
   ela não é criada.
3. Uma rede Docker criada fora do pool `172.16.0.0/12` (por exemplo `--subnet 10.0.0.0/24`)
   não é coberta pelas regras. Use sub-redes dentro de `172.16.0.0/12` ou ajuste
   `POOL` em `/data/adb/modules/docker/net.sh`.
4. VPN ativa no Android muda as tabelas de rota; teste sem a VPN.

### Contêiner com usuário não-root fica sem rede (root funciona)

Imagens que rodam com UID ≥ 10000 (por exemplo distroless `nonroot` = 65532) são
bloqueadas pelo firewall eBPF do Android. O `docker-uidfw` libera esses UIDs em até 3 s.

- `tail /data/docker/log/uidfw.log` deve mostrar `allowed uid <n>`.
- Se o log diz `uid owner map not found` ou `unexpected layout`, sua versão do Android tem um
  formato que o uidfw não conhece — abra uma issue com a saída de
  `pm list packages --apex-only --show-versioncode | grep tethering`.
- O uidfw nunca libera UIDs de apps instalados; se o UID do contêiner coincidir com o de um
  app, escolha outro (`user:` no compose).

### Falha de DNS (`lookup registry-1.docker.io: ... server misbehaving`, `Temporary failure in name resolution`)

- `cat /data/docker/resolv.conf` deve ter servidores `nameserver`. O arquivo é atualizado
  pelo `net.sh` a cada 15 s a partir de `dumpsys connectivity`.
- DNS privado (Configurações → Rede → DNS privado) não se aplica ao Docker; os servidores
  públicos de reserva (1.1.1.1, 8.8.8.8) são usados se o da rede falhar.
- Redes que bloqueiam DNS externo: configure `"dns": ["<ip>"]` em `/data/docker/daemon.json`.

### `x509: certificate signed by unknown authority` ao baixar imagens

- Confira a data/hora do aparelho.
- O dockerd usa as CAs de sistema do Android (`SSL_CERT_DIR` em `nsroot.sh`); CAs instaladas
  como "certificado de usuário" não valem. Se você usa um proxy ou registry com certificado
  próprio, instale a CA como certificado de sistema.

### `exec format error` / `no matching manifest for linux/arm64`

A imagem só existe para amd64. O kernel não tem `BINFMT_MISC`, então emulação QEMU não é
possível. Procure uma imagem multi-arquitetura ou construa a imagem para arm64.

### O hotspot / ancoragem USB parou de funcionar depois de instalar

O módulo usa `ip-forward-no-drop` para o Docker não mudar a política FORWARD. Se você
substituiu `/data/docker/daemon.json` por um seu, mantenha `"ip-forward-no-drop": true`.

### Porta publicada não abre a partir de outro dispositivo da rede

- Teste no próprio aparelho: `wget -qO- http://127.0.0.1:<porta>`.
- Use o IP do aparelho na rede (`ip -4 addr show wlan0`).
- Redes Wi-Fi com "isolamento de clientes" (redes de convidados, públicas) bloqueiam o acesso.

### Docker para depois de um tempo / com a tela desligada

O Android pode matar processos em segundo plano em situações de pouca memória. Verifique
`dmesg | grep -i 'lowmemorykiller\|lmkd'` e `logcat -b events | grep am_kill`. Reduza o
número de contêineres ou limite a memória deles (`mem_limit` no compose). A regra de soneca
(doze) do firewall é tratada pelo uidfw.

### Depois de atualizar o LineageOS o Docker não inicia

A OTA instala o kernel padrão. Refaça [o procedimento do kernel](KERNEL.md#após-uma-atualização-do-lineageos).

### Pouco espaço em `/data`

```sh
docker system df
docker system prune            # contêineres parados, redes e imagens sem uso
docker system prune -a --volumes   # CUIDADO: apaga também volumes não usados
```

### `adb` cai durante o uso

Cabos/hubs USB instáveis derrubam a conexão. Use ADB por Wi-Fi
(`adb tcpip 5555 && adb connect <ip>:5555`) ou um terminal no próprio aparelho.
O Docker continua rodando independente do `adb`.

### Redes do Docker colidem com o Droidspaces (`172.28.x.x`)

Desde o 29.10.0-4 o `daemon.json` do módulo deixa `172.28.0.0/16` fora do pool do Docker.
Instalações anteriores mantêm o `/data/docker/daemon.json` antigo: copie
`default-address-pools` de `/data/adb/modules/docker/daemon.json` para ele e rode
`dockerctl restart`.

---

Problema não listado? Abra uma [issue](https://github.com/fortmea/docker-rosemary/issues/new/choose).
