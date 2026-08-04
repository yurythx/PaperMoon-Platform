#!/usr/bin/env bash
# Registra os compartilhamentos NFS como storage no Proxmox e garante que a
# estrutura de pastas media/books/downloads exista dentro de cada um (usada
# pelos bind mounts do Terraform).
#
# Idempotente: pula qualquer storage que já esteja cadastrado; mkdir -p não
# falha se a pasta já existir.
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

# NFS_MOUNTS é um mapa storage_id -> export_path (ver vars.example.sh) —
# os dois pools deste projeto usam paths de export diferentes entre si
# (estrutura de pool do TrueNAS), não um padrão previsível tipo /dados,
# /dados2, então não dá pra derivar um do outro.
for storage_id in "${!NFS_MOUNTS[@]}"; do
  export_path="${NFS_MOUNTS[$storage_id]}"

  if pvesm status --storage "$storage_id" &>/dev/null; then
    echo "[skip] Storage '$storage_id' já existe."
  else
    echo "[add] Registrando storage '$storage_id' -> ${NFS_SERVER}:${export_path}"
    pvesm add nfs "$storage_id" \
      --server "$NFS_SERVER" \
      --export "$export_path" \
      --content images \
      --options vers=4
    echo "[ok] '$storage_id' montado em /mnt/pve/${storage_id}"
  fi

  mount_point="/mnt/pve/${storage_id}"
  echo "[dirs] Garantindo estrutura media/books/downloads em ${mount_point}"
  mkdir -p "${mount_point}"/{media/{movies,series,anime,music,photos},books/{manga,comics,ebooks},downloads/{complete,incomplete,watch}}
  chmod -R 777 "${mount_point}/media" "${mount_point}/books" "${mount_point}/downloads"
done

echo
echo "Verificação final:"
pvesm status
