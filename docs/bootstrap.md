# Fase 1 — Bootstrap

## Objetivo

Deixar o host Proxmox no estado mínimo necessário para que a Fase 2
(Terraform) consiga criar e gerenciar toda a infraestrutura sem nenhuma
intervenção manual adicional.

## Por que não é Terraform {#por-que-nao-e-terraform}

O provider Terraform do Proxmox fala com a API do próprio Proxmox — mas
alguém precisa criar essa API/credencial primeiro, e o Terraform não
consegue instalar Tailscale no host, registrar um storage NFS ou baixar um
template de container por conta própria. É o problema de "quem provisiona o
provisionador". Por isso essa camada é um conjunto pequeno de scripts
versionados e idempotentes em [`bootstrap/`](../bootstrap/), não Terraform —
e também não é feita "à mão e esquecida": é reproduzível, documentada e
auditável como o resto da plataforma.

## Escopo

| Script | O que faz | Por quê |
|---|---|---|
| `01-nfs-storage.sh` | Registra os pools NFS (192.168.1.14) como storage no Proxmox (`pvesm add nfs`) e garante a estrutura `media/books/downloads` dentro de cada um. No host real (`pve1`) já existiam como `TrueNAS-NFS`/`TrueNAS-NFS2`, montados em `/mnt/pve/TrueNAS-NFS` e `/mnt/pve/TrueNAS-NFS2` (exports `/mnt/Pool_HD1/Dados` e `/mnt/Pool_HD2/Dados2`) — o script detectou e só criou a estrutura de pastas, que não existia ainda | Base para os bind mounts (`mp0`, `mp1`) que o Terraform declara em cada LXC na Fase 2 |
| `02-terraform-user.sh` | Cria `terraform@pve` (realm nativo do Proxmox, sem login Linux), uma role customizada com privilégios mínimos, e um token de API | Terraform nunca usa `root@pam` — segue o princípio de segurança/menor privilégio |
| `03-lxc-template.sh` | Baixa o template Ubuntu Server 24.04 LTS para o storage `local` | Template base padronizado que todo módulo Terraform de LXC vai reutilizar |
| `04-tailscale.sh` | Instala e conecta o Tailscale no host Proxmox | Acesso administrativo remoto seguro à web UI (porta 8006) e SSH, sem expor o Proxmox à internet |

## Decisões técnicas e trade-offs

### NFS via `pvesm add` em vez de `/etc/fstab`

**Decisão:** registrar os shares como storage nativo do Proxmox.
**Vantagem:** o `pve-manager` cuida de montar no boot, exibe status no
`pvesm status`/GUI, e não trava o boot se o NFS estiver indisponível.
**Desvantagem:** o storage é registrado com `--content images` — um
detalhe cosmético (o Proxmox exige algum tipo de conteúdo válido), já que na
prática só usamos o diretório montado como origem de bind mounts, não como
storage de discos de VM.

### Usuário de serviço no realm `pve`, não `pam`

**Decisão:** `terraform@pve` em vez de um usuário Linux real.
**Vantagem:** não existe shell, senha de sistema ou superfície de ataque
SSH associada a essa conta — é uma identidade só de API.
**Desvantagem:** nenhuma relevante; é estritamente mais seguro para este caso de uso.

### Token com `--privsep 0`

**Decisão:** o token herda diretamente os privilégios do usuário, em vez de
precisar de uma ACL própria.
**Vantagem:** simplicidade — como o usuário já tem privilégio mínimo por
design, não há necessidade de uma segunda camada de restrição no token.
**Desvantagem:** se o token vazar, o blast radius é igual ao do usuário
inteiro (mitigado pelo escopo já mínimo da role).

### Regeneração de token é manual, nunca automática

**Decisão:** `02-terraform-user.sh` nunca recria um token que já existe.
**Por quê:** o segredo só é exibido uma vez, no momento da criação. Rodar o
script de novo e silenciosamente gerar um token novo invalidaria o token que
o Terraform em produção já está usando — uma ação destrutiva demais para
acontecer como efeito colateral de uma reexecução idempotente.

### Tailscale só no host, não em containers

**Decisão:** conforme alinhado com o usuário, o Tailscale cobre apenas o
plano de administração do host Proxmox.
**Por quê:** o Cloudflare Tunnel (CT 101, já existente) já resolve o plano de
ingress público das aplicações — colocar Tailscale também dentro de cada
container seria redundante e aumentaria a superfície de manutenção sem
necessidade real neste momento.

## Pré-requisitos antes de rodar

- Acesso root (SSH ou console) ao host Proxmox.
- Storage NFS (`192.168.1.14`) acessível na rede a partir do Proxmox.
- Uma auth key do Tailscale gerada em
  https://login.tailscale.com/admin/settings/keys (necessária só para
  `04-tailscale.sh`).

## Como executar

Ver [`bootstrap/README.md`](../bootstrap/README.md) para os comandos exatos.

## Verificação pós-bootstrap

```bash
pvesm status                                   # deve listar TrueNAS-NFS e TrueNAS-NFS2
pveum user list                                # deve listar terraform@pve
pveum user token list terraform@pve            # deve listar o token 'provider'
pveam list local | grep ubuntu-24.04           # template disponível
tailscale status                               # host conectado à tailnet
```

## Próximo passo

Com o host pronto, a Fase 2 (Terraform) usa o token gerado aqui como
credencial de provider e os storages `TrueNAS-NFS`/`TrueNAS-NFS2` como
origem dos bind mounts de cada LXC.
