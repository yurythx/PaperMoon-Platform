#!/usr/bin/env bash
# Instala o Tailscale no HOST Proxmox (plano de administração: acesso remoto
# seguro à web UI/SSH sem expor a porta 8006 à internet). Não confundir com o
# Cloudflare Tunnel (CT 101), que cuida do plano de ingress público das apps.
#
# Idempotente: pula a instalação se o binário já existir; só chama "tailscale up"
# se o node ainda não estiver associado a uma tailnet.
#
# Requer TAILSCALE_AUTHKEY exportada no ambiente (chave gerada em
# https://login.tailscale.com/admin/settings/keys). Nunca cole a chave neste
# arquivo nem em vars.sh.
#
# Executar como root, diretamente no host Proxmox:
#   export TAILSCALE_AUTHKEY="tskey-auth-xxxxx"
#   ./04-tailscale.sh

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./vars.sh

if [[ $EUID -ne 0 ]]; then
  echo "Erro: execute como root (ou via sudo) no host Proxmox." >&2
  exit 1
fi

if command -v tailscale &>/dev/null; then
  echo "[skip] Tailscale já instalado ($(tailscale version | head -n1))."
else
  echo "[add] Instalando Tailscale via script oficial (curl | sh)"
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if tailscale status &>/dev/null; then
  echo "[skip] Host já está conectado a uma tailnet:"
  tailscale status | head -n1
  exit 0
fi

if [[ -z "${TAILSCALE_AUTHKEY:-}" ]]; then
  echo
  echo "TAILSCALE_AUTHKEY não definida — não vou autenticar automaticamente."
  echo "Gere uma chave em https://login.tailscale.com/admin/settings/keys e rode:"
  echo "  export TAILSCALE_AUTHKEY=\"tskey-auth-xxxxx\""
  echo "  tailscale up --hostname=${TAILSCALE_HOSTNAME} --ssh"
  exit 0
fi

echo "[up] Conectando à tailnet como '${TAILSCALE_HOSTNAME}'"
tailscale up --authkey="$TAILSCALE_AUTHKEY" --hostname="$TAILSCALE_HOSTNAME" --ssh

echo "[ok] $(tailscale status | head -n1)"
