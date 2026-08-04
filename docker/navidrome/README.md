# navidrome (CT 113)

## Por que `ND_MUSICFOLDER=/music` com duas subpastas, em vez de duas variáveis

O Navidrome só aceita **uma** pasta raiz de música (`ND_MUSICFOLDER`), ao
contrário do Jellyfin/Komga (que suportam múltiplas raízes por biblioteca).
Como os dois pools NFS (`dados`/`dados2`) precisam aparecer os dois, a
solução é montar cada um como uma *subpasta* de um diretório comum dentro
do container (`/music/pool1`, `/music/pool2`) e apontar `ND_MUSICFOLDER`
para o pai (`/music`) — o Navidrome escaneia recursivamente e enxerga as
duas como uma biblioteca só. Mount somente leitura.

## Rede

Porta 4533, liberada só para a LAN de casa
(`ansible/playbooks/host_vars/navidrome.yml`).
