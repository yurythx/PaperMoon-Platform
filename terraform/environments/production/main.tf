terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

# Autenticação por usuário+senha (ticket), NÃO por api_token — descoberto
# rodando 'terraform apply' de verdade: o Proxmox faz uma checagem literal
# de string contra "root@pam" para operações sensíveis usadas aqui (mount
# point tipo bind, device_passthrough, feature flags como keyctl). Um
# token de API, mesmo do root, se autentica como "root@pam!<tokenid>" —
# não bate com a checagem, e a operação é negada com 403 independente do
# privilégio do role. Só ticket-auth (usuário+senha) resolve. Documentado
# em docs/terraform.md.
provider "proxmox" {
  endpoint = var.pm_api_url
  username = var.pm_pam_username
  password = var.pm_pam_password
  insecure = var.pm_tls_insecure
}
