# nextcloud-redis (CT 122)

Cache/lock de transação e armazenamento de sessão do Nextcloud (120).
Container dedicado, seguindo a mesma lógica de `nextcloud-mariadb`.

**Sem acesso direto** — só o Nextcloud (120) conecta via rede interna. Pra
inspecionar na mão: `docker exec -it nextcloud-redis redis-cli -a
<REDIS_PASSWORD>`.

## Persistência: deliberadamente sem volume

Redis aqui é usado só como cache e file-locking, não como fonte de verdade
de dados. Perder o conteúdo num restart é aceitável (o Nextcloud reconstrói
o cache sozinho) — por isso não há volume nomeado, ao contrário do
`nextcloud-mariadb`. Se isso mudar (ex: usar Redis para algo que precise
sobreviver a restart), adicionar um volume para `/data` e habilitar AOF.

## Autenticação

Senha via `--requirepass` (variável `REDIS_PASSWORD`). Fica visível em
`docker inspect`/lista de processos dentro do container — risco aceito para
este ambiente (LAN interna, sem acesso de terceiros); se isso for uma
preocupação real no futuro, migrar para `redis.conf` montado como arquivo
não muda o nível de proteção de fato (ainda root-legível), então não
prioritizei essa troca agora.

## Rede

Porta 6379 publicada no host, liberada no `ufw` só para o IP do Nextcloud
(192.168.1.120) — ver `ansible/playbooks/host_vars/nextcloud-redis.yml`.

## Variáveis (`.env`)

Ver `.env.example`. Em produção, gerado pelo Ansible a partir de
`host_vars/nextcloud-redis.yml` (vaulted).
