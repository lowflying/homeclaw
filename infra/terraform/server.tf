resource "hcloud_server" "homeclaw" {
  name        = "homeclaw-prod"
  server_type = var.server_type
  image       = "ubuntu-24.04"
  location    = var.server_location
  ssh_keys    = [hcloud_ssh_key.homeclaw_deploy.id]

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    volume_id = hcloud_volume.postgres_data.id
  })

  labels = {
    project = "homeclaw"
    env     = "prod"
  }

  lifecycle {
    ignore_changes = [
      # Prevent replacement if user_data drifts after initial boot
      user_data,
    ]
  }
}
