# Módulo reutilizável: 1 definição de LXC, instanciada uma vez por container
# em terraform/environments/production/containers.tf. Não conhece detalhes
# de nenhuma aplicação específica — só recebe parâmetros.

resource "proxmox_virtual_environment_container" "this" {
  node_name   = var.node_name
  vm_id       = var.vm_id
  description = var.description
  tags        = var.tags

  unprivileged = var.unprivileged

  features {
    nesting = var.nesting
    keyctl  = var.keyctl
  }

  operating_system {
    template_file_id = var.template_file_id
    type              = "ubuntu"
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  disk {
    datastore_id = var.disk_datastore
    size         = var.disk_size_gb
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  dynamic "device_passthrough" {
    for_each = var.device_passthrough
    content {
      path = device_passthrough.value.path
      mode = try(device_passthrough.value.mode, "0666")
      uid  = try(device_passthrough.value.uid, null)
      gid  = try(device_passthrough.value.gid, null)
    }
  }

  dynamic "mount_point" {
    for_each = var.mount_points
    content {
      volume    = mount_point.value.volume
      path      = mount_point.value.path
      read_only = try(mount_point.value.read_only, false)
    }
  }

  start_on_boot = var.start_on_boot
  started       = var.started
}
