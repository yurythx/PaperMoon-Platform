# Fase 4 — Recuperação de Desastre

Procedimento fim-a-fim para reconstruir a plataforma inteira do zero (host
Proxmox perdido/reinstalado do zero, ou um container específico corrompido).

## Cenário 1: perda total do host Proxmox

Pressupõe que você tem: um Proxmox novo instalado, o storage NFS
(192.168.1.14) intacto e acessível, e os backups (`docs/backup.md`) em mãos
(fora do host morto — por isso a decisão de destino do backup em
`docs/backup.md` importa tanto).

1. **Bootstrap** (`docs/bootstrap.md`): rodar os 4 scripts em
   `bootstrap/` no Proxmox novo — registra NFS, cria o usuário/token do
   Terraform, baixa o template LXC, conecta o Tailscale.
2. **Terraform** (`docs/terraform.md`):
   ```bash
   cd terraform/environments/production
   cp terraform.tfvars.example terraform.tfvars   # preencher com os valores reais
   terraform init
   terraform apply
   ```
   Recria os 12 LXCs, vazios (sem dado nenhum ainda).
3. **Ansible — configuração base** (`docs/ansible.md`):
   ```bash
   cd ansible
   ansible-galaxy install -r requirements.yml

   # OBRIGATÓRIO antes de qualquer ansible-playbook: sem isso, todo
   # host_vars/group_vars com segredo real (senhas, tokens) está
   # criptografado e ilegível. Restaure a senha do vault do seu password
   # manager — não existe "recuperar" se essa senha também foi perdida
   # junto com o host antigo (ver docs/ansible.md, seção "Segredos via
   # Ansible Vault").
   echo 'SENHA_DO_VAULT_AQUI' > .vault_pass && chmod 600 .vault_pass

   ansible-playbook site.yml -e ansible_user=root   # hosts novos, usuário suporte ainda não existe
   ```
   Aplica `common` (usuário suporte, SSH, timezone, unattended-upgrades),
   `docker_engine`, `node_exporter`, `backup` (cria a estrutura, mas sem
   dado ainda) e `firewall` em todos os 12 hosts.
4. **Restaurar backups ANTES de subir as stacks com dado** — copiar os
   arquivos de `docs/backup.md` para dentro do host (ou para o diretório
   `backup_destination_dir` configurado) e restaurar (comandos em
   `docs/backup.md`) para: `nextcloud-mariadb`, `papermoon` (Postgres),
   `nextcloud`, `vaultwarden` (volumes). Isso exige que o container do
   banco/app já exista mas idealmente parado ou recém-criado sem dado —
   ver `docs/backup.md` para a ordem exata (banco antes do app que
   depende dele).
5. **Deploy de cada stack** (`docs/docker.md`), na ordem de dependência:
   ```bash
   ansible-playbook playbooks/deploy-nextcloud-mariadb.yml
   ansible-playbook playbooks/deploy-nextcloud-redis.yml
   ansible-playbook playbooks/deploy-nextcloud.yml
   ansible-playbook playbooks/deploy-jellyfin.yml
   ansible-playbook playbooks/deploy-komga.yml
   ansible-playbook playbooks/deploy-qbittorrent.yml
   ansible-playbook playbooks/deploy-navidrome.yml
   ansible-playbook playbooks/deploy-vaultwarden.yml
   ansible-playbook playbooks/deploy-prometheus.yml
   ansible-playbook playbooks/deploy-grafana.yml
   ansible-playbook playbooks/deploy-cloudflare-tunnel.yml
   ansible-playbook playbooks/deploy-papermoon.yml
   ```
6. **Verificar**: `docs/ansible.md`/`docs/docker.md` têm os comandos de
   verificação por camada. Conferir especialmente que os dados restaurados
   (contas do Nextcloud, cofre do Vaultwarden, clientes/faturas do
   PaperMoon) estão íntegros antes de considerar concluído.

## Cenário 2: um único container corrompido/perdido

Muito mais simples — Terraform e Ansible já são idempotentes:

```bash
cd terraform/environments/production && terraform apply   # recria só a LXC que sumiu
cd ../../../ansible
ansible-playbook site.yml --limit <hostname> -e ansible_user=root
ansible-playbook playbooks/deploy-<app>.yml
```

Depois, restaurar o backup daquele host específico se ele guardava dado
(ver `docs/backup.md`).

## O que este procedimento NÃO cobre ainda

- Backup do **estado do Terraform** (`terraform.tfstate`) em si — hoje é
  local (`docs/terraform.md`), sem cópia automática. Se o `.tfstate` for
  perdido junto com o host, o Terraform não vai mais reconhecer os
  recursos existentes (mas como a infra também morreu junto no Cenário 1,
  isso não muda o procedimento — `terraform apply` recria do zero de
  qualquer forma).
- Backup dos próprios arquivos deste repositório Git — pressuposto: o
  repositório está em um remote (GitHub ou outro), não só local.
- Teste periódico de restore (*"backup que nunca foi restaurado não é
  backup, é esperança"*) — não há automação disso ainda; recomenda-se
  testar manualmente de tempos em tempos.
