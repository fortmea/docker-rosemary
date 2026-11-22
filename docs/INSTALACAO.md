# Instalação

## Pré-requisitos

| Item | Observação |
|---|---|
| Redmi Note 10S / Poco M5s (`rosemary`) | `adb shell getprop ro.product.device` deve retornar `rosemary` |
| Bootloader desbloqueado | via Mi Unlock (ferramenta da Xiaomi, fora do escopo deste projeto) |
| LineageOS | testado com LineageOS 24; instale pelo [guia oficial](https://wiki.lineageos.org/devices/rosemary/) |
| Root | Magisk ≥ 20.4 (testado 31.1). KernelSU e APatch são detectados, mas não testados |
| PC | `adb` e `fastboot` ([platform-tools](https://developer.android.com/tools/releases/platform-tools)); Docker ou Linux x86_64 para compilar o kernel |
| Espaço | ~250 MB para o módulo + o que suas imagens ocuparem em `/data` |

## 1. Kernel compatível

Confira as opções obrigatórias no kernel em execução:

```sh
adb shell su -c 'zcat /proc/config.gz' | grep -E 'CONFIG_(SYSVIPC|POSIX_MQUEUE|IPC_NS|CGROUP_PIDS|CGROUP_DEVICE|NETFILTER_XT_MATCH_ADDRTYPE)='
```

As 6 linhas devem aparecer com `=y`. No LineageOS padrão elas faltam: siga
[KERNEL.md](KERNEL.md) para compilar e gravar o kernel e volte aqui.

## 2. Módulo Magisk

**Opção A — release pronto (recomendado)**

1. Baixe `docker-magisk-<versão>.zip` e o `.sha256` dos
   [Releases](https://github.com/fortmea/docker-rosemary/releases) e confira:
   `shasum -a 256 -c docker-magisk-*.zip.sha256`
2. Copie para o aparelho: `adb push docker-magisk-*.zip /sdcard/Download/`
3. Magisk → Módulos → Instalar do armazenamento → escolha o zip.
   Alternativa por linha de comando: `adb shell su -c 'magisk --install-module /sdcard/Download/docker-magisk-<versão>.zip'`
4. Reinicie.

**Opção B — compilar o zip**

Requisitos no PC: `bash`, `curl`, `tar`, `zip` e Go (versão de [`uidfw/go.mod`](../uidfw/go.mod)).

```sh
git clone https://github.com/fortmea/docker-rosemary
cd docker-rosemary
scripts/build-module.sh          # baixa Docker/Compose oficiais e confere o SHA-256
# resultado: out/docker-magisk-<versão>.zip
```

Instale como na opção A.

## 3. Verificar

```sh
adb shell
su
dockerctl status            # "Docker rodando (PID ...)"
docker info | head -20
docker run --rm hello-world
docker run --rm alpine wget -qO- https://example.com | head -3   # rede + DNS + TLS
```

Se algo falhar, veja [PROBLEMAS.md](PROBLEMAS.md).

## 4. Exemplo: Portainer

```sh
su
mkdir -p /data/docker/compose/portainer && cd /data/docker/compose/portainer
cat > compose.yaml <<'EOF'
services:
  portainer:
    image: portainer/portainer-ce:lts
    restart: unless-stopped
    ports: ["9443:9443"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
volumes:
  portainer_data:
EOF
docker compose up -d
```

Abra `https://<ip-do-aparelho>:9443` no navegador. Contêineres com
`restart: unless-stopped` voltam sozinhos após reiniciar o aparelho.

## Desinstalar

Remova o módulo no Magisk e reinicie. `/data/docker` (imagens, volumes, configuração) é
mantido de propósito; para apagar tudo:

```sh
su -c 'rm -rf /data/docker'
```

Para voltar ao kernel original, grave o backup do boot (veja [KERNEL.md](KERNEL.md#reverter)).
