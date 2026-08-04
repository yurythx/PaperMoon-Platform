# Sem isto, o Terraform assume o provider legado "hashicorp/proxmox" pra
# qualquer resource "proxmox_*" dentro de um módulo filho que não declare
# isso explicitamente — descoberto rodando 'terraform init' de verdade no
# host real (nunca tinha sido validado antes).
terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}
