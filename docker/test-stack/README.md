# test-stack (CT 150)

Stack dedicada de teste de carga e segurança — **Locust** (carga),
**OWASP ZAP** (segurança/pentest) e **cAdvisor** (métricas dos próprios
containers desta stack). Roda isolada numa LXC própria (150), separada de
toda a stack de produção — de propósito, pra nunca correr o risco de gerar
carga/scan a partir de um host que também hospeda algo real.

## ⚠️ Antes de rodar qualquer teste

O alvo default do `locustfile.py` é o **Keycloak real da Prefeitura**
(`sso.rondonopolis.mt.gov.br`), usado em produção por funcionários de
verdade via AD/LDAP. Ler o aviso completo no topo do `locustfile.py` antes
de rodar — resumo:

1. Combine **janela de horário e concorrência** com quem administra o
   AD/Keycloak antes de qualquer execução.
2. Use uma **conta de teste dedicada**, nunca a de um funcionário real —
   política de lockout do AD pode bloquear a conta de alguém de verdade.
3. Comece pequeno (`--users 5 --spawn-rate 1`) e suba aos poucos, olhando o
   Grafana da stack principal (não o dashboard do Locust — ele só vê o lado
   cliente).
4. Segredos só via `.env` gerado pelo Ansible a partir do vault — nunca
   hardcoded no `locustfile.py` (ele lê tudo de `os.environ`).

## Serviços

| Serviço | Porta | Acesso |
|---|---|---|
| Locust | `8089` | `http://192.168.1.150:8089` — UI web, configura usuários/spawn-rate por lá |
| OWASP ZAP | `8080` | `http://192.168.1.150:8080/zap/` — UI completa via `zap-webswing.sh`, sem precisar de X11/VNC |
| cAdvisor | `8081` | `http://192.168.1.150:8081` — métricas só dos 3 containers desta stack |

## Rodar sem UI (headless), ex: pipeline de CI

```bash
docker compose run --rm locust \
  -f /mnt/locust/locustfile.py \
  --headless --users 10 --spawn-rate 2 --run-time 5m \
  --host https://sso.rondonopolis.mt.gov.br
```

## cAdvisor → Prometheus da stack principal

Este cAdvisor **não** se auto-registra em lugar nenhum — adicionar
manualmente o scrape target no `docker/prometheus/prometheus.yml` da stack
principal (job dedicado, já que cAdvisor expõe métricas bem diferentes de
um `node_exporter`):

```yaml
  - job_name: cadvisor-test-stack
    static_configs:
      - targets: ["192.168.1.150:8081"]
```

Depois de editar, reimplantar (`ansible-playbook playbooks/deploy-prometheus.yml`)
e reiniciar o container do Prometheus pra recarregar o config (não tem
`--web.enable-lifecycle` habilitado nesta instância — `docker restart
prometheus` mesmo).

## Por que não usar a role `docker_app` genérica? (Spoiler: usa)

Esta stack usa a mesma role `docker_app` de toda a plataforma — nenhuma
role nova foi criada. `locustfile.py` entra como
`docker_app_extra_files`, exatamente como o `prometheus.yml` da stack de
monitoramento. Ver `ansible/playbooks/deploy-test-stack.yml`.

## TrueNAS e Keycloak não são monitorados pelo Prometheus

Decisão explícita: só o cAdvisor desta stack (containers de teste) entra no
Prometheus. TrueNAS e o Keycloak da Prefeitura ficam de fora — são
infraestrutura de terceiro/fora do escopo desta plataforma.
