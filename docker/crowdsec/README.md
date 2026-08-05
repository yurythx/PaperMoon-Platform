# crowdsec (CT 132)

## Escopo desta entrega (Fase 1) — só o engine central

CrowdSec é composto de duas peças que normalmente vivem em máquinas
diferentes:

- **Engine (LAPI)** — lê logs, detecta padrões de ataque via cenários, e
  mantém a lista de decisões (IPs bloqueados). É isso que roda aqui.
- **Bouncer** — processo leve que aplica o bloqueio de fato (`iptables`)
  na máquina que precisa ser protegida, falando com o LAPI central.

Este CT sobe **só o engine**. Sozinho, ele hoje só enxerga o próprio
`auth.log` (tentativas de SSH contra ele mesmo) — pouco tráfego, pouco
valor de proteção por si só. O ganho de segurança de verdade pra
plataforma inteira vem da **Fase 2** (ainda não implementada,
deliberadamente separada): instalar um bouncer leve em cada um dos outros
11 LXCs + Proxmox host, todos registrados contra o LAPI deste container —
uma detecção em qualquer host da rede vira bloqueio em todos.

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

## Próximo passo (Fase 2, não incluída aqui)

Instalar `crowdsec-firewall-bouncer` nos outros 11 LXCs + Proxmox host,
cada um registrado contra `http://192.168.1.132:8080` via
`cscli bouncers add`. Ver `docs/terraform.md`/`docs/ansible.md` quando
essa fase for planejada.
