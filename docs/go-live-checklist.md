# Checklist — Testar em produção sem medo

Contexto: o PaperMoon já está no ar de verdade, numa VPS, com clientes
reais. Este documento separa duas fases com riscos completamente
diferentes — não confundir as duas é o item mais importante deste
checklist.

## Por que dá pra testar a Fase A sem medo nenhum

O Terraform/Ansible deste repositório só enxergam o **Proxmox novo**. Eles
não sabem que a VPS existe, não têm credenciais dela, não têm como
alcançá-la. Enquanto o domínio real (`papermoon.cloud` ou o que for) e o
Cloudflare Tunnel de produção continuarem apontando pra VPS, **qualquer
coisa que a gente fizer no Proxmox novo é inofensiva** — inclusive subir o
CT 102 (PaperMoon) lá, com um Postgres vazio, do zero. Ele só passa a
importar quando alguém apontar tráfego real pra ele.

A regra de ouro da Fase A: **não toque no DNS/tunnel de produção até o
fim.**

---

## Fase A — Validar a plataforma nova (zero risco ao negócio)

### A.1 — Corrigir as suposições que ficaram documentadas como "confirmar depois"

Isso se acumulou ao longo da construção — reunindo tudo num lugar só:

- [ ] **Nome real do node Proxmox** (`pvecm status` ou `hostname`) → `terraform.tfvars` (`pm_node_name`)
- [ ] **IPs 192.168.1.101, .102, .110-113, .120-123, .130-131 estão livres** — nenhum conflita com outro dispositivo/DHCP da rede
- [ ] **Device real da GPU** (`ls -la /dev/dri/` no host) — confirmar que é `renderD128` mesmo, ajustar `containers.tf` se não for
- [ ] **Schema do bloco `device_passthrough`** do provider `bpg/proxmox` — nunca validado de verdade (sem Terraform instalado neste ambiente de trabalho). Primeiro `terraform plan` vai revelar se o nome/campos do bloco batem com a versão real do provider.
- [ ] **Nomes dos volumes Docker** usados em `backup_jobs` (`nextcloud_nextcloud_data`, `vaultwarden_vaultwarden_data`, `papermoon_papermoon-media`) — confirmar com `docker volume ls` depois que cada stack subir
- [ ] Nenhum módulo Ansible/coleção (`community.docker`, `community.general`, `ansible.posix`) foi executado de verdade — só sintaxe checada

### A.2 — Preencher segredos reais

- [ ] `terraform/environments/production/terraform.tfvars` (a partir do `.example`)
- [ ] Todos os `ansible/host_vars/*.yml` (hoje `CHANGE_ME`) — senhas de banco, `SECRET_KEY` do Django, `ADMIN_TOKEN` do Vaultwarden (hash Argon2 real), etc.
- [ ] `ansible/files/cloudflare-tunnel-credentials.json` — só depois de criar o túnel de teste (ver A.4)
- [ ] Depois de preencher tudo: `ansible-vault encrypt` em cada arquivo com segredo

### A.3 — Aplicar em ordem, verificando a cada passo (não em lote)

```bash
# 1. Bootstrap (uma vez)
cd bootstrap && ./01-nfs-storage.sh && ./02-terraform-user.sh && ./03-lxc-template.sh && ./04-tailscale.sh

# 2. Terraform — SEMPRE plan antes de apply
cd terraform/environments/production
terraform init
terraform plan          # leia a saída inteira antes de continuar
terraform apply

# 3. Ansible — primeiro só o essencial, host por host
cd ansible
ansible-galaxy install -r requirements.yml
ansible-playbook playbooks/site.yml -e ansible_user=root --limit jellyfin   # 1 host de teste primeiro
```

