# Módulo `lxc`

Cria um único LXC no Proxmox via provider `bpg/proxmox`. Não-privilegiado
por padrão, com `nesting`/`keyctl` habilitados para suportar Docker dentro
do container. Não conhece nada sobre a aplicação que vai rodar dentro —
isso é responsabilidade do Ansible (Fase 3) e do `docker-compose.yml` de
cada stack (Fase 3/Docker).

## Exemplo de uso

```hcl
module "jellyfin" {
  source = "../../modules/lxc"

  node_name        = var.pm_node_name
  vm_id            = 110
  hostname         = "jellyfin"
  tags             = ["docker", "media"]
  cores            = 4
  memory_mb        = 4096
  disk_size_gb     = 8
  template_file_id = var.lxc_template_file_id
  ip_address       = "192.168.1.110/24"
  gateway          = var.network_gateway
  ssh_public_keys  = var.ssh_public_keys

  mount_points = [
    { volume = "/mnt/pve/pve-dados/media/movies", path = "/data/movies-1", read_only = true },
  ]
}
```

## Inputs / Outputs

Ver [`variables.tf`](./variables.tf) e [`outputs.tf`](./outputs.tf) — cada
variável tem `description`. Não duplicado aqui para não divergir do código.
