variable "pm_api_url" {
  type        = string
  description = "Endpoint da API do Proxmox, ex: https://192.168.1.x:8006/api2/json"
}

variable "pm_api_token" {
  type        = string
  sensitive   = true
  description = "Token gerado em bootstrap/02-terraform-user.sh, formato terraform@pve!provider=<secret>"
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
