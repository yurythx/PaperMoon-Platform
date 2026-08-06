# Fase 2 — Terraform

## Objetivo

A partir do host preparado na Fase 1, criar os 14 LXCs (101, 102, 110-123, 130, 131, 140, 150)
inteiramente via `terraform apply`, sem nenhum passo manual no Proxmox.
**Nenhum container é pré-existente** — inclusive o Cloudflare Tunnel (101) e
o PaperMoon (102), que uma versão anterior deste documento tratava
incorretamente como "já existentes, não tocar". Só o *código* do PaperMoon
(`docker/papermoon/`) é intocável — a LXC que o hospeda nasce pelo Terraform
como qualquer outra.

## Orçamento de RAM/CPU — restrição real de hardware

O host tem **~15,3GB de RAM utilizável** (16GB nominal; Ryzen 5 PRO 4650G, 6 núcleos/12 threads — confirmado via `/proc/meminfo`, corrigido de "4500" nesta revisão). Isso
não dá pra alocar os containers "confortavelmente" — a primeira versão deste
Terraform somava ~17GB só nos 10 containers de app, sem nem contar 101/102.
Revisado para caber com folga:

| Container | cores | memory_mb | Motivo do tamanho |
|---|---|---|---|
| cloudflare-tunnel (101) | 1 | 512 | cloudflared é só um processo leve, sem estado |
| papermoon (102) | 4 | 3072 | 7 processos Docker (postgres, redis, django, celery-worker, celery-beat, flower, nextjs) |
| jellyfin (110) | 2 | 2048 | Transcodificação via GPU passthrough, não via CPU (ver decisão abaixo) |
| komga (111) | 1 | 768 | Roda em JVM, precisa de um pouco mais que os outros apps leves |
| qbittorrent (112) | 1 | 512 | |
| navidrome (113) | 1 | 512 | Go, muito leve mesmo com biblioteca grande |
| nextcloud (120) | 2 | 1536 | PHP-FPM |
| nextcloud-mariadb (121) | 1 | 1024 | Instância pequena, uso pessoal |
| nextcloud-redis (122) | 1 | 256 | Só cache/lock, sem persistência |
| vaultwarden (123) | 1 | 256 | Binário Rust, extremamente leve |
| grafana (130) | 1 | 512 | |
| prometheus (131) | 1 | 1024 | Poucos hosts/exporters neste homelab |
| homarr (140) | 1 | 512 | Dashboard central — trocado de gethomepage/homepage (bug de cache real não resolvido, ver `docker/homarr/README.md`) |
| test-stack (150) | 2 | 1024 | Locust + OWASP ZAP (JVM) + cAdvisor — LXC isolada de teste de carga/segurança, ver `docker/test-stack/README.md` |
| **Total** | **20** | **~13,25GB** | + ~1,5GB reservado pro Proxmox = ~14,75GB de ~15,3GB utilizáveis (**~3,6% de folga — apertado de novo**) |

CrowdSec (132) e Uptime Kuma (141) foram retirados da stack (destruídos via
Terraform), liberando ~1GB — reocupado quase todo pela LXC de testes (150)
adicionada em seguida. Saldo líquido: praticamente neutro em RAM.

**Ainda sem espaço pra Keycloak+GLPI+n8n+Zabbix** (avaliados numa correção
de infraestrutura posterior) — juntos somariam ~6GB a mais, não cabem no
orçamento atual. Decisão registrada: ficam de fora até resolver hardware.

`cores` é um teto de CPU (soft cap via cgroups do LXC), não uma reserva
exclusiva — por isso a soma pode passar do número de threads físicas (12)
sem problema, desde que nem todos os containers peguem pico de CPU ao
mesmo tempo (cenário realista para um homelab).

Se algum container precisar de mais RAM no futuro, redimensionar é uma
mudança não-destrutiva no Terraform (`memory_mb` do módulo) — mas sempre
conferir a soma total antes de aumentar algo, dado o teto de 16GB.

## Estrutura

```
terraform/
├── modules/lxc/              # definição reutilizável de 1 container
└── environments/production/
    ├── main.tf                # provider bpg/proxmox
    ├── backend.tf             # state local
    ├── variables.tf
    ├── locals.tf               # storages NFS e listas de bind mounts
    ├── containers.tf          # 1 module "lxc" por container (101, 102, 110-123, 130, 131, 140, 150)
    ├── outputs.tf             # inventário hostname -> IP para o Ansible
    └── terraform.tfvars.example
```

Cada container é uma chamada ao mesmo módulo `lxc` — nenhuma duplicação de
lógica entre os 14 CTs.

## Decisões técnicas

### Provider: `bpg/proxmox`

Escolhido em vez do `Telmate/proxmox` por suporte mais completo e ativo a
LXC (bind mounts, features, tags) e schema mais previsível. Confirmado com
o usuário.

### LXC não-privilegiado + `nesting`/`keyctl`

Todos os containers Docker rodam não-privilegiados (`unprivileged = true`
no módulo, que é o default). Um escape do container não compromete
diretamente o host Proxmox. `nesting`/`keyctl` habilitados pois são
pré-requisito para o Docker funcionar dentro de um LXC. Confirmado com o
usuário.

### GPU passthrough no Jellyfin (110) — AMD, via VAAPI

Confirmado com o usuário: GPU AMD disponível para passthrough. O módulo
`lxc` ganhou a variável `device_passthrough`, usada só no Jellyfin para
expor `/dev/dri/renderD128` (dispositivo de render do driver `amdgpu`)
dentro do container não-privilegiado.

