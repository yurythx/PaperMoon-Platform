# Um module "lxc" por container — TODOS os 12 (incluindo 101 e 102) são
# criados por este Terraform, nenhum é pré-existente. Ver "Capacidade do
# host" no CLAUDE.md e docs/terraform.md para o racional do dimensionamento
# abaixo: o host tem só 16GB de RAM total para 12 LXCs.

module "cloudflare_tunnel" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 101
  hostname         = "cloudflare-tunnel"
  tags             = ["docker", "ingress"]
  cores            = 1
  memory_mb        = 512
  disk_size_gb     = 4
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.101/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys
  # Sem mount_points: cloudflared não guarda estado. Sem porta de entrada
  # liberada no ufw (Fase 3): o túnel só faz conexões de saída.
}

module "papermoon" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 102
  hostname         = "papermoon"
  tags             = ["docker", "saas", "production"]
  cores            = 4    # gunicorn (4 workers) + celery (concorrência 4) competem por CPU
  memory_mb        = 3072 # 7 processos Docker: postgres, redis, django, celery-worker, celery-beat, flower, nextjs
  disk_size_gb     = 32   # dados do Postgres + uploads de mídia
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.102/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys
}

module "jellyfin" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 110
  hostname         = "jellyfin"
  tags             = ["docker", "media"]
  cores            = 2 # transcodificação via GPU passthrough, não via CPU — ver docs/terraform.md
  memory_mb        = 2048
  disk_size_gb     = 8
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.110/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys

  mount_points = local.media_mount_points

  # Transcodificação de hardware via GPU AMD (VAAPI) — confirmar o path exato
  # com 'ls -la /dev/dri/' no host antes do apply; renderD128 é o mais comum,
  # mas o número pode variar conforme outros dispositivos DRM presentes.
  device_passthrough = [
    { path = "/dev/dri/renderD128" },
  ]
}

module "komga" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 111
  hostname         = "komga"
  tags             = ["docker", "media"]
  cores            = 1
  memory_mb        = 768 # JVM precisa de um pouco mais que os outros apps leves
  disk_size_gb     = 8
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.111/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys

  mount_points = local.book_mount_points
}

module "qbittorrent" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 112
  hostname         = "qbittorrent"
  tags             = ["docker", "downloads"]
  cores            = 1
  memory_mb        = 512
  disk_size_gb     = 8
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.112/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys

  mount_points = local.downloads_mount_points
}

module "navidrome" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 113
  hostname         = "navidrome"
  tags             = ["docker", "media"]
  cores            = 1
  memory_mb        = 512
  disk_size_gb     = 4
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.113/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys

  mount_points = local.music_mount_points
}

module "nextcloud" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 120
  hostname         = "nextcloud"
  tags             = ["docker", "productivity"]
  cores            = 2
  memory_mb        = 1536
  disk_size_gb     = 64 # dados dos usuários ficam no disco local do LXC (decisão registrada em docs/terraform.md)
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.120/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys
}

module "nextcloud_mariadb" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 121
  hostname         = "nextcloud-mariadb"
  tags             = ["docker", "database"]
  cores            = 1
  memory_mb        = 1024
  disk_size_gb     = 16
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.121/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys
}

module "nextcloud_redis" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 122
  hostname         = "nextcloud-redis"
  tags             = ["docker", "cache"]
  cores            = 1
  memory_mb        = 256
  disk_size_gb     = 4
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.122/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys
}

module "vaultwarden" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 123
  hostname         = "vaultwarden"
  tags             = ["docker", "security"]
  cores            = 1
  memory_mb        = 256
  disk_size_gb     = 4
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.123/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys
}

module "grafana" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 130
  hostname         = "grafana"
  tags             = ["docker", "monitoring"]
  cores            = 1
  memory_mb        = 512
  disk_size_gb     = 8
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.130/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys
}

module "prometheus" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 131
  hostname         = "prometheus"
  tags             = ["docker", "monitoring"]
  cores            = 1
  memory_mb        = 1024 # homelab, poucos hosts/exporters — reveja se a retenção crescer
  disk_size_gb     = 16
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.131/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys
}
