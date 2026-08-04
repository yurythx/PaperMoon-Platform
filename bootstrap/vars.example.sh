#!/usr/bin/env bash
# Copie este arquivo para vars.sh (ignorado pelo Git) e ajuste se necessário.
# vars.sh é lido (source) por todos os scripts numerados deste diretório.

# --- NFS ---
# Valores reais confirmados no host (pve1) via 'cat /etc/pve/storage.cfg' —
# os dois pools do TrueNAS usam paths de export diferentes entre si, sem
# padrão comum, por isso é um mapa explícito em vez de um prefixo + lista.
NFS_SERVER="192.168.1.14"
declare -A NFS_MOUNTS=(
  ["TrueNAS-NFS"]="/mnt/Pool_HD1/Dados"
  ["TrueNAS-NFS2"]="/mnt/Pool_HD2/Dados2"
)

# --- Terraform service account (Proxmox) ---
TF_PVE_USER="terraform"
TF_PVE_REALM="pve"                     # conta nativa do Proxmox, sem usuário PAM/Linux
TF_PVE_ROLE="TerraformProv"
TF_TOKEN_ID="provider"                 # token final: terraform@pve!provider

# --- Template LXC ---
LXC_TEMPLATE_OS_MATCH="ubuntu-24.04-standard"
LXC_TEMPLATE_STORAGE="local"           # storage onde o template fica armazenado

# --- Tailscale ---
# Gere uma auth key (reusable, com expiração curta) em https://login.tailscale.com/admin/settings/keys
# Exporte como variável de ambiente antes de rodar o script — nunca cole aqui:
#   export TAILSCALE_AUTHKEY="tskey-auth-xxxxx"
TAILSCALE_HOSTNAME="pve-papermoon"
