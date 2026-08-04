# qbittorrent (CT 112)

## Downloads: só o pool `dados`

Como já registrado em `docs/terraform.md`, `downloads/{complete,incomplete,watch}`
é área de staging temporária (os arquivos saem de lá assim que organizados
na biblioteca definitiva) — por isso só usa o pool `dados`, não os dois.
Mounts com leitura/escrita (sem `:ro`), diferente dos apps de mídia — o
qBittorrent precisa escrever os downloads.

## Porta de peers (6881) precisa de port-forward no roteador

Isso está **fora do escopo deste repositório** (Proxmox/Terraform/Ansible
não controlam o roteador de casa). Sem encaminhar a porta 6881 (TCP+UDP) no
roteador para `192.168.1.112:6881`, o qBittorrent funciona mas com
velocidade reduzida (só consegue conectar a peers que também aceitam
conexões de entrada).

## Rede

- WebUI (porta de `WEBUI_PORT`, default 8080): liberada só para a LAN de
  casa.
- Porta 6881 (TCP+UDP): liberada para **qualquer origem** (`from` omitido
  no `ufw`) — precisa aceitar peers vindos da internet real, não só da LAN.

Ver `ansible/playbooks/host_vars/qbittorrent.yml`.
