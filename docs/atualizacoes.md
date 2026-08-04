# Fase 4 — Atualizações

Duas camadas independentes: sistema operacional e aplicação.

## Sistema operacional (patches de segurança)

`unattended-upgrades` (role `common`) aplica patches de segurança do
Ubuntu automaticamente, todos os dias, em todos os hosts. **Não reinicia o
host sozinho** (`Unattended-Upgrade::Automatic-Reboot "false"`) — decisão
confirmada com o usuário, para nunca reiniciar um container sem aviso.

Quando um patch pedir reboot (raro — normalmente só kernel/glibc), o
Ubuntu cria o arquivo `/var/run/reboot-required`. Verificar manualmente:

```bash
ansible docker_hosts -m ansible.builtin.stat -a "path=/var/run/reboot-required"
```

Reiniciar um host quando necessário:

```bash
ansible <hostname> -m ansible.builtin.reboot
```

Como todos os composes usam `restart: unless-stopped`, os containers sobem
sozinhos depois do boot — sem passo manual adicional.

## Aplicação (nova versão de uma stack)

### Apps normais (usam a role `docker_app`)

Reexecutar o playbook de deploy correspondente já resolve — o
`docker_app_extra_files`/`.env` são regerados e o
`community.docker.docker_compose_v2` com `pull: always` puxa a imagem mais
recente e recria só o que mudou:

```bash
ansible-playbook playbooks/deploy-jellyfin.yml   # exemplo — vale para qualquer app da lista
```

Se você mudou a *versão* da imagem (ex: fixar uma tag específica em vez de
`latest`), edite o `docker-compose.yml` daquele app em `docker/<app>/` e
rode o playbook de novo.

### PaperMoon (exceção — usa `deploy.sh` próprio)

```bash
ansible-playbook playbooks/deploy-papermoon.yml
```

Isso invoca o `deploy.sh` do próprio repositório do PaperMoon no host —
`git pull`, build, migrations, health-check e **rollback automático** se
algo falhar. Nada específico deste monorepo a fazer além de rodar o
playbook.

## Infraestrutura (Terraform)

Mudar `cores`/`memory_mb`/disco de um container: editar o módulo em
`terraform/environments/production/containers.tf` e rodar
`terraform plan` / `terraform apply` — não-destrutivo para a maioria dos
atributos (Proxmox aplica a mudança a quente quando possível).
