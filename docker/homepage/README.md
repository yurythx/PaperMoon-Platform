# homepage (CT 140)

Portal central da infraestrutura — [gethomepage/homepage](https://gethomepage.dev),
config 100% em YAML (sem banco, sem estado além dos arquivos de config).

## HOMEPAGE_ALLOWED_HOSTS é obrigatório

Versões recentes da imagem retornam **500** pra qualquer request cujo
`Host` header não esteja nesta lista (proteção contra DNS rebinding).
Inclui o IP:porta da LAN **e** o domínio público — sem os dois, um dos
dois caminhos de acesso quebra.

## Links via domínio público, onde existe rota no Cloudflare Tunnel

`services.yaml` aponta pro domínio público (`https://<serviço>.papermoon.cloud`)
pra cada serviço que já tem rota configurada no painel Zero Trust — assim
o mesmo link funciona de dentro e de fora de casa. Trocado do IP:porta
da LAN original a pedido do usuário, depois que as rotas do Cloudflare
Tunnel foram criadas.

**Duas exceções deliberadas, continuam por IP:porta da LAN:**
- **Grafana** — não tem rota pública configurada ainda (não estava na
  lista de rotas criadas). Atualizar pro domínio assim que existir.
- **CrowdSec** — nunca deve ter rota pública, de propósito (é o
  motor de decisões que protege a frota inteira; expô-lo publicamente
  só aumentaria a superfície de ataque contra ele mesmo). Ver
  `docker/crowdsec/README.md`.

## Config

Três arquivos, montados via `docker_app_extra_files` (mesmo padrão do
`prometheus.yml`/provisioning do Grafana):

- `settings.yaml` — tema, layout das seções.
- `services.yaml` — os links em si, agrupados por categoria.
- `widgets.yaml` — busca + relógio no topo.

Editar aqui e rodar `deploy-homepage.yml` de novo — sem painel de admin,
sem estado pra perder.
