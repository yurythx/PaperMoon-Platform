# vaultwarden (CT 123)

Gerenciador de senhas (servidor compatível com Bitwarden). Banco interno
(SQLite, dentro do volume `vaultwarden_data`) — sem container de banco
separado, conforme `CLAUDE.md`.

## `ADMIN_TOKEN` precisa ser um hash Argon2, não texto puro

Versões recentes do Vaultwarden exigem que `ADMIN_TOKEN` seja um hash PHC
Argon2, não a senha em texto puro (Vaultwarden avisa e ignora o admin panel
se detectar texto puro). Gere o hash real antes do deploy:

```bash
docker run --rm -it vaultwarden/server /vaultwarden hash
```

Cole a senha quando solicitado, copie o hash gerado (começa com `$argon2...`)
para `ADMIN_TOKEN` no `.env` real (nunca no `.env.example`).

## `DOMAIN`

Precisa bater exatamente com a URL usada no navegador/app — afeta geração
de ícones e WebAuthn/passkeys. Por enquanto aponta pro IP da LAN
(`http://192.168.1.123:8222`); se um dia ganhar acesso público via
Cloudflare Tunnel, atualizar para o domínio público (`https://...`).

## `SIGNUPS_ALLOWED=false` por padrão

Mais seguro (ninguém cria conta sozinho). Para criar a primeira conta:
mude temporariamente para `true`, cadastre-se, volte para `false`. Contas
adicionais depois podem ser convidadas via organização, mesmo com signups
desabilitado.

## Backup

Tudo (SQLite + anexos) fica em `/data` (volume `vaultwarden_data`, disco
local do LXC). Prioridade alta de backup na Fase 4 — é o único app aqui
onde perder dados significa perder senhas de verdade.

## Rede

Porta 8222, liberada só para a LAN de casa
(`ansible/playbooks/host_vars/vaultwarden.yml`).
