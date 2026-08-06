# nextcloud (CT 120)

Armazenamento de arquivos e colaboração — um "Google Drive" self-hosted.
Depende de `nextcloud-mariadb` (121) e `nextcloud-redis` (122) já estarem
no ar antes do primeiro `docker compose up`.

## Acesso

| | |
|---|---|
| **LAN** | `http://192.168.1.120:8080` |
| **Domínio público** | `https://nextcloud.papermoon.cloud` |
| **Login** | conta admin criada no primeiro `docker compose up` (`NEXTCLOUD_ADMIN_USER`/`NEXTCLOUD_ADMIN_PASSWORD`, `ansible/playbooks/host_vars/nextcloud.yml`, vault) |

## Imagem: `nextcloud:29-apache`, não separado nginx+php-fpm

Escolhida a variante "tudo em um" (Apache embutido) em vez de compor
nginx + php-fpm em containers separados — para uma instância pessoal isso
seria complexidade sem benefício real (a separação nginx/php-fpm só
compensa em cenários de alta escala/múltiplas réplicas). SSL/TLS é
responsabilidade do Cloudflare Tunnel (termina HTTPS na borda), então o
container só precisa falar HTTP puro na LAN.

## Persistência

`nextcloud_data` (volume nomeado, disco local do LXC — ver decisão em
`docs/terraform.md`, container tem 64GB alocados) guarda `/var/www/html`
inteiro: config, apps instalados e os arquivos dos usuários. Backup real
fica para a Fase 4 (Operação).

## `NEXTCLOUD_TRUSTED_DOMAINS`

**Cuidado real, já mordeu antes:** essa env var só é lida por `occ` no
**install-time** (primeiro `docker compose up`) — mudar o valor depois e
subir de novo **não** atualiza a instância já instalada, ela continua
recusando com "Trusted domain error" para qualquer domínio adicionado
depois. Para adicionar um domínio numa instância já rodando:

```bash
docker exec -u www-data nextcloud php occ config:system:get trusted_domains
docker exec -u www-data nextcloud php occ config:system:set trusted_domains <próximo_índice> --value=<dominio>
```

`ansible/playbooks/deploy-nextcloud.yml` já faz isso automaticamente (tasks
pós-instalação, idempotentes) — não precisa rodar na mão, mas é útil saber
o motivo se um domínio novo "não pegar" mesmo depois do deploy.

## Cron

O Nextcloud precisa rodar `cron.php` periodicamente para tarefas de fundo
(ao invés do modo AJAX, menos confiável). Isso é configurado como um cron
do sistema no host, não dentro do compose — ver
`ansible/playbooks/deploy-nextcloud.yml`.

## Atenção: credenciais duplicadas em 3 arquivos

`MYSQL_PASSWORD` aqui **precisa ser idêntico** ao `mariadb_password` em
`ansible/playbooks/host_vars/nextcloud-mariadb.yml`, e `REDIS_HOST_PASSWORD` precisa
bater com `redis_password` em `ansible/playbooks/host_vars/nextcloud-redis.yml`. Não
há mecanismo automático ligando os três — se trocar a senha em um lugar,
troque nos outros dois também.

## Rede

Porta 8080 publicada e liberada no `ufw` para a LAN inteira
(`ansible/playbooks/host_vars/nextcloud.yml`) — o acesso público real passa
pelo Cloudflare Tunnel (101), que alcança essa mesma porta pela LAN, não
por uma regra de firewall dedicada só a ele.
