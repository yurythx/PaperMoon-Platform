# homarr (CT 140)

Portal central da infraestrutura — [Homarr](https://homarr.dev). Substituiu
o [gethomepage/homepage](https://gethomepage.dev) originalmente planejado
aqui (mesmo CT/IP, só o app mudou) — mais recursos, board editável
arrastando/soltando na própria UI.

## Diferença de arquitetura vs. o Homepage abandonado

Homepage era 100% config-as-code (YAML versionado, sem banco). Homarr
guarda tudo (board, links, integrações) num SQLite dentro do volume
`homarr_appdata` — **estado de aplicação, não config declarativa**. Mesmo
padrão já usado pro Uptime Kuma: o Ansible só sobe o container, o board em
si é montado manualmente na UI (`http://192.168.1.140:7575`) na primeira
vez.

## `SECRET_ENCRYPTION_KEY` é obrigatório

Usado pra criptografar credenciais de integrações salvas no board (ex:
API key de algum widget). Gerar com `openssl rand -hex 32`. Perder essa
chave depois de configurar integrações == perder o acesso a elas (mesma
lógica de qualquer chave de criptografia em repouso desta plataforma).

## Sem `docker.sock` montado, de propósito

A integração Docker do Homarr (auto-descoberta de containers) só faz
sentido quando tudo roda no mesmo host Docker — aqui cada serviço tem seu
próprio LXC. Montar o socket só daria ao Homarr controle sobre os
containers *deste* LXC (só ele mesmo), sem nenhum ganho real, e é uma
superfície de ataque desnecessária caso o Homarr seja comprometido.

## Board — links por domínio público

Configurar cada app apontando pro domínio (`https://<serviço>.papermoon.cloud`)
onde já existe rota no Cloudflare Tunnel; os que não têm rota ainda ficam
por IP:porta da LAN até existir uma.

| Serviço | Link |
|---|---|
| PaperMoon | `https://papermoon.cloud` |
| Nextcloud | `https://nextcloud.papermoon.cloud` |
| Vaultwarden | `https://vault.papermoon.cloud` |
| Jellyfin | `https://jellyfin.papermoon.cloud` |
| Komga | `https://komga.papermoon.cloud` |
| Navidrome | `https://navidrome.papermoon.cloud` |
| qBittorrent | `https://torrent.papermoon.cloud` |
| Grafana | `http://192.168.1.130:3000` (sem rota pública ainda) |
| Prometheus | `https://prometheus.papermoon.cloud` |

CrowdSec e Uptime Kuma foram retirados da stack — remover os widgets/links
correspondentes do board manualmente na UI do Homarr se ainda estiverem lá.

## Backup

`homarr_appdata` (SQLite — board, integrações, preferências). Incluir no
backup padrão da plataforma (`ansible/roles/backup`) assim que a Fase de
operação cobrir este host.
