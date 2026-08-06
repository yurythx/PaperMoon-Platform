# cloudflare-tunnel (CT 101)

Ingress público único de toda a plataforma — é o motivo de `papermoon.cloud`
e todos os subdomínios (`nextcloud.`, `vault.`, `jellyfin.`, etc.)
funcionarem sem nenhuma porta aberta no roteador de casa. Só faz conexões
de **saída** para a borda da Cloudflare — não precisa de nenhuma porta
liberada de entrada no `ufw` (nem mesmo para a LAN).

**Sem UI/acesso direto neste host** — é só o processo `cloudflared`
rodando. Gerenciar rotas (quais domínios apontam pra qual serviço) é feito
no [painel Cloudflare Zero Trust](https://one.dash.cloudflare.com/) →
Networks → Tunnels, não aqui.

## Túnel remotely-managed (painel Zero Trust)

Diferente da primeira versão deste stack (que previa um túnel
locally-managed, com `config.yml`/`credentials.json` gerados por
`cloudflared tunnel create`), este túnel foi criado direto no painel
**Cloudflare Zero Trust → Networks → Tunnels**. Nesse modelo:

- O ingress (quais hostnames públicos apontam para qual serviço interno,
  ex: `papermoon.cloud` → `http://192.168.1.102:3000`) é configurado
  na aba **Public Hostname** do túnel, no próprio painel — não existe
  `config.yml` neste repositório.
- O único segredo necessário aqui é o **token** do túnel (painel > seu
  túnel > "Install connector" > copie o valor depois de `--token` no
  comando `cloudflared tunnel run --token ...`).
- `cloudflared` roda com `tunnel --no-autoupdate run --token <TOKEN>` —
  sem volumes, sem arquivos de config montados.

**Vantagem** sobre o modelo locally-managed: zero arquivo de credencial
para proteger/rotacionar neste repo, e qualquer mudança de ingress (novo
hostname, trocar porta) é feita no painel, sem precisar rodar Ansible de
novo. **Desvantagem**: o ingress vive fora do IaC — se quiser reconstruir
o túnel do zero via Terraform/Ansible, os hostnames precisam ser
recriados manualmente no painel (não há hoje um provider Terraform para
isso neste projeto).

## Onde colocar o token real

`ansible/playbooks/host_vars/cloudflare-tunnel.yml` (`cloudflare_tunnel_token`)
— **só no controlador (host Proxmox), nunca commitado**. O arquivo neste
repositório mantém sempre o placeholder `CHANGE_ME_TUNNEL_TOKEN`; o valor
real é editado direto no `host_vars` do controlador, seguindo o mesmo
padrão de todo outro segredo desta plataforma (ver `docs/ansible.md`).
Criptografe com `ansible-vault encrypt` assim que possível.

## Ingress atual

Configurado no painel (não neste repo): hostnames apontando para o
PaperMoon (192.168.1.102), portas 3000 (Next.js) e 8000 (Django API —
usado pelo webhook do Asaas). Se outro app desta plataforma (Nextcloud,
Vaultwarden, etc.) precisar de acesso público no futuro, basta adicionar
uma nova "Public Hostname" no painel — sem tocar neste repositório.
