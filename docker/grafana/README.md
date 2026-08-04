# grafana (CT 130)

Depende do `prometheus` (131) já estar no ar.

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

Nenhum dashboard pré-criado ainda — fica para quando o `node_exporter` for
adicionado na Fase 4 (ver `docker/prometheus/README.md`), já que sem
métricas de host não há o que exibir de interessante ainda.

## Rede

Porta 3000, liberada só para a LAN de casa
(`ansible/playbooks/host_vars/grafana.yml`).
