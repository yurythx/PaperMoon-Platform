# State local — adequado para operador único (homelab). O arquivo
# terraform.tfstate cai no .gitignore da raiz do monorepo; faça backup dele
# periodicamente (contém os IDs reais dos recursos Proxmox).
#
# Se no futuro for necessário locking multi-usuário ou histórico versionado
# do state, migrar para um backend remoto (ex: "http" apontando para um
# servidor compatível, ou "s3" para um endpoint S3-compatible) é uma troca
# direta deste bloco + "terraform init -migrate-state" — não exige mudar
# nenhum módulo.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
