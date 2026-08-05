# uptime-kuma (CT 141)

Monitoramento de disponibilidade — [louislam/uptime-kuma](https://github.com/louislam/uptime-kuma).

## Sem `.env`, de propósito

Ao contrário do resto da plataforma, este stack não tem `docker_app_env`
nenhum — a imagem não tem um mecanismo suportado de pré-configurar conta
de admin ou monitores via variável de ambiente/arquivo. Tudo é feito uma
vez, manualmente, pelo assistente de primeiro acesso na própria interface
web (`http://192.168.1.141:3001`), igual ao Cloudflare Tunnel (ver
`docker/cloudflare-tunnel/README.md`) — ação fora do escopo do
Terraform/Ansible.

## Monitores a criar (ação manual, uma vez)

Cada um como "HTTP(s)" apontando pro IP:porta da LAN (mesmos links do
`docker/homarr/README.md`):

| Monitor | URL |
|---|---|
| PaperMoon | `http://192.168.1.102:3000` |
| PaperMoon API (health) | `http://192.168.1.102:8000/health/` |
| Nextcloud | `http://192.168.1.120:8080/status.php` |
| Vaultwarden | `http://192.168.1.123:8222/alive` |
| Grafana | `http://192.168.1.130:3000/api/health` |
| Prometheus | `http://192.168.1.131:9090/-/healthy` |
| Jellyfin | `http://192.168.1.110:8096/health` |
| Komga | `http://192.168.1.111:25600/actuator/health` |
| Navidrome | `http://192.168.1.113:4533/ping` |

Keycloak/GLPI/Zabbix ficam de fora desta lista — não fazem parte desta
fase (ver `docs/terraform.md`, orçamento de RAM). Adicionar quando/se
forem implantados.

## Backup

Estado (contas, monitores, histórico) fica só no volume `uptime_kuma_data`
(SQLite interno) — sem banco externo. Incluir no backup padrão da
plataforma (`ansible/roles/backup`) assim que a Fase de operação cobrir
este host.
