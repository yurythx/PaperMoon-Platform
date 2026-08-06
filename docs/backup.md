# Fase 4 — Backup

## Escopo: só os hosts com dado real, não regenerável

| Host | O que é salvo | Prioridade |
|---|---|---|
| `papermoon` | dump do Postgres + volume de mídia (uploads) | Máxima — dado de negócio (clientes, faturas) |
| `nextcloud-mariadb` | dump do MariaDB | Alta |
| `nextcloud` | volume de dados (arquivos dos usuários) | Alta |
| `vaultwarden` | volume de dados (SQLite + anexos) | Máxima — perder isso é perder senhas de verdade |

Os outros 10 hosts (Jellyfin, Komga, qBittorrent, Navidrome, Redis do
Nextcloud, Grafana, Prometheus, Cloudflare Tunnel, Homarr, test-stack)
**não têm backup automatizado** — ou porque o dado é 100% regenerável
(Prometheus, cache do Redis, test-stack), ou porque é só
configuração/preferência de baixo custo para refazer manualmente
(Jellyfin/Komga/Navidrome só guardam metadados — a mídia em si já está na
origem, no storage NFS). Homarr é o único caso "deveria ter, ainda não tem"
da lista — o board/preferências (SQLite em `homarr_appdata`) só existe
naquele volume; perder o host sem backup significa remontar o board na mão
na UI. Se isso mudar, adicionar `backup_jobs` no `host_vars/<host>.yml`
correspondente — a role já suporta.

## Como funciona

Role Ansible `backup` (aplicada a todo `docker_hosts`, mas só age onde
`backup_jobs` está definido em `host_vars/`):

1. Gera um script (`/usr/local/bin/papermoon-platform-backup.sh`) a partir
   de `ansible/roles/backup/templates/backup.sh.j2`, com um bloco por job.
2. Agenda via cron do sistema, todo dia às 03:00.
3. Tipos de job suportados:
   - `postgres` — `docker exec ... pg_dump | gzip`
   - `mariadb` — idem com `mysqldump` (senha via `MYSQL_PWD` env, não na
     linha de comando, para não aparecer em `ps aux`)
   - `volume` — `tar` do volume Docker nomeado, via um container Alpine
     descartável montando o volume — evita precisar saber o path real do
     volume no filesystem do host.
4. Retenção: arquivos locais mais antigos que `backup_retention_days`
   (default 7) são apagados a cada execução.

## Destino dos backups: ainda não decidido

`backup_destination_dir` (default `/opt/backups`, disco local do próprio
LXC) é um **placeholder deliberado** — na conversa de definição desta fase,
ficou em aberto se o destino final seria um diretório novo no storage NFS
(mais capacidade, mas exige criar a pasta no servidor NFS por fora deste
repositório) ou continuar local. Guardar localmente já funciona e protege
contra erro humano/corrupção de app, mas **não protege contra falha do
disco do LXC** — não é uma estratégia de backup completa até essa decisão
ser tomada.

Trocar o destino depois é uma mudança de uma linha
(`ansible/roles/backup/defaults/main.yml` ou um override em
`group_vars/all.yml`), sem tocar em nenhum outro arquivo.

## Verificar nomes de volume antes de confiar

Os jobs do tipo `volume` (`nextcloud-data`, `vaultwarden-data`,
`papermoon-media`) assumem o nome de projeto Compose = nome do diretório
(comportamento padrão do Docker Compose). Confirme com `docker volume ls`
no host real antes do primeiro backup — se estiver errado, é um ajuste
pontual no `host_vars/<host>.yml` correspondente.

## Restaurar um backup

```bash
# Postgres/MariaDB:
gunzip -c backup.sql.gz | docker exec -i <container> psql -U <user> <db>       # Postgres
gunzip -c backup.sql.gz | docker exec -i <container> mysql -u <user> -p<senha> <db>  # MariaDB

# Volume:
docker run --rm -v <volume>:/target -v $(pwd):/backup alpine \
  tar xzf /backup/<arquivo>.tar.gz -C /target
```

Pare o container da aplicação antes de restaurar um volume, para não
escrever por cima de arquivos em uso.
