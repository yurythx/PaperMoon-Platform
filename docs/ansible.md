# Fase 3a — Ansible (núcleo)

## Objetivo

Deixar os 12 LXCs criados na Fase 2 totalmente configurados (sistema,
Docker, firewall) e prontos para receber qualquer stack — sem repetir
lógica entre hosts ou entre apps.

Esta fase foi dividida em duas entregas:
- **3a (esta)**: roles de sistema + mecanismo genérico de deploy.
- **3b (próxima, incremental)**: `docker-compose.yml` de cada app em
  `docker/<app>/` + um `playbooks/deploy-<app>.yml` por app, feitos um de
  cada vez.

## Estrutura

```
ansible/
├── ansible.cfg
├── requirements.yml            # collections: community.general, community.docker, ansible.posix
├── site.yml                     # wrapper -> playbooks/site.yml (para bater com o comando do CLAUDE.md)
├── inventory/production.yml     # 12 hosts, IPs fixos (bater com o output do Terraform)
├── files/                       # segredos não-YAML (ex: credentials.json do cloudflared)
├── playbooks/
│   ├── site.yml                 # aplica common+docker_engine+node_exporter+backup+firewall em todos os hosts
│   ├── deploy-<app>.yml         # 1 por app (Fase 3b) — a maioria usa a role docker_app
│   ├── templates/               # templates específicos de playbook (ex: .env.production do PaperMoon)
│   ├── group_vars/              # IMPORTANTE: aqui, não em ansible/group_vars — ver nota abaixo
│   │   ├── all.yml               # usuário de suporte, timezone, chaves SSH, firewall_lan_cidr
│   │   └── docker_hosts.yml      # pacotes do Docker + firewall_common_ports (ex: node_exporter)
│   └── host_vars/               # IMPORTANTE: aqui, não em ansible/host_vars — 1 arquivo por app
└── roles/
    ├── common/                  # timezone, usuário suporte, hardening de SSH, unattended-upgrades
    ├── docker_engine/           # instala Docker CE + Compose plugin
    ├── node_exporter/           # métricas de host pro Prometheus (Fase 4)
    ├── backup/                  # cron de backup local, só nos hosts com backup_jobs (Fase 4)
    ├── firewall/                 # ufw: nega por padrão, libera SSH + portas comuns + específicas
    └── docker_app/               # genérica — usada pela maioria dos apps da Fase 3b
```

## Decisões técnicas

### `group_vars`/`host_vars` moram em `playbooks/`, não na raiz de `ansible/`

Descoberto rodando de verdade contra o host real: o Ansible resolve
`group_vars`/`host_vars` relativos ao diretório do **arquivo de playbook
que está sendo executado**, não ao diretório do wrapper `ansible/site.yml`
nem ao diretório do inventário. Como todo playbook deste projeto mora em
`ansible/playbooks/`, era ali que essas pastas precisavam estar —
mantê-las em `ansible/group_vars/`/`ansible/host_vars/` (a estrutura
original, nunca testada contra infraestrutura real) fazia toda variável
resolver como `undefined` silenciosamente ao rodar qualquer playbook. Só
apareceu na primeira execução real porque não há como isso ser pego por
`--syntax-check` ou validação de YAML — é puramente sobre onde o Ansible
procura essas pastas em tempo de execução.

**Nota honesta sobre o processo de debug:** no caminho até achar essa causa
real, chegamos a suspeitar (e "corrigir") coisas que não eram o problema —
renomear a variável `timezone`, trocar o módulo `community.general.timezone`
por `timedatectl`, e até trocar `ansible-core` 2.19 por 2.17 via venv. Nenhuma
dessas era a causa raiz (o erro persistiu idêntico em todas), mas não são
mudanças ruins por si só — `timedatectl` é mais simples que o módulo, e
`ansible-core` 2.17 é uma versão mais madura que a 2.19 (lançada há pouco
tempo) — então ficaram. Mas o bug de verdade era só a localização das pastas.

### Control node: o próprio Proxmox

Terraform e Ansible rodam diretamente no host Proxmox (`pve1`), não numa
máquina separada — evita o problema de Ansible não rodar nativamente no
Windows, e o host já tem acesso de rede a tudo que precisa gerenciar.
`ansible-core` fica isolado num venv (`/root/ansible-venv`) para não brigar
com nenhum pacote Python do próprio sistema Proxmox.

