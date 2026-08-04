variable "node_name" {
  type        = string
  description = "Nome do node Proxmox onde o container será criado (ex: pve)."
}

variable "vm_id" {
  type        = number
  description = "CT ID do container (ver tabela de containers no CLAUDE.md)."
}

variable "hostname" {
  type        = string
  description = "Hostname do container."
}

variable "description" {
  type        = string
  default     = "Gerenciado pelo Terraform — não editar manualmente."
}

variable "tags" {
  type        = list(string)
  default     = []
}

variable "cores" {
  type        = number
  default     = 1
}

variable "memory_mb" {
  type        = number
  default     = 512
}

variable "swap_mb" {
  type        = number
  default     = 512
}

variable "disk_size_gb" {
  type        = number
  default     = 4
}

variable "disk_datastore" {
  type        = string
  default     = "local-lvm"
}

variable "template_file_id" {
  type        = string
  description = "volid completo do template no storage (ex: local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst). Confirmar com 'pveam list local' no host — o nome muda a cada revisão do template."
}

variable "network_bridge" {
  type        = string
  default     = "vmbr0"
}

variable "ip_address" {
  type        = string
  description = "IPv4 com prefixo CIDR, ex: 192.168.1.110/24"
}

variable "gateway" {
  type = string
}

variable "unprivileged" {
  type        = bool
  default     = true
  description = "LXC não-privilegiado por padrão (segurança). Ver docs/terraform.md."
}

variable "nesting" {
  type        = bool
  default     = true
  description = "Necessário para rodar Docker dentro do LXC."
}

variable "keyctl" {
  type    = bool
  default = true
}

variable "mount_points" {
  type = list(object({
    volume    = string
    path      = string
    read_only = optional(bool, false)
  }))
  default     = []
  description = "Bind mounts do host para o container. 'volume' é um caminho absoluto no host Proxmox (ex: /mnt/pve/pve-dados/media/movies) — nunca um path NFS montado dentro do container."
}

variable "start_on_boot" {
  type    = bool
  default = true
}

variable "started" {
  type    = bool
  default = true
}

variable "device_passthrough" {
  type = list(object({
    path = string
    mode = optional(string, "0666")
    uid  = optional(number)
    gid  = optional(number)
  }))
  default     = []
  description = "Dispositivos do host passados para dentro do LXC não-privilegiado (ex: /dev/dri/renderD128 para transcodificação de hardware). Usa o bloco 'device_passthrough' do provider bpg/proxmox — como uma LXC compartilha o kernel do host, isso basta; não precisa instalar driver de GPU dentro do container."
}

variable "ssh_public_keys" {
  type        = list(string)
  default     = []
  description = "Chaves públicas SSH autorizadas para o usuário root do container, consumidas pelo Ansible na Fase 3."
}
