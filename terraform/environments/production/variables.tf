variable "pm_api_url" {
  type        = string
  description = "Endpoint da API do Proxmox, ex: https://192.168.1.x:8006/api2/json"
}

variable "pm_pam_username" {
  type        = string
  default     = "root@pam"
  description = "Precisa ser literalmente root@pam (ticket-auth) — bind mounts, device_passthrough e feature flags custom só são permitidos para essa identidade exata no Proxmox. Ver comentário em main.tf."
}

variable "pm_pam_password" {
  type        = string
  sensitive   = true
  description = "Senha do root@pam. Considere usar uma senha dedicada/rotacionada só para automação, já que api_token não serve para as operações deste projeto."
}

variable "pm_tls_insecure" {
  type        = bool
  default     = true
  description = "true = aceita o certificado autoassinado padrão do Proxmox (comum em homelab)."
}

variable "pm_node_name" {
  type        = string
  description = "Nome do node Proxmox onde os containers serão criados."
}

variable "network_gateway" {
  type    = string
  default = "192.168.1.1"
}

variable "lxc_template_file_id" {
  type        = string
  description = "volid do template Ubuntu 24.04 baixado em bootstrap/03-lxc-template.sh. Confirmar com 'pveam list local' no host."
}

variable "ssh_public_keys" {
  type        = list(string)
  default     = []
  description = "Chaves SSH autorizadas em todos os containers (consumidas pelo Ansible na Fase 3)."
}
