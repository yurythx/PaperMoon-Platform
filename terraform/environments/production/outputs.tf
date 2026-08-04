# Inventário simples para a Fase 3 (Ansible) consumir — hostname -> IP.
output "inventory" {
  value = {
    cloudflare_tunnel  = module.cloudflare_tunnel.ip_address
    papermoon          = module.papermoon.ip_address
    jellyfin           = module.jellyfin.ip_address
    komga              = module.komga.ip_address
    qbittorrent        = module.qbittorrent.ip_address
    navidrome          = module.navidrome.ip_address
    nextcloud          = module.nextcloud.ip_address
    nextcloud_mariadb  = module.nextcloud_mariadb.ip_address
    nextcloud_redis    = module.nextcloud_redis.ip_address
    vaultwarden        = module.vaultwarden.ip_address
    grafana            = module.grafana.ip_address
    prometheus         = module.prometheus.ip_address
  }
}