### Inventário estático

Ver decisão já registrada na proposta de arquitetura: os IPs são fixos
(definidos no Terraform), então listar os 12 hosts à mão em
`inventory/production.yml` é mais simples que manter um inventário
dinâmico. Conferir com `terraform output inventory` se algo divergir.

### Usuário `suporte` + hardening de SSH em ordem segura

A role `common` cria o usuário `suporte` com sudo sem senha (necessário
porque a automação não tem TTY para digitar senha) e só desabilita login de
root/senha via SSH **depois** que a chave do `suporte` já está confirmada —
nessa ordem, nunca existe uma janela em que o host fica inacessível.

**Consequência operacional:** num host novo (recém-criado pelo Terraform),
o usuário `suporte` ainda não existe, então a primeira execução precisa
mirar `root` explicitamente:

```bash
cd ansible
ansible-playbook site.yml -e ansible_user=root
```

Da segunda execução em diante, o padrão do inventário (`ansible_user:
suporte`) já funciona, porque a role `common` é idempotente (não recria o
que já existe).

### Docker Engine via repositório oficial (não `docker.io` do Ubuntu)

O pacote `docker.io` dos repositórios padrão do Ubuntu costuma ficar
desatualizado e não inclui o `docker-compose-plugin` na mesma versão do
Docker CE. A role `docker_engine` segue o método oficial (chave GPG +
repositório próprio da Docker Inc.).

### Firewall (`ufw`) habilitado por host

Confirmado com o usuário. Política padrão: negar toda entrada, liberar
saída, permitir SSH (22) e as portas listadas em `firewall_allowed_ports`
(default vazio em `group_vars/all.yml`, sobrescrito por host em
`host_vars/<app>.yml` na Fase 3b, quando o `docker-compose.yml` de cada app
definir suas portas expostas).
**Ordem importa:** as regras de `allow` são aplicadas antes de `ufw
enable`, para nunca haver risco de travar o próprio acesso SSH.

### Segredos via Ansible Vault

`host_vars/<app>.yml` com credenciais (senha do MariaDB, token do
Vaultwarden, etc.) deve ser criptografado com `ansible-vault encrypt`. A
senha do vault fica em `.vault_pass` (fora do Git, `.gitignore` já cobre) e
é referenciada em `ansible.cfg` (`vault_password_file`, comentado até a
Fase 3b criar o primeiro segredo).

### Role `docker_app` genérica

Uma única role, parametrizada (`docker_app_name`, `docker_app_compose_src`,
`docker_app_env`), reaproveitada pela maioria dos `playbooks/deploy-<app>.yml` da
Fase 3b — evita duplicar "criar diretório → copiar compose → gerar .env →
`docker compose up -d`" dez vezes. Detalhes de uso em
[`ansible/roles/docker_app/README.md`](../ansible/roles/docker_app/README.md).

## Pré-requisitos antes de rodar

- Fases 1 e 2 concluídas (host bootstrapped, LXCs criados pelo Terraform).
- Ansible >= 2.15 instalado na máquina controladora.
- `ansible-galaxy install -r requirements.yml` executado uma vez.
- `group_vars/all.yml` com a(s) chave(s) SSH pública(s) reais (mesmas do
  `terraform.tfvars`).

## Como executar

```bash
cd ansible
ansible-galaxy install -r requirements.yml
ansible-playbook site.yml -e ansible_user=root   # só na primeira vez por host novo
ansible-playbook site.yml                         # execuções seguintes
```

## Verificação pós-execução

```bash
ansible docker_hosts -m ping                      # todos devem responder como "suporte"
ansible docker_hosts -a "docker --version"
ansible docker_hosts -a "ufw status verbose"
```

## Status

Fase 3b concluída — os 12 apps têm stack + playbook de deploy (ver
`docs/docker.md` para a tabela completa). Fase 4 (monitoramento de frota,
backup, atualizações, disaster recovery) também concluída — ver
`docs/backup.md`, `docs/atualizacoes.md` e `docs/disaster-recovery.md`.
