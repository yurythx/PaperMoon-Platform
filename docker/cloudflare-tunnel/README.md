# cloudflare-tunnel (CT 101)

Ingress público único de toda a plataforma. Só faz conexões de **saída**
para a borda da Cloudflare — não precisa de nenhuma porta liberada de
entrada no `ufw` (nem mesmo para a LAN).

## Como criar o túnel (ação manual, fora deste repositório)

Isso exige acesso à sua conta Cloudflare — não é algo que dá pra automatizar
sem suas credenciais reais:

```bash
# Em qualquer máquina com cloudflared instalado (não precisa ser o host):
cloudflared tunnel login
cloudflared tunnel create papermoon-platform
```

O segundo comando imprime o **Tunnel ID** e cria um arquivo de credenciais
(`~/.cloudflared/<TUNNEL_ID>.json`).

## Onde colocar os valores reais

1. **Tunnel ID** → `ansible/playbooks/host_vars/cloudflare-tunnel.yml`
   (`cloudflare_tunnel_id`).
2. **Arquivo de credenciais** → copie o conteúdo do JSON gerado para
   `ansible/files/cloudflare-tunnel-credentials.json`, substituindo o
   placeholder. Depois criptografe:
   ```bash
   ansible-vault encrypt ansible/files/cloudflare-tunnel-credentials.json
   ```
3. **Registros DNS**: no painel Cloudflare, aponte os hostnames usados em
   `cloudflare_tunnel_ingress` (`ansible/playbooks/host_vars/cloudflare-tunnel.yml`)
   como CNAME para `<TUNNEL_ID>.cfargotunnel.com`.

## `config.yml` é gerado, não versionado com valor real

`config.yml.j2` (neste diretório) é um template — o Ansible renderiza os
valores reais de `ansible/playbooks/host_vars/cloudflare-tunnel.yml` na hora do
deploy (`docker_app_extra_files` com `template: true`, ver
`ansible/playbooks/deploy-cloudflare-tunnel.yml`). Não crie um
`config.yml` real aqui.

## Ingress inicial: só o PaperMoon

Os hostnames placeholder (`app.papermoon.cloud`, `webhooks.papermoon.cloud`)
apontam para o PaperMoon (192.168.1.102), portas 3000 (Next.js) e 8000
(Django API — usado pelo webhook do Asaas). Se outro app desta plataforma
(Nextcloud, Vaultwarden, etc.) precisar de acesso público no futuro, basta
adicionar uma nova entrada em `cloudflare_tunnel_ingress` — sem tocar no
compose ou no template.
