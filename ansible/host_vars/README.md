# host_vars

Um arquivo por app, criado conforme cada stack é definida na Fase 3b (ver
`nextcloud-mariadb.yml` e `nextcloud-redis.yml` como exemplo). Contém as
variáveis de ambiente específicas daquele app e o `firewall_allowed_ports`
correspondente às portas que o `docker-compose.yml` dele expõe.

**Arquivos com segredo real (senhas, tokens) devem ser criptografados com
`ansible-vault encrypt host_vars/<app>.yml` antes de ir para produção.** Os
arquivos atuais neste diretório têm apenas placeholders (`CHANGE_ME_...`) —
substitua pelos valores reais e criptografe antes do primeiro deploy.
