resource "hcloud_firewall" "homeclaw" {
  name = "homeclaw"

  # Inbound: SSH on 2222 from allowed IPs only
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "2222"
    source_ips = concat(["109.78.131.133/32"], var.extra_allowed_ips)
  }

  # Inbound: ICMP (ping) from anywhere — IPv4 and IPv6
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Outbound: TCP — allow all (required by Hetzner for egress)
  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "any"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  # Outbound: UDP — allow all (DNS, NTP, etc.)
  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "any"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  # Outbound: ICMP — allow all
  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "homeclaw" {
  firewall_id = hcloud_firewall.homeclaw.id
  server_ids  = [hcloud_server.homeclaw.id]
}
