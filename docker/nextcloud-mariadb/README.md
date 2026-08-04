# nextcloud-mariadb (CT 121)

Banco de dados dedicado ao Nextcloud (120). Não é um MariaDB de uso geral —
por isso vive na sua própria stack/container em vez de dentro de
`docker/nextcloud/`, seguindo a regra do projeto de "banco dedicado só
quando recomendado" e stacks independentes entre si.

## Configuração

Flags do `command` seguem a recomendação oficial do Nextcloud para MariaDB
(`READ-COMMITTED`, `ROW` binlog, `utf8mb4`) — evita os avisos de
"missing database indices"/collation que o Nextcloud reclama com defaults
padrão do MariaDB.

## Rede

Porta 3306 é publicada no host, mas o `ufw` (role `firewall` do Ansible,
ver `ansible/host_vars/nextcloud-mariadb.yml`) só libera essa porta para o
IP do container Nextcloud (192.168.1.120) — nenhum outro host da LAN
consegue conectar.

## Backup

Dados ficam no volume nomeado `mariadb_data` (disco local do LXC, sem NFS —
ver decisão em `docs/terraform.md`). Backup via `mysqldump` agendado será
tratado na Fase 4 (Operação); por ora, um `docker exec nextcloud-mariadb
mysqldump -u root -p --all-databases` manual já serve de contingência.

## Variáveis (`.env`)

Ver `.env.example`. Em produção, o `.env` real é gerado pelo Ansible
(`playbooks/deploy-nextcloud-mariadb.yml`) a partir de
`host_vars/nextcloud-mariadb.yml` (vaulted) — não edite o `.env` no host
manualmente, ele é sobrescrito a cada `ansible-playbook`.