**Por que isso basta, sem instalar driver nenhum via Ansible:** um LXC
compartilha o kernel do host Proxmox — o driver `amdgpu` já roda no host;
o container só precisa enxergar o nó de dispositivo. Diferente de uma VM
(que precisaria de VFIO + driver próprio dentro do guest), aqui é só
expor o device. A imagem Docker do Jellyfin (definida na Fase 3b) já traz
as bibliotecas VAAPI userspace necessárias — só vai precisar de
`devices: ["/dev/dri/renderD128:/dev/dri/renderD128"]` no seu
`docker-compose.yml`, apontando para o mesmo device já passado pelo Terraform.

**Verificar antes do primeiro `apply`:**
- `ls -la /dev/dri/` no host Proxmox — confirmar que o device é mesmo
  `renderD128` (pode ter outro número se houver mais de uma GPU/adaptador).
- O schema exato do bloco `device_passthrough` no provider `bpg/proxmox`
  instalado — foi escrito de acordo com a documentação pública do provider,
  mas não pôde ser validado com `terraform validate` neste ambiente (sem
  Terraform CLI disponível). Rodar `terraform plan` primeiro e conferir se o
  bloco é aceito antes de aplicar em produção.

### `dados` e `dados2` são pools independentes, não réplica

Confirmado com o usuário: os dois compartilhamentos NFS têm conteúdo
diferente (não é backup um do outro). Por isso, os apps de mídia (Jellyfin,
Komga, Navidrome) recebem bind mounts dos **dois** pools como bibliotecas
separadas — ex: Jellyfin enxerga `/data/movies-1` (de `dados`) e
`/data/movies-2` (de `dados2`) como duas pastas de biblioteca distintas
dentro do app, não uma única pasta mesclada.

### Nextcloud usa disco local do LXC, não NFS

Confirmado com o usuário: por simplicidade, os dados dos usuários do
Nextcloud (120) ficam num disco maior (64GB) alocado pelo Terraform no
próprio LXC, em vez de um novo diretório no storage NFS — isso evitaria
mexer na estrutura `media/books/downloads` já fixada no servidor NFS
(192.168.1.14), que é externa a este repositório.
**Trade-off:** o Nextcloud fica limitado ao tamanho do disco do LXC. Se o
uso crescer além disso, revisitar essa decisão (redimensionar o disco via
Terraform é uma mudança simples e não-destrutiva).

### qBittorrent só usa o pool `dados` para downloads

Decisão de implementação (não confirmada explicitamente com o usuário):
como `downloads/{complete,incomplete,watch}` é área de staging temporária —
os arquivos saem de lá assim que organizados na biblioteca definitiva — não
pareceu necessário espelhar isso nos dois pools NFS. Se isso não fizer
sentido na prática, é uma mudança pequena em `locals.tf`
(`downloads_mount_points`).

### Convenção de IP: `192.168.1.<CT ID>`

Cada container usa o IP terminado no seu próprio CT ID (ex: CT 110 →
`192.168.1.110`), aplicado uniformemente aos 14 containers, incluindo 101 e
102. **Antes do primeiro `apply`, confirme que nenhum desses IPs já está em
uso** por outro dispositivo na rede (impressora, DHCP de outro host, etc.) —
o Terraform não vai detectar esse conflito por conta própria.

### Cloudflare Tunnel (101) ↔ PaperMoon (102): rede entre LXCs separados

O `docker-compose.prod.yml` original do PaperMoon foi escrito supondo que o
cloudflared rodaria **no mesmo host Docker**, compartilhando uma rede
(`papermoon-network: external: true`) para alcançar `django-api`/`nextjs`
pelo nome do serviço. Como agora são duas LXCs diferentes, isso não
funciona sem ajuste — a resolução fica para a Fase 3b (Ansible/Docker) e
está documentada como pendência em `docs/docker.md`, não neste documento
(Terraform só cria a LXC e a rede L3 entre elas; a configuração de qual
porta o compose publica é responsabilidade da camada Docker).

### State local

Ver comentário em `backend.tf`. Adequado para operador único; documentado
como migrar para backend remoto se isso mudar.

## Autenticação

O provider usa o token de API criado em `bootstrap/02-terraform-user.sh`
(`terraform@pve!provider=<secret>`), passado via `terraform.tfvars`
(gitignored) — nunca hardcoded nos `.tf`.

## Pré-requisitos antes de rodar

- Fase 1 (Bootstrap) concluída e verificada (ver `docs/bootstrap.md`).
- `terraform.tfvars` preenchido a partir do `.example` (endpoint da API,
  token, node name, volid exato do template, chave SSH pública).
- Terraform >= 1.7 instalado na máquina que vai rodar o `apply` (não
  precisa ser o próprio Proxmox).

## Como executar

```bash
cd terraform/environments/production
cp terraform.tfvars.example terraform.tfvars   # preencha os valores reais
terraform init
terraform plan     # revise antes de aplicar
terraform apply
```

## Verificação pós-apply

```bash
terraform output inventory   # deve listar hostname -> IP dos 14 containers
```
No Proxmox: os CTs 101, 102, 110-123, 130, 131, 140, 150 devem aparecer criados e rodando, com
os mount points visíveis em `pct config <vmid>`.

## Próximo passo

Com os LXCs criados, a Fase 3 (Ansible) usa o `terraform output inventory`
como base do inventário para configurar cada host e fazer o deploy dos
`docker-compose.yml` de cada stack.