Sugestão de ordem de teste por criticidade (do mais barato de errar pro
mais sensível):
1. `jellyfin`/`komga`/`navidrome`/`qbittorrent` — se algo der errado, o pior caso é reconfigurar um app de mídia
2. `vaultwarden`, `nextcloud` + dependências, `grafana`/`prometheus`
3. `cloudflare-tunnel` — mas com um hostname de **teste** (ver A.4), nunca o domínio real ainda
4. `papermoon` — por último, e mesmo assim só com dado fake/vazio nesta fase (ver Fase B antes de usar dado real)

### A.4 — Testar o Cloudflare Tunnel sem tocar no DNS de produção

Crie um **segundo túnel** (`papermoon-platform-staging`, por exemplo) com
seu próprio hostname de teste (pode ser um subdomínio novo tipo
`staging.papermoon.cloud`, ou até o hostname `.trycloudflare.com` gratuito
que o `cloudflared` gera sozinho para testes rápidos). Isso valida toda a
cadeia (Terraform → Ansible → Docker → Cloudflare) sem chegar perto do
domínio que os clientes reais usam.

### A.5 — Critério de "passou na Fase A"

- Todos os 12 containers no ar, `ansible docker_hosts -m ping` respondendo
- `terraform plan` sem diffs pendentes (idempotência confirmada)
- Rodar `ansible-playbook site.yml` uma segunda vez não muda nada
  (idempotência do lado Ansible)
- PaperMoon acessível pelo hostname de teste, com dado fake, funcionando
  ponta a ponta (cadastro, login, um fluxo de cobrança de teste do Asaas
  em sandbox)
- Um backup rodou (`docs/backup.md`) e **foi restaurado com sucesso** em
  outro lugar (backup nunca testado não conta como backup)

---

## Fase B — Migrar o PaperMoon de verdade (aqui sim tem risco real)

Só começar depois da Fase A 100% verde.

### B.1 — Backup da VPS atual (a fonte da verdade, hoje)

- [ ] Rodar o backup da VPS atual (o `scripts/backup.sh` que já existe no
      próprio PaperMoon) e guardar o dump em local seguro, **fora da VPS**
- [ ] Validar que esse dump abre/restaura sem erro num ambiente separado
      (não teste restore direto na VPS de produção)

### B.2 — Restaurar esse dump real no CT 102 novo

- [ ] Restaurar o Postgres (comando em `docs/backup.md`) no
      `nextcloud-mariadb`... digo, no `papermoon` novo
- [ ] Rodar `ansible-playbook playbooks/deploy-papermoon.yml` (o
      `deploy.sh` cuida de migrations/health-check)
- [ ] Testar exaustivamente com o hostname de **teste** (ainda sem tocar
      DNS real) — login com conta real (sem fazer ações destrutivas),
      conferir que os dados batem com a VPS

### B.3 — Corte (cutover) com plano de volta

- [ ] Colocar a VPS em modo leitura/manutenção por alguns minutos (evita
      escrita dupla enquanto migra o delta final de dados)
- [ ] Sincronizar o delta final (dados criados entre o backup do B.1 e
      agora) — rodar o backup/restore de novo, ou aplicar só as mudanças
- [ ] Trocar o ingress do túnel de produção (ou o CNAME no Cloudflare) do
      domínio real para o novo Cloudflare Tunnel → `192.168.1.102`
- [ ] **Manter a VPS ligada e intocada por um período** (dias, não horas)
      como plano B — reverter é só apontar o DNS/tunnel de volta pra ela
- [ ] Monitorar de perto no Grafana/Prometheus (já up desde a Fase A) nas
      primeiras horas/dias após o corte

### B.4 — Só depois de confiar 100%

- [ ] Desligar/desprovisionar a VPS antiga
- [ ] Remover o túnel/hostname de teste (A.4), manter só o de produção

---

## Resumo de uma frase

**Fase A é livre — teste à vontade, não existe jeito de isso quebrar a
VPS. Fase B é a parte de verdade: backup verificado, corte com rollback
pronto, VPS antiga viva por alguns dias como rede de segurança.**
