# CI/CD — Deploy automático do PaperMoon (CT 102)

Pipeline **separado** do `cd.yml` que já existe no repositório do PaperMoon
(esse continua cuidando do deploy na VPS de produção, via `deploy.sh`). Este
documento cobre o novo `deploy.yml`, que dispara em todo push na `main` do
repositório do PaperMoon e atualiza o LXC 102 deste Proxmox.

## Arquitetura

```
push na main (github.com/yurythx/papermoon)
        │
        ▼
GitHub Actions (runner ubuntu-latest, na nuvem)
        │  entra na tailnet via OAuth client
        ▼
Tailscale (rede privada) ──► pve1 (100.127.151.5), porta 22
        │  SSH com chave de comando forçado (só roda 1 comando específico)
        ▼
git pull do PaperMoon-Platform + ansible-playbook playbooks/deploy-papermoon.yml
        │  (rodando local no control node, contra o LXC 102 via SSH interno)
        ▼
CT 102: build → migrate → collectstatic → up -d → prune
```

**Por que Tailscale em vez de expor SSH do Proxmox na internet**: o host
não tem — e não deve ter — porta 22 aberta publicamente. O Tailscale já
está instalado e conectado nele (Fase 1/Bootstrap); a Action só entra
temporariamente na mesma rede privada pra alcançar o IP interno
(`100.127.151.5`), sem criar nenhuma exposição nova.

**Por que uma chave SSH com `command=` forçado, não a chave de automação
já existente do Terraform**: se o secret do GitHub vazar, um atacante só
consegue rodar exatamente o comando fixado no `authorized_keys` do
servidor — nada além disso, nem um shell interativo. Isso já foi
configurado no host real:

```bash
# /root/.ssh/authorized_keys (linha adicionada, não a chave de automação normal)
command="cd /root/PaperMoon-Platform && git pull -q --ff-only && cd ansible && /root/ansible-venv/bin/ansible-playbook playbooks/deploy-papermoon.yml",restrict ssh-ed25519 AAAA... github-actions-papermoon-deploy
```

Se precisar recriar essa chave (rotação, ou em outro host), o comando
completo de instalação está em `bootstrap/README.md` (a adicionar quando
este fluxo for promovido a bootstrap oficial — por ora foi feito
manualmente, documentado aqui).

## Secrets a configurar no GitHub (repositório `yurythx/papermoon`)

Settings → Secrets and variables → Actions → New repository secret:

| Secret | Valor | Como obter |
|---|---|---|
| `TS_OAUTH_CLIENT_ID` | ID do OAuth client da Tailscale | Tailscale Admin Console → Settings → OAuth clients → Generate. Escopo mínimo: `devices:core` (só precisa conseguir logar como nó efêmero). |
| `TS_OAUTH_SECRET` | Secret do mesmo OAuth client | Gerado junto com o client acima — só é mostrado uma vez. |
| `PROXMOX_TAILSCALE_IP` | `100.127.151.5` | IP Tailscale do `pve1` (`tailscale status` no host). |
| `PROXMOX_CI_SSH_KEY` | Conteúdo da chave **privada** `github-actions-papermoon-deploy` | Gerada localmente ao configurar isso — guarde só no secret do GitHub, não sobra cópia em lugar nenhum do repositório. |

Também crie o **Environment** `proxmox-homelab` (Settings → Environments) —
opcionalmente com "required reviewers" se quiser aprovar manualmente antes
de cada deploy, mesmo padrão que o `cd.yml` já usa pro ambiente
`production`.

## Verificar as ACLs da Tailscale

Por padrão, contas Tailscale novas permitem todo-para-todo dentro da
mesma tailnet — o runner efêmero (tag `tag:ci`) provavelmente já alcança
`pve1` na porta 22 sem configuração extra. Se sua conta tiver ACLs mais
restritas, adicione uma regra permitindo `tag:ci` → `pve1:22`.

## O que este pipeline NÃO faz (ainda)

- **Rollback automático** — o `deploy.sh` antigo tinha isso (reverte pro
  commit anterior se o health-check falhar); o novo playbook Ansible
  declarativo (`ansible/playbooks/deploy-papermoon.yml`) ainda não
  reimplementa essa parte. Se o health-check falhar, o job do GitHub
  Actions falha e alguém precisa investigar/reverter manualmente.
- **Notificação** (Slack/Discord/e-mail) de sucesso ou falha — só aparece
  como status do próprio GitHub Actions.
