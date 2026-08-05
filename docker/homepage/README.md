# homepage (CT 140)

Portal central da infraestrutura — [gethomepage/homepage](https://gethomepage.dev),
config 100% em YAML (sem banco, sem estado além dos arquivos de config).

## HOMEPAGE_ALLOWED_HOSTS é obrigatório

Versões recentes da imagem retornam **500** pra qualquer request cujo
`Host` header não esteja nesta lista (proteção contra DNS rebinding).
Inclui o IP:porta da LAN **e** o domínio público — sem os dois, um dos
dois caminhos de acesso quebra.

## Links via IP:porta da LAN, não via domínio público

`services.yaml` aponta pra cada serviço direto pelo IP interno — este
dashboard é usado de dentro de casa; rotear cada clique pelo Cloudflare
Tunnel só adicionaria uma volta desnecessária pra quem já está na LAN.

## Config

Três arquivos, montados via `docker_app_extra_files` (mesmo padrão do
`prometheus.yml`/provisioning do Grafana):

- `settings.yaml` — tema, layout das seções.
- `services.yaml` — os links em si, agrupados por categoria.
- `widgets.yaml` — busca + relógio no topo.

Editar aqui e rodar `deploy-homepage.yml` de novo — sem painel de admin,
sem estado pra perder.
