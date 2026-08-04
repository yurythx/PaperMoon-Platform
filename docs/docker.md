# Camada Docker

Documento vivo — atualizado a cada stack adicionada na Fase 3b. Ver
`docs/ansible.md` para a ordem de entrega planejada.

## Padrão de cada stack

Cada `docker/<app>/` é independente e contém:

- `docker-compose.yml` — nunca com segredo hardcoded, só `${VAR}` lidas do `.env`.
- `.env.example` — placeholders (`CHANGE_ME_...`), documentação do que a stack espera.
- `README.md` — decisões específicas daquela stack (rede, persistência, backup).

O `.env` **real** de cada host não é editado manualmente — ele é gerado
pela role `docker_app` do Ansible (Fase 3a) a partir de
`ansible/host_vars/<app>.yml` (segredos ali devem estar
`ansible-vault`-criptografados antes de produção).

## Rede entre stacks

Como cada app roda em seu próprio LXC (não há uma rede Docker
compartilhada entre containers), comunicação entre stacks diferentes (ex:
Nextcloud -> MariaDB) acontece pela rede da LAN, via a porta publicada no
`docker-compose.yml` daquele serviço. O `ufw` (role `firewall`) restringe
quem pode alcançar essa porta — ver `from` em `firewall_allowed_ports`.

## Stacks entregues

| Stack | CT | Status | Observação |
|---|---|---|---|
| `nextcloud-mariadb` | 121 | ✅ | Porta 3306 liberada só para 192.168.1.120 (Nextcloud) |
| `nextcloud-redis` | 122 | ✅ | Porta 6379 liberada só para 192.168.1.120; sem volume (cache) |
| `nextcloud` | 120 | ✅ | imagem `nextcloud:29-apache`; porta 8080 liberada pra LAN; cron.php agendado via Ansible |
| `jellyfin` | 110 | ✅ | GPU AMD/VAAPI via `/dev/dri/renderD128`; bibliotecas duplas (dados+dados2) |
| `komga` | 111 | ✅ | porta 25600; bibliotecas duplas |
| `qbittorrent` | 112 | ✅ | porta 6881 aberta pra internet (peers) — precisa port-forward no roteador |
| `navidrome` | 113 | ✅ | `ND_MUSICFOLDER` único com 2 subpastas montadas (dados+dados2) |
| `vaultwarden` | 123 | ✅ | `ADMIN_TOKEN` precisa ser hash Argon2 real, gerado manualmente antes do deploy |
| `prometheus` | 131 | ✅ | só auto-monitoramento por enquanto; frota completa fica pra Fase 4 (node_exporter) |
| `grafana` | 130 | ✅ | datasource do Prometheus provisionado automaticamente |
| `cloudflare-tunnel` | 101 | ✅ | `config.yml` renderizado via Jinja2 a partir de `host_vars/cloudflare-tunnel.yml`; credenciais reais ainda são placeholder |
| `papermoon` | 102 | ✅ | não usa a role `docker_app` genérica — reaproveita o `deploy.sh` próprio do app (git pull + build + migrate + health-check + rollback) |

### Resolvido: rede entre `cloudflare-tunnel` e `papermoon`

O `docker-compose.prod.yml` do PaperMoon foi escrito originalmente
assumindo que o cloudflared estaria no mesmo host Docker (rede
`papermoon-network: external: true`, alcançando `django-api`/`nextjs` pelo
nome do serviço). Como o Cloudflare Tunnel é o ingress único de toda a
plataforma (não só do PaperMoon), ele vive em uma LXC separada (101) — a
solução implementada:

1. **Portas publicadas** no `docker-compose.prod.yml` do PaperMoon: 3000
   (nextjs) e 8000 (django-api, usado pelo webhook do Asaas) — mudança de
   infraestrutura de deploy, código da aplicação (Python/TS) intocado.
   `papermoon-network` (a rede externa compartilhada) foi removida do
   compose por não fazer mais sentido — ver diff em
   `docker/papermoon/docker-compose.prod.yml`. **Essa mudança precisa ser
   commitada e enviada (`git push`) para o repositório do PaperMoon no
   GitHub** — o `deploy.sh` roda `git pull` no host de produção, então sem
   o push a versão antiga (com a rede compartilhada) continua sendo
   puxada.
2. **`ufw`** do host 102 libera as portas 3000/8000 só para 192.168.1.101
   (`ansible/host_vars/papermoon.yml`), mesmo padrão usado em
   `nextcloud-mariadb`/`nextcloud-redis`.
3. **cloudflared** (`docker/cloudflare-tunnel/config.yml.j2`) aponta os
   hostnames para `192.168.1.102:3000` e `192.168.1.102:8000` diretamente,
   em vez de nomes de serviço Docker.

**Ainda pendente de ação humana** (fora do escopo do que dá pra automatizar
sem acesso à sua conta): criar o túnel de verdade na Cloudflare
(`cloudflared tunnel login && cloudflared tunnel create ...`), preencher o
Tunnel ID e as credenciais reais, e apontar os registros DNS — passo a
passo em `docker/cloudflare-tunnel/README.md`.

## Como aplicar uma stack já entregue

```bash
cd ansible
ansible-playbook playbooks/deploy-nextcloud-mariadb.yml
ansible-playbook playbooks/deploy-nextcloud-redis.yml
```

(Pressupõe que `playbooks/site.yml` já rodou nesses hosts pelo menos uma
vez — Docker Engine e firewall precisam existir antes de subir a stack.)
