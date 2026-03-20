resource "hcloud_ssh_key" "homeclaw_deploy" {
  name       = "homeclaw-deploy"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIALr/dzv2L+57dyNgv+nVxKuQa3yyMuA7AlQB3NRBa0w hetzner-homeclaw-deploy"
}
