#!/usr/bin/env bash
# Registra os compartilhamentos NFS (dados, dados2) como storage no Proxmox.
# Idempotente: pula qualquer storage que já esteja cadastrado.
#
# Executar como root, diretamente no host Proxmox:
#   ./01-nfs-storage.sh

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./vars.sh

if [[ $EUID -ne 0 ]]; then
  echo "Erro: execute como root (ou via sudo) no host Proxmox." >&2
  exit 1
fi

for share in "${NFS_SHARES[@]}"; do
  storage_id="${NFS_STORAGE_PREFIX}${share}"

  if pvesm status --storage "$storage_id" &>/dev/null; then
    echo "[skip] Storage '$storage_id' já existe."
    continue
  fi

  echo "[add] Registrando storage '$storage_id' -> ${NFS_SERVER}:/${share}"
  pvesm add nfs "$storage_id" \
    --server "$NFS_SERVER" \
    --export "/${share}" \
    --content images \
    --options vers=4

  echo "[ok] '$storage_id' montado em /mnt/pve/${storage_id}"
done

echo
echo "Verificação final:"
pvesm status | grep -E "^${NFS_STORAGE_PREFIX}" || true
