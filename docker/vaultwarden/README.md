# vaultwarden (CT 123)

Gerenciador de senhas (servidor compatível com Bitwarden — funciona com o
app/extensão oficial do Bitwarden apontando pro servidor customizado).
Banco interno (SQLite, dentro do volume `vaultwarden_data`) — sem
container de banco separado, conforme `CLAUDE.md`.

## Acesso

| | |
|---|---|
| **LAN** | `http://192.168.1.123:8222` |
| **Domínio público** | `https://vault.papermoon.cloud` — usar este no app/extensão do Bitwarden ("Configurações → Servidor self-hosted") |
| **Painel admin** | `/admin`, autentica com `ADMIN_TOKEN` (ver abaixo) |
| **Cadastro** | `SIGNUPS_ALLOWED=false` por padrão — ver seção abaixo pra criar a primeira conta |

## `ADMIN_TOKEN` precisa ser um hash Argon2, não texto puro

Versões recentes do Vaultwarden exigem que `ADMIN_TOKEN` seja um hash PHC
Argon2, não a senha em texto puro (Vaultwarden avisa e ignora o admin panel
se detectar texto puro). Gere o hash real antes do deploy:

```bash
docker run --rm -it vaultwarden/server /vaultwarden hash
```

Cole a senha quando solicitado, copie o hash gerado (começa com `$argon2...`)
para `ADMIN_TOKEN` no `.env` real (nunca no `.env.example`).

**Se `docker run -it` não tiver TTY disponível** (ex: rodando de dentro de
um `pct exec` remoto sem alocar pseudo-terminal), o binário do Vaultwarden
falha tentando ler `/dev/tty` diretamente. Alternativa que funciona sem
TTY: o CLI `argon2` (pacote `argon2` no apt) gera um hash PHC argon2id
equivalente, que o Vaultwarden aceita normalmente (ele só valida o formato
PHC, não exige que tenha sido gerado pelo binário oficial):
```bash
SALT=$(openssl rand -hex 8)
echo -n "SUA_SENHA" | argon2 "$SALT" -id -t 3 -m 16 -p 4 -l 32 -e
```

**Escapar `$` como `$$` ao colocar o hash em `ADMIN_TOKEN`** — o Docker
Compose interpola `$algo` dentro de valores vindos do `.env` como se fosse
uma variável (`$argon2id`, `$v`, `$m`...), zerando o hash silenciosamente.
Isso já é tratado automaticamente em
`ansible/playbooks/deploy-vaultwarden.yml` — só importa se você for testar
o `docker-compose.yml` manualmente fora do Ansible.

## `DOMAIN`

Precisa bater **exatamente** com a URL usada no navegador/app — afeta
geração de ícones e WebAuthn/passkeys. Já configurado como
`https://vault.papermoon.cloud` (domínio público real, via Cloudflare
Tunnel) — se testar via LAN (`http://192.168.1.123:8222`) em vez do
domínio, WebAuthn/passkeys não funcionam (exigem HTTPS + domínio
consistente).

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
