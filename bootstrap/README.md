# Bootstrap

Scripts de preparação do host Proxmox, executados **uma vez** (e reexecutáveis
com segurança) antes da Fase 2 (Terraform). Esta é a única camada da
plataforma que não nasce 100% de `terraform apply` — ver justificativa em
[docs/bootstrap.md](../docs/bootstrap.md#por-que-nao-e-terraform).

Todos os scripts rodam **como root, diretamente no host Proxmox** (via SSH ou
console), não a partir desta máquina de desenvolvimento.

## Uso

```bash
cp vars.example.sh vars.sh   # ajuste os valores se necessário
chmod +x *.sh

./01-nfs-storage.sh          # registra storages NFS dados/dados2
./02-terraform-user.sh       # cria usuário + role + token de API do Terraform
./03-lxc-template.sh         # baixa o template Ubuntu 24.04 LXC
export TAILSCALE_AUTHKEY="tskey-auth-xxxxx"
./04-tailscale.sh            # instala e conecta o Tailscale no host
```

`vars.sh` é ignorado pelo Git (contém apenas parâmetros, não segredos — o
segredo real, o token do Terraform e a auth key do Tailscale, nunca é escrito
em disco por estes scripts).

## Ordem de execução

Os scripts são independentes entre si (podem rodar em qualquer ordem ou
isoladamente de novo), mas a numeração reflete a ordem lógica recomendada:
storage → identidade do Terraform → template de CT → acesso remoto.

Detalhes de cada etapa, privilégios concedidos e como verificar o resultado:
ver [docs/bootstrap.md](../docs/bootstrap.md).
