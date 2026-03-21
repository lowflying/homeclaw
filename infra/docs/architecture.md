# infra — Architecture

> Infra-specific architecture decisions. Read `../docs/shared/architecture.md` first for cross-cutting decisions.

---

## Status

**Active** — Planning session complete (2026-03-19). Terraform written and validated. Pending `terraform apply` approval.

---

## Confirmed Decisions

| Decision | Value | Confirmed |
|---|---|---|
| Server type | CX31 (2 vCPU / 8 GB RAM) | ✓ 2026-03-21 |
| Server location | nbg1 (Nuremberg) | ✓ |
| OS image | ubuntu-24.04 | ✓ |
| SSH port | 2222 | ✓ 2026-03-21 |
| Owner SSH key | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIALr/dzv2L+57dyNgv+nVxKuQa3yyMuA7AlQB3NRBa0w` | ✓ 2026-03-21 |
| Object Storage bucket | `homeclaw-infra-tfstate` | ✓ 2026-03-21 (bucket created, creds in GitHub Actions secrets) |
| Postgres volume | 10 GB, `prevent_destroy = true` | ✓ |

---

## Resources

| Resource | Terraform resource | Status |
|---|---|---|
| VPS | `hcloud_server.homeclaw` | Written — awaiting apply |
| Firewall | `hcloud_firewall.homeclaw` | Written — awaiting apply |
| SSH key | `hcloud_ssh_key.homeclaw_deploy` | Written — awaiting apply |
| Volume (PostgreSQL) | `hcloud_volume.postgres_data` | Written — awaiting apply |
| Object Storage bucket | External (pre-existing) | Created |

---

## Owner IP (SSH Allowlist)

**The owner's home IP is dynamic.** Updating `firewall.tf` with the current IP is a BAU task — safe to do without approval as it is non-destructive (only additive to access, never removes access to a running server).

Current allowlisted IP: `109.78.131.133/32` — updated 2026-03-21.

Additional IPs can be passed via `var.extra_allowed_ips` without touching `firewall.tf`.

---

## State Backend

- **Primary:** Hetzner Object Storage (S3-compatible), `nbg1` region
  - Bucket: `homeclaw-infra-tfstate`, key: `base/terraform.tfstate`
  - Credentials in GitHub Actions secrets: `HOS_ACCESS_KEY` / `HOST_SECRET_KEY`
  - **Note:** `HOST_SECRET_KEY` is a typo — should be `HOS_SECRET_KEY`. Do not rename until CI is wired, to avoid secret loss.
- **Never commit state files to git.**

---

## Module Structure

Current Terraform lives flat in `terraform/` (no modules yet). Module refactor deferred — premature until second environment is needed.

```
terraform/
├── backend.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── server.tf
├── firewall.tf
├── ssh_key.tf
├── volume.tf
├── versions.tf
└── templates/
    └── cloud-init.yaml.tpl
```

---

## Open Gaps

| # | Gap | Status |
|---|---|---|
| A1 | CX31 confirmed | ✓ Resolved |
| S1 | SSH port 2222 | ✓ Resolved |
| S2 | Owner IP for SSH allowlist | ✓ Resolved (dynamic, update as BAU) |
| I2 | SSH public key confirmed | ✓ Resolved |
| I4 | Object Storage bucket + creds | ✓ Resolved |
| I5 | Hetzner project name / HCLOUD_TOKEN scope | Pending — confirm token is project-scoped |
| CI1 | GitHub Actions workflow YAML | Not written |
| CI2 | Cloudflare Tunnel token on VPS | Manual step — must be done after first apply |
| CI3 | `HOST_SECRET_KEY` typo in GitHub Actions secret | Known — leave until CI is wired |
