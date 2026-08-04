# prometheus (CT 131)

## Monitoramento da frota (Fase 4)

`prometheus.yml` faz scrape de si mesmo (`localhost:9090`) e de todos os 12
hosts via `node_exporter` (porta 9100, instalado pela role Ansible
homônima em todo `docker_hosts`). O `ufw` de cada host libera 9100 só para
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
(`ansible/host_vars/prometheus.yml`).
