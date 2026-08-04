# jellyfin (CT 110)

## GPU (transcodificação de hardware, AMD VAAPI)

O device `/dev/dri/renderD128` já é passado para dentro da LXC pelo
Terraform (`device_passthrough` em `containers.tf`) — como a LXC compartilha
o kernel do host, o container só precisa: (1) montar o mesmo device
(`devices:` no compose) e (2) ter permissão via grupo (`group_add`).

**Antes do primeiro deploy**, descubra o GID do grupo `render` dentro da
própria LXC (não no Proxmox host) e ajuste `RENDER_GID` no `.env`:
```bash
getent group render
```
Se o GID mudar entre o host e a LXC (comum, já que são namespaces
diferentes), use o valor de dentro da LXC — é o que o processo do
container enxerga.

Depois, em **Painel Admin → Reprodução** no Jellyfin, habilite "VAAPI" como
método de transcodificação de hardware, apontando pra `/dev/dri/renderD128`.

## Duas bibliotecas por categoria (pools `dados` e `dados2`)

Como `dados` e `dados2` são pools de armazenamento independentes (não
réplica), cada categoria de mídia aparece como duas pastas dentro do
container (`/media/movies-1` e `/media/movies-2`, etc — ver
`terraform/environments/production/locals.tf`). No Jellyfin, ao criar a
biblioteca "Filmes", adicione **as duas pastas** (`movies-1` e `movies-2`)
como root folders da mesma biblioteca — o Jellyfin trata múltiplas pastas
raiz como uma única coleção.

Mounts somente leitura (`:ro`) — o Jellyfin nunca precisa escrever nos
arquivos de mídia originais.

## Rede

Porta 8096 (WebUI/streaming), liberada só para a LAN de casa
(`firewall_lan_cidr`) — ver `ansible/playbooks/host_vars/jellyfin.yml`.
