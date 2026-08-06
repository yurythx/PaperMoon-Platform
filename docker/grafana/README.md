# grafana (CT 130)

Dashboards de métricas de toda a frota — visualiza o que o Prometheus (131)
coleta. Depende do `prometheus` (131) já estar no ar.

## Acesso

| | |
|---|---|
| **LAN** | `http://192.168.1.130:3000` |
| **Domínio público** | `https://grafana.papermoon.cloud` — ⚠️ rota do Cloudflare Tunnel com problema no momento (HTTP 530); usar o acesso via LAN até corrigir no painel Zero Trust |
| **Login** | `GF_ADMIN_USER`/`GF_ADMIN_PASSWORD` (`ansible/playbooks/host_vars/grafana.yml`, vault) |

## Datasource provisionado automaticamente

`provisioning/datasources/prometheus.yml` registra o Prometheus
(`http://192.168.1.131:9090`) como datasource padrão assim que o Grafana
sobe — sem precisar configurar isso manualmente pela UI. `editable: false`
é proposital: evita que alguém troque a URL sem querer pela interface e
"perca" a fonte real de métricas (para mudar, edite o arquivo e rode o
deploy de novo).

Se o IP do Prometheus mudar no Terraform, atualizar aqui também — não há
descoberta automática, é hardcoded.

## Dashboards

Nenhum dashboard pré-criado — `node_exporter` já roda em todos os 14 hosts
(Fase 4 concluída), então as métricas já estão disponíveis no datasource;
falta só importar/criar os dashboards na UI (ex: o dashboard oficial "Node
Exporter Full", ID `1860` em grafana.com/dashboards, funciona direto).

## Rede

Porta 3000, liberada só para a LAN de casa
(`ansible/playbooks/host_vars/grafana.yml`).
