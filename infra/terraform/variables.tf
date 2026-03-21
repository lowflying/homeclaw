variable "hcloud_token" {
  description = "Hetzner Cloud API token. Set via TF_VAR_hcloud_token or GitHub Actions secret HCLOUD_TOKEN."
  type        = string
  sensitive   = true
}

variable "server_location" {
  description = "Hetzner datacenter location identifier."
  type        = string
  default     = "hel1"
}

variable "server_type" {
  description = "Hetzner server type (instance size)."
  type        = string
  default     = "cx33"
}

variable "extra_allowed_ips" {
  description = "Additional IPs for SSH allowlist — add home machine IP here (e.g. [\"1.2.3.4/32\"])."
  type        = list(string)
  default     = []
}
