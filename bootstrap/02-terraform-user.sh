#!/usr/bin/env bash
# Cria a conta de serviço que o Terraform usará para falar com a API do Proxmox:
#   - role customizada com privilégios mínimos (gerenciar guests/LXC + storage + pool)
#   - usuário no realm nativo "pve" (sem shell/login Linux)
#   - token de API com privsep=0 (herda os privilégios do usuário)
#
# Idempotente: nunca recria role/usuário se já existem, e NUNCA regenera um
# token existente (regenerar invalidaria silenciosamente o token em uso pelo
# Terraform em produção — isso deve ser uma decisão manual e deliberada).
#
# Executar como root, diretamente no host Proxmox:
#   ./02-terraform-user.sh

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./vars.sh

if [[ $EUID -ne 0 ]]; then
  echo "Erro: execute como root (ou via sudo) no host Proxmox." >&2
  exit 1
fi

TF_USER_FULL="${TF_PVE_USER}@${TF_PVE_REALM}"

# Privilégios mínimos recomendados para provisionar/gerenciar LXCs, seus
# discos e mount points via Terraform (válido tanto para o provider
# bpg/proxmox quanto Telmate/proxmox — a escolha do provider é decisão da
# Fase 2, este role é deliberadamente um superconjunto seguro para ambos).
ROLE_PRIVS="Datastore.AllocateSpace,Datastore.Audit,Pool.Allocate,Sys.Audit,Sys.Console,Sys.Modify,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.Cloudinit,VM.Config.CPU,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Migrate,VM.Monitor,VM.PowerMgmt,SDN.Use"

# --- 1. Role ---
if pveum role list --output-format json | grep -q "\"roleid\":\"${TF_PVE_ROLE}\""; then
  echo "[skip] Role '${TF_PVE_ROLE}' já existe."
else
  echo "[add] Criando role '${TF_PVE_ROLE}'"
  pveum role add "$TF_PVE_ROLE" --privs "$ROLE_PRIVS"
fi

# --- 2. Usuário ---
if pveum user list --output-format json | grep -q "\"userid\":\"${TF_USER_FULL}\""; then
  echo "[skip] Usuário '${TF_USER_FULL}' já existe."
else
  echo "[add] Criando usuário '${TF_USER_FULL}'"
  pveum user add "$TF_USER_FULL" --comment "Service account do Terraform (IaC) - não é login humano"
fi

# --- 3. ACL: vincula o usuário ao role na raiz da árvore de permissões ---
echo "[sync] Garantindo ACL '/' -> ${TF_USER_FULL} = ${TF_PVE_ROLE}"
pveum aclmod / -user "$TF_USER_FULL" -role "$TF_PVE_ROLE"

# --- 4. Token de API ---
if pveum user token list "$TF_USER_FULL" --output-format json | grep -q "\"tokenid\":\"${TF_TOKEN_ID}\""; then
  echo "[skip] Token '${TF_TOKEN_ID}' já existe para ${TF_USER_FULL}."
  echo "       O segredo só é exibido na criação. Se foi perdido, rotacione manualmente com:"
  echo "       pveum user token remove ${TF_USER_FULL} ${TF_TOKEN_ID} && pveum user token add ${TF_USER_FULL} ${TF_TOKEN_ID} --privsep 0"
else
  echo "[add] Gerando token '${TF_TOKEN_ID}' (privsep=0 -> herda os privilégios do usuário)"
  echo
  pveum user token add "$TF_USER_FULL" "$TF_TOKEN_ID" --privsep 0
  echo
  echo "!!! COPIE O 'value' ACIMA AGORA — ele não será mostrado novamente. !!!"
  echo "Guarde como TF_VAR do Terraform (fora do Git), formato do token completo:"
  echo "  ${TF_USER_FULL}!${TF_TOKEN_ID}=<value-acima>"
fi
