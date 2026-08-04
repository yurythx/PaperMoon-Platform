# nextcloud (CT 120)

Depende de `nextcloud-mariadb` (121) e `nextcloud-redis` (122) já estarem
no ar antes do primeiro `docker compose up`.

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

Por padrão só o IP da LAN (`192.168.1.120`). Se/quando o Nextcloud ganhar
acesso público via Cloudflare Tunnel, adicionar o domínio público aqui
também (lista separada por espaço) — senão o Nextcloud recusa a requisição
com "Trusted domain error".

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

Porta 8080 publicada e liberada no `ufw` para a LAN inteira por enquanto
(`ansible/playbooks/host_vars/nextcloud.yml`). Se um dia o Nextcloud for exposto
publicamente via Cloudflare Tunnel, restringir essa regra ao IP do túnel
(101), no mesmo padrão já usado para as portas de banco/cache.
