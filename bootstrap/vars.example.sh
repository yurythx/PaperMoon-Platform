#!/usr/bin/env bash
# Copie este arquivo para vars.sh (ignorado pelo Git) e ajuste se necessário.
# vars.sh é lido (source) por todos os scripts numerados deste diretório.

# --- NFS ---
NFS_SERVER="192.168.1.14"
NFS_SHARES=("dados" "dados2")          # vira o storage ID no Proxmox (pve-dados, pve-dados2)
NFS_STORAGE_PREFIX="pve-"

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
