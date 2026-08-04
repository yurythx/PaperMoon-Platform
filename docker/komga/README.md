# komga (CT 111)

Servidor de manga/quadrinhos/ebooks. `SERVER_PORT=25600` (em vez do default
8080 do Spring Boot) só para deixar host e container na mesma porta e
evitar confusão de mapeamento.

## Bibliotecas duplas (pools `dados`/`dados2`)

Mesma lógica do Jellyfin: cada categoria (`manga`, `comics`, `ebooks`)
aparece como duas pastas (`-1`/`-2`, um pool NFS cada). No Komga, crie uma
biblioteca por categoria e adicione as duas pastas correspondentes como
raízes de varredura.

Mounts somente leitura — o Komga só lê os arquivos, nunca escreve neles
(metadados/thumbnails ficam em `komga_config`, volume separado).

## Rede

Porta 25600, liberada só para a LAN de casa
(`ansible/playbooks/host_vars/komga.yml`).
