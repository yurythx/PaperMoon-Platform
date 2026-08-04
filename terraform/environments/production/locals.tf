locals {
  # IDs reais dos storages NFS neste host (pve1) — já existiam antes deste
  # projeto, registrados como "TrueNAS-NFS"/"TrueNAS-NFS2" (não "pve-dados"
  # como um rascunho anterior deste arquivo assumia). Confirmado via
  # 'cat /etc/pve/storage.cfg' no host real. São dois pools independentes
  # (conteúdo diferente, não réplica um do outro) — por isso os apps de
  # mídia recebem bind mounts dos dois, como bibliotecas separadas (ver
  # docs/terraform.md).
  dados_path  = "/mnt/pve/TrueNAS-NFS"
  dados2_path = "/mnt/pve/TrueNAS-NFS2"

  media_categories = ["movies", "series", "anime", "photos"]
  book_categories  = ["manga", "comics", "ebooks"]

  # Bind mounts de mídia (somente leitura) combinando os dois pools NFS
  # para uma lista de categorias sob media/<categoria>.
  media_mount_points = flatten([
    for cat in local.media_categories : [
      { volume = "${local.dados_path}/media/${cat}", path = "/data/${cat}-1", read_only = true },
      { volume = "${local.dados2_path}/media/${cat}", path = "/data/${cat}-2", read_only = true },
    ]
  ])

  music_mount_points = [
    { volume = "${local.dados_path}/media/music", path = "/data/music-1", read_only = true },
    { volume = "${local.dados2_path}/media/music", path = "/data/music-2", read_only = true },
  ]

  book_mount_points = flatten([
    for cat in local.book_categories : [
      { volume = "${local.dados_path}/books/${cat}", path = "/data/${cat}-1", read_only = true },
      { volume = "${local.dados2_path}/books/${cat}", path = "/data/${cat}-2", read_only = true },
    ]
  ])

  # qBittorrent: downloads é área de trabalho transitória (staging antes de
  # organizar na biblioteca definitiva) — usa só o pool "dados" por
  # simplicidade. Ver docs/terraform.md se isso precisar mudar.
  downloads_mount_points = [
    { volume = "${local.dados_path}/downloads/complete", path = "/data/complete", read_only = false },
    { volume = "${local.dados_path}/downloads/incomplete", path = "/data/incomplete", read_only = false },
    { volume = "${local.dados_path}/downloads/watch", path = "/data/watch", read_only = false },
  ]
}
