# ansible/files

Arquivos binários/opacos (não variáveis YAML) que precisam ser copiados
para hosts remotos — diferente de `host_vars/`, que é para variáveis.

- `cloudflare-tunnel-credentials.json` — credencial real do túnel Cloudflare
  (ver `docker/cloudflare-tunnel/README.md`). **Contém segredo** — substitua
  o placeholder pelo valor real e rode `ansible-vault encrypt` antes de
  qualquer deploy real. `ansible.builtin.copy` decripta automaticamente um
  arquivo vault-encriptado ao copiá-lo, então isso funciona de forma
  transparente no playbook.
