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
`ansible/playbooks/host_vars/<app>.yml` (segredos ali devem estar
`ansible-vault`-criptografados antes de produção).

## Rede entre stacks

Como cada app roda em seu próprio LXC (não há uma rede Docker
compartilhada entre containers), comunicação entre stacks diferentes (ex:
Nextcloud -> MariaDB) acontece pela rede da LAN, via a porta publicada no
`docker-compose.yml` daquele serviço. O `ufw` (role `firewall`) restringe
quem pode alcançar essa porta — ver `from` em `firewall_allowed_ports`.

## Stacks entregues

**Todas as linhas abaixo (exceto `cloudflare-tunnel`) foram implantadas e
verificadas de verdade no host real (`pve1`) em 2026-08-04** — não é só
código nunca testado. Ver `docs/go-live-checklist.md` para o relato
completo dos bugs reais encontrados e corrigidos nesse processo.

| Stack | CT | Status | Observação |
|---|---|---|---|
| `nextcloud-mariadb` | 121 | ✅ testado | Porta 3306 liberada só para 192.168.1.120 (Nextcloud) |
| `nextcloud-redis` | 122 | ✅ testado | Porta 6379 liberada só para 192.168.1.120; sem volume (cache) |
| `nextcloud` | 120 | ✅ testado | `nextcloud:29-apache`; HTTP 302 confirmado; cron.php agendado via Ansible |
| `jellyfin` | 110 | ✅ testado | GPU AMD/VAAPI via `/dev/dri/renderD128`; container `healthy`; bibliotecas duplas (dados+dados2) |
| `komga` | 111 | ✅ testado | porta 25600, HTTP 200 confirmado |
| `qbittorrent` | 112 | ✅ testado | HTTP 200 confirmado; porta 6881 aberta pra internet (peers) — precisa port-forward no roteador |
| `navidrome` | 113 | ✅ testado | `ND_MUSICFOLDER` único com 2 subpastas montadas (dados+dados2) |
| `vaultwarden` | 123 | ✅ testado | `ADMIN_TOKEN` com hash Argon2 real; painel `/admin` HTTP 200 confirmado |
| `prometheus` | 131 | ✅ testado | `/-/healthy` confirmado; scrape dos 14 hosts via node_exporter (Fase 4) + job dedicado pro cAdvisor do test-stack (150) |
| `grafana` | 130 | ✅ testado | datasource do Prometheus confirmado via API (`/api/datasources`) |
| `papermoon` | 102 | ✅ testado | `deploy.sh` rodou ponta a ponta (build+migrate+health-check); 7 containers `healthy`; portas 3000/8000 publicadas e restritas via ufw ao IP do Cloudflare Tunnel. **SMTP/Asaas ainda são placeholder** — preencher antes de depender de e-mail/cobrança reais |
| `cloudflare-tunnel` | 101 | ✅ testado | Túnel remotely-managed (token, não `config.yml`/`credentials.json` — ver `docker/cloudflare-tunnel/README.md`). Conectado à borda Cloudflare, 4 conexões QUIC confirmadas |
| `papermoon` | 102 | ✅ | não usa a role `docker_app` genérica — reaproveita o `deploy.sh` próprio do app (git pull + build + migrate + health-check + rollback) |
| `homarr` | 140 | ⏳ pendente | Dashboard central — ver "Abandonado: gethomepage/homepage" abaixo pro porquê da troca |
| `test-stack` | 150 | ⏳ pendente | Locust + OWASP ZAP + cAdvisor, LXC isolada de teste de carga/segurança — usa a role `docker_app` genérica, sem role nova. Ver `docker/test-stack/README.md` (aviso de segurança antes de rodar qualquer teste contra o Keycloak real da Prefeitura) |

### Retirado da stack: CrowdSec (132) e Uptime Kuma (141)

Decisão do usuário: remover os dois. Ordem seguida (importa, por causa do
bouncer instalado nos outros hosts): 1) `remove-crowdsec-bouncer.yml`
desinstalou o `crowdsec-firewall-bouncer` (systemd + iptables) dos 13
hosts que tinham — antes de destruir o engine central, pra não deixar
bouncer órfão tentando falar com um LAPI que não responde mais; 2)
`terraform apply -target=module.crowdsec -target=module.uptime_kuma`
destruiu as duas LXCs. Removidos do repo: `docker/crowdsec/`,
`docker/uptime-kuma/`, `ansible/roles/crowdsec_bouncer/`, playbooks e
`host_vars` correspondentes, entradas no inventário e no
`docker/prometheus/prometheus.yml`. Histórico completo no git log
(`chore(terraform): remove crowdsec and uptime-kuma modules`).

### Abandonado: gethomepage/homepage (bug de cache real, não resolvido)

CT 140 foi implantado primeiro com `gethomepage/homepage`, funcionando
(HTTP 200, config correta lida do volume). Depois de trocar
`services.yaml` pra usar domínio público em vez de IP:porta da LAN, a
página continuou servindo o link antigo mesmo após: reload do config,
`docker restart`, e `docker compose up --force-recreate` (container
totalmente novo, volume de config bind-mounted confirmado com o
conteúdo certo via `docker exec cat`). A app roda em Next.js 16 com os
dados de `services.yaml` embutidos num payload `fallback` de
SSR/data-cache — o cache sobrevivendo a uma recriação completa do
container (não só um restart do processo) não teve causa raiz
identificada a tempo de valer a pena continuar investigando, dado que
Homarr (próxima entrada) resolve o mesmo problema com mais recursos.
Substituído por completo — nenhum resquício do stack antigo ficou no
repositório.

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
   (`ansible/playbooks/host_vars/papermoon.yml`), mesmo padrão usado em
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
