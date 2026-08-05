# Role `crowdsec_bouncer`

Fase 2 do CrowdSec (ver `docker/crowdsec/README.md`). Instala só o
**bouncer** (`crowdsec-firewall-bouncer`, binário nativo — não é um
container Docker, precisa manipular `iptables` do próprio host) — não um
agente local. O host não detecta nada sozinho, só aplica via `iptables`
as decisões já tomadas pelo engine central (CT 132), incluindo a
blocklist coletiva da comunidade CrowdSec.

## Variáveis

| Variável | Obrigatória | Descrição |
|---|---|---|
| `crowdsec_bouncer_api_key` | sim | Gerada 1x por host no CT 132: `docker exec crowdsec cscli bouncers add <hostname>`. **Não existe forma de recuperar depois de gerada** — só revogar (`cscli bouncers delete <hostname>`) e gerar outra. Deve estar em `host_vars/<app>.yml`, criptografada com `ansible-vault`. |
| `crowdsec_bouncer_version` | não | Default `0.0.36` — pinada de propósito, não "latest" (reprodutibilidade). |
| `crowdsec_lapi_url` | não | Default `http://192.168.1.132:8080` (CT 132). |

## Por que não usar o repositório APT oficial do CrowdSec

Evita depender de gerenciar mais uma chave GPG/repositório externo neste
projeto — o tarball do GitHub Releases já vem com um `install.sh` que
cuida de usuário de sistema, unit systemd e config default, e a versão
fica pinada no `defaults/main.yml` em vez de "latest" (mesmo princípio
de idempotência do resto da plataforma).

## Coexistência com `ufw`

Este host já usa `ufw` pra filtrar entrada de outros hosts da LAN. O
`crowdsec-firewall-bouncer` usa a própria chain iptables (`INPUT`),
inserindo regras de bloqueio por IP no topo — não remove nem substitui
as regras do `ufw`, os dois convivem. `ufw` no Ubuntu 24.04 já roda sobre
o backend `iptables-nft` (compat nftables), mesmo backend que o bouncer
usa por padrão (`mode: iptables`).

## Rollout — feito host por host, não em massa

Cada host precisa de uma API key própria gerada no CT 132 antes de rodar
este role contra ele. Ordem seguida nesta plataforma: `prometheus`
primeiro (baixo risco, monitoramento interno, sem exposição real),
verificado de ponta a ponta, só depois os demais — nunca todos de uma vez,
por mexer em firewall de hosts em produção (`papermoon`, `vaultwarden`
inclusos).
