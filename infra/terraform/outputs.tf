output "server_ipv4" {
  description = "Public IPv4 address of the homeclaw production server."
  value       = hcloud_server.homeclaw.ipv4_address
}

output "server_id" {
  description = "Hetzner resource ID of the server."
  value       = hcloud_server.homeclaw.id
}

output "volume_id" {
  description = "Hetzner resource ID of the postgres data volume."
  value       = hcloud_volume.postgres_data.id
}

output "postgres_volume_device" {
  description = "Block device path for the postgres data volume (stable by-id symlink)."
  value       = "/dev/disk/by-id/scsi-0HC_Volume_${hcloud_volume.postgres_data.id}"
}
