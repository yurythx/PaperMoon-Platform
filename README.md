# PaperMoon Platform

Monorepo de infraestrutura como código para o homelab PaperMoon: Proxmox VE
+ Terraform + Ansible + Docker Compose, com o objetivo de reconstruir toda
a infraestrutura a partir do zero apenas com:

```bash
terraform apply
ansible-playbook site.yml
```

Governança completa (papel, princípios, decisões arquiteturais) em
[`CLAUDE.md`](./CLAUDE.md) — carregado automaticamente pelo Claude Code
neste diretório.

## Estrutura

```
bootstrap/    # preparo one-time do host Proxmox (NFS, usuário do Terraform, template LXC, Tailscale)
terraform/    # cria os 12 LXCs (módulo reutilizável + ambiente de produção)
ansible/      # configura os hosts e faz o deploy de cada stack Docker
docker/       # 1 pasta por aplicação: docker-compose.yml + .env.example + README.md
docs/         # documentação de cada camada (ver abaixo)
```

## Aplicações

| CT ID | Serviço | Banco |
|---|---|---|
| 101 | Cloudflare Tunnel | — |
| 102 | PaperMoon (SaaS) | PostgreSQL |
| 110 | Jellyfin | SQLite interno |
| 111 | Komga | interno |
| 112 | qBittorrent | — |
| 113 | Navidrome | SQLite interno |
| 120 | Nextcloud | MariaDB + Redis |
| 121 | MariaDB (Nextcloud) | — |
| 122 | Redis (Nextcloud) | — |
| 123 | Vaultwarden | SQLite interno |
| 130 | Grafana | SQLite interno |
| 131 | Prometheus | TSDB próprio |

## Roadmap (4 fases — concluídas)

1. **Bootstrap** — [`docs/bootstrap.md`](docs/bootstrap.md)
2. **Terraform** — [`docs/terraform.md`](docs/terraform.md)
3. **Ansible + Docker** — [`docs/ansible.md`](docs/ansible.md), [`docs/docker.md`](docs/docker.md)
4. **Operação** — [`docs/backup.md`](docs/backup.md), [`docs/atualizacoes.md`](docs/atualizacoes.md), [`docs/disaster-recovery.md`](docs/disaster-recovery.md)

## Antes do primeiro `apply`/`ansible-playbook` real

Este repositório está pronto em código, mas nada foi executado contra
infraestrutura real ainda. Antes de rodar:

- Preencher os `terraform.tfvars` e todos os `ansible/host_vars/*.yml`
  (hoje com placeholders `CHANGE_ME`) com valores reais, e criptografar os
  que têm segredo com `ansible-vault`.
- Criar o túnel Cloudflare de verdade (ver `docker/cloudflare-tunnel/README.md`).
- Decidir o destino final dos backups (ver `docs/backup.md` — hoje é um
  placeholder local).

## Sobre o PaperMoon

`docker/papermoon/` é o código-fonte do SaaS PaperMoon, um repositório Git
próprio (remote: `github.com/yurythx/papermoon`) relocado para dentro deste
monorepo — não é rastreado por este `.git` (ver `.gitignore`). Não
modificar o código da aplicação a partir daqui; só ajustes de deploy
(compose/env) quando estritamente necessários, documentados em
`docker/papermoon/` e `docs/docker.md`.
