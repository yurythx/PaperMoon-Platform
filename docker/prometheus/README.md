# prometheus (CT 131)

Coleta (scrape) e armazena métricas de toda a frota — a fonte de dados por
trás dos dashboards do Grafana (130). Uso direto normalmente é só pra
depurar uma query PromQL ou conferir o status de um scrape target; o dia a
dia é via Grafana.

## Acesso

| | |
|---|---|
| **LAN** | `http://192.168.1.131:9090` |
| **Domínio público** | `https://prometheus.papermoon.cloud` |
| **Login** | nenhum — sem autenticação própria (ver nota de segurança abaixo) |
| **Alvos monitorados** | `http://192.168.1.131:9090/targets` |

⚠️ Prometheus não tem autenticação nativa — expor publicamente via
Cloudflare Tunnel significa que qualquer um com o link vê métricas
internas da frota (não segredos, mas ainda assim informação operacional).
Considerar Cloudflare Access na frente dessa rota se isso for uma
preocupação real.

## Monitoramento da frota (Fase 4)

`prometheus.yml` faz scrape de si mesmo (`localhost:9090`) e de todos os 14
hosts via `node_exporter` (porta 9100, instalado pela role Ansible
homônima em todo `docker_hosts`), além de um job dedicado pro cAdvisor do
test-stack (150, porta 8081). O `ufw` de cada host libera 9100 só para
o IP do Prometheus (`firewall_common_ports` em `group_vars/docker_hosts.yml`).

## Dashboard no Grafana

Não incluímos um JSON de dashboard pronto neste repositório (o dashboard
"Node Exporter Full" da comunidade tem milhares de linhas — melhor importar
oficialmente do que copiar um JSON desatualizado). Depois que o Prometheus
e o node_exporter estiverem coletando dados:

1. No Grafana, vá em **Dashboards → Import**.
2. Use o ID **1860** (Node Exporter Full, mantido pela comunidade Grafana).
3. Selecione o datasource "Prometheus" (já provisionado automaticamente).

## Retenção

15 dias por padrão (`RETENTION` no `.env`) — ajuste conforme o disco
alocado (16GB, ver `docs/terraform.md`) e a quantidade de métricas depois
que o `node_exporter` entrar em cena.

## Configuração é um bind mount, não `.env`

`prometheus.yml` é montado diretamente (`./prometheus.yml:/etc/prometheus/prometheus.yml:ro`)
— o Ansible copia esse arquivo via `docker_app_extra_files` (não é gerado a
partir do `.env`, ao contrário dos outros apps). Para mudar a configuração
de scrape, edite `docker/prometheus/prometheus.yml` direto e rode o deploy
de novo.

## Rede

Porta 9090, liberada só para a LAN de casa
(`ansible/playbooks/host_vars/prometheus.yml`).
