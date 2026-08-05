# crowdsec (CT 132)

## Arquitetura — engine central + bouncer em cada host

CrowdSec é composto de duas peças que normalmente vivem em máquinas
diferentes:

- **Engine (LAPI)** — lê logs, detecta padrões de ataque via cenários, e
  mantém a lista de decisões (IPs bloqueados). É isso que roda aqui (CT 132).
- **Bouncer** — processo leve que aplica o bloqueio de fato (`iptables`)
  na máquina que precisa ser protegida, falando com o LAPI central. Ver
  `ansible/roles/crowdsec_bouncer/README.md`.

**Fase 1** (este CT): só o engine, lendo o próprio `auth.log`.
**Fase 2** (concluída — todos os outros 12 `docker_hosts`, incluindo
`papermoon` e `vaultwarden`, têm `crowdsec-firewall-bouncer` instalado e
registrado contra este LAPI): uma detecção em qualquer host da rede (ou a
blocklist coletiva da comunidade CrowdSec) vira bloqueio em todos, sem
esperar log próprio de cada um. Proxmox host (bare-metal) deliberadamente
**fora** do rollout automatizado — sem forma de recuperar via `pct exec`
se uma regra de firewall der errado nele, ao contrário de qualquer LXC.

## Por que um LXC dedicado, e não junto de outro serviço

Mesmo padrão do resto da plataforma: um LXC por responsabilidade,
reconstruível via Terraform sem afetar os demais. CrowdSec também é o
tipo de serviço que idealmente sobrevive independente do que ele está
protegendo — colocar no mesmo LXC de outra app criaria acoplamento
desnecessário.

## Rede

Porta 8080 (LAPI) liberada só para a LAN de casa
(`ansible/playbooks/host_vars/crowdsec.yml`) — nunca deve ser exposta pra
internet. Bouncers de outros hosts (Fase 2) vão se autenticar contra essa
porta com uma API key gerada via `cscli bouncers add <nome>` dentro do
container, uma por host — não existe segredo pré-compartilhado a
configurar nesta Fase 1.

## Gotcha real: a imagem vem com um `acquis.yaml` placeholder

A imagem oficial (`crowdsecurity/crowdsec`) sobe com um `acquis.yaml`
padrão que literalmente aponta pra `/does/not/exist` — o engine carrega
os cenários normalmente e não dá erro nenhum, mas nunca lê log de
verdade até você sobrescrever esse arquivo. Achado ao verificar o
container recém-implantado (`docker logs crowdsec` mostrava
`"No matching files for pattern /does/not/exist"`). `acquis.yaml` deste
diretório é montado por cima (mais específico que o volume
`crowdsec_config`) apontando pro `auth.log` de verdade.

## Persistência

`crowdsec_config` (parsers/cenários instalados via `cscli hub`,
sobrevive a upgrade de imagem) e `crowdsec_data` (banco local de
decisões/alertas, SQLite). Sem isso, cada restart perderia o estado do
hub e teria que reinstalar as coleções do zero (`COLLECTIONS` no
`.env` cobre isso automaticamente, mas manter o volume evita o
download repetido).

## Verificar que está funcionando

```bash
docker exec crowdsec cscli metrics       # cenários carregados, linhas parseadas
docker exec crowdsec cscli decisions list  # IPs banidos até agora (vazio é normal no início)
```

## Verificar a Fase 2 (bouncers)

```bash
docker exec crowdsec cscli bouncers list   # todos os 12 hosts, "Last API pull" recente = vivo
```

## Próximo passo em aberto

Proxmox host (bare-metal) sem bouncer — decisão deliberada, não esquecimento
(ver acima). Se algum dia for feito, exige cuidado redobrado e um plano de
recuperação fora de banda (console físico/IPMI), não só confirmação normal.
