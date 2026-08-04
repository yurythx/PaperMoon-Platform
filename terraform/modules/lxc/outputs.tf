output "vm_id" {
  value = proxmox_virtual_environment_container.this.vm_id
}

output "hostname" {
  value = var.hostname
}

output "ip_address" {
  value       = split("/", var.ip_address)[0]
  description = "IP sem o prefixo CIDR, pronto para consumo pelo inventário do Ansible (Fase 3)."
}
