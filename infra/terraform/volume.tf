resource "hcloud_volume" "postgres_data" {
  name      = "postgres-data"
  size      = 10
  location  = var.server_location
  format    = "ext4"

  labels = {
    name = "postgres-data"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "hcloud_volume_attachment" "postgres_data" {
  volume_id = hcloud_volume.postgres_data.id
  server_id = hcloud_server.homeclaw.id
  automount = false
}
