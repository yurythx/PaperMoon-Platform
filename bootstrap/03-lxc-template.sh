#!/usr/bin/env bash
# Garante que o template Ubuntu Server 24.04 LTS para LXC está baixado no
# storage local — base que o Terraform vai usar para criar todos os CTs.
#
# Resolve o nome exato do arquivo dinamicamente (em vez de fixar uma versão),
# pois o Proxmox atualiza o nome do template (ex: ubuntu-24.04-standard_24.04-2_amd64.tar.zst)
# conforme novas revisões saem — hardcoded quebraria silenciosamente no futuro.
#
# Idempotente: pula o download se um template compatível já existir.
#
# Executar como root, diretamente no host Proxmox:
#   ./03-lxc-template.sh

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./vars.sh

if [[ $EUID -ne 0 ]]; then
  echo "Erro: execute como root (ou via sudo) no host Proxmox." >&2
  exit 1
fi

echo "[sync] Atualizando lista de templates disponíveis (pveam update)"
pveam update

if pveam list "$LXC_TEMPLATE_STORAGE" | grep -q "$LXC_TEMPLATE_OS_MATCH"; then
  echo "[skip] Já existe um template '${LXC_TEMPLATE_OS_MATCH}*' em '${LXC_TEMPLATE_STORAGE}':"
  pveam list "$LXC_TEMPLATE_STORAGE" | grep "$LXC_TEMPLATE_OS_MATCH"
  exit 0
fi

TEMPLATE_FILE=$(pveam available --section system | awk '{print $2}' | grep "^${LXC_TEMPLATE_OS_MATCH}" | sort -V | tail -n1)

if [[ -z "$TEMPLATE_FILE" ]]; then
  echo "Erro: nenhum template encontrado para '${LXC_TEMPLATE_OS_MATCH}' no catálogo do Proxmox." >&2
  echo "Rode 'pveam available --section system | grep ubuntu' para conferir os nomes disponíveis." >&2
  exit 1
fi

echo "[add] Baixando template '${TEMPLATE_FILE}' para storage '${LXC_TEMPLATE_STORAGE}'"
pveam download "$LXC_TEMPLATE_STORAGE" "$TEMPLATE_FILE"

echo "[ok] Template disponível:"
pveam list "$LXC_TEMPLATE_STORAGE" | grep "$LXC_TEMPLATE_OS_MATCH"
