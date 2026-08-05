# Role `docker_app`

Role genérica que sobe qualquer stack Docker Compose deste monorepo. Usada
por um `playbooks/deploy-<app>.yml` por aplicação (criados na Fase 3b),
nunca diretamente em `site.yml`.

## Variáveis

| Variável | Obrigatória | Descrição |
|---|---|---|
| `docker_app_name` | sim | Nome da app, usado no path padrão de deploy |
| `docker_app_compose_src` | sim | Caminho, no controlador Ansible, do `docker-compose.yml` (normalmente `{{ playbook_dir }}/../../docker/<app>/docker-compose.yml`) |
| `docker_app_dir` | não | Diretório remoto da stack (default `/opt/docker/<docker_app_name>`) |
| `docker_app_env` | não | Dict de variáveis que vira o `.env` da stack (default vazio). **Só é escrito na primeira vez** — re-runs não sobrescrevem um `.env` já existente no host (evita clobbar segredo real com placeholder se o `host_vars` correspondente algum dia regredir). Pra forçar regeneração de propósito (rotação de segredo), apague o `.env` no host antes de rodar de novo, ou passe `docker_app_force_env_regen: true` nessa execução. |
| `docker_app_extra_files` | não | Lista de `{src, dest, template}` para arquivos/pastas extras além de compose+.env (ex: `prometheus.yml`, `provisioning/` do Grafana, `config/settings.yaml` do Homepage). `dest` é relativo a `docker_app_dir` — **o diretório pai é criado automaticamente**, mesmo que `dest` tenha subpasta (ex: `config/settings.yaml` cria `config/` antes de copiar). `template: true` renderiza como Jinja2 em vez de copiar como está. Processados **antes** do `docker compose up`. **Se `src` for uma pasta, termine com `/`** (ex: `.../provisioning/`) — sem a barra, o `copy` do Ansible copia a pasta *para dentro* de `dest`, resultando em `dest/provisioning/...` aninhado em vez do conteúdo direto em `dest/...`. |

## Exemplo (Fase 3b)

```yaml
# playbooks/deploy-jellyfin.yml
- hosts: jellyfin
  roles:
    - role: docker_app
      vars:
        docker_app_name: jellyfin
        docker_app_compose_src: "{{ playbook_dir }}/../../docker/jellyfin/docker-compose.yml"
        docker_app_env:
          PUID: 1000
          PGID: 1000
          TZ: "{{ system_timezone }}"
```

Segredos (senhas, tokens) em `docker_app_env` devem vir de `host_vars/<app>.yml`
criptografado com `ansible-vault`, nunca hardcoded no playbook.
