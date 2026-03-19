# infra — Architecture

> Infra-specific architecture decisions. Read `../docs/shared/architecture.md` first for cross-cutting decisions.

---

## Status

**Draft** — Planning session not yet started. This file will be populated during the infra planning session.

---

## Planned Resources

See `../docs/shared/architecture.md` for the full picture. Infra-specific detail to be added here after the planning session.

Draft resource list:

| Resource | Terraform resource | Notes |
|---|---|---|
| VPS | `hcloud_server` | CX31, nbg1 — awaiting confirmation |
| Firewall | `hcloud_firewall` | SSH (owner IP only). All else via Cloudflare Tunnel. |
| SSH key | `hcloud_ssh_key` | Public key to be added |
| Private network | `hcloud_network` + `hcloud_subnet` | For future multi-resource use |
| Object Storage bucket | Hetzner S3-compatible | Terraform state backend |
| Volume | `hcloud_volume` | PostgreSQL data persistence |

---

## State Backend

- **Primary:** Hetzner Object Storage (S3-compatible) — bucket to be created before first `terraform init`
- **Local copy:** `terraform/environments/prod/.terraform.tfstate.backup` — kept for operator sanity
- **Never commit state files to git.**

---

## Module Structure

```
terraform/
├── environments/
│   └── prod/
│       ├── main.tf          ← calls modules, environment-specific vars
│       ├── variables.tf
│       ├── outputs.tf
│       └── backend.tf       ← S3 backend config (no secrets here, creds via env vars)
└── modules/
    ├── server/              ← hcloud_server + ssh_key
    ├── firewall/            ← hcloud_firewall + rules
    └── network/             ← hcloud_network + subnet
```

---

## Gaps

| # | Gap | Needed for |
|---|---|---|
| I1 | CX31 server size confirmed? | `hcloud_server` resource |
| I2 | Owner SSH public key | `hcloud_ssh_key` resource |
| I3 | Owner IP(s) for SSH allowlist | `hcloud_firewall` SSH rule |
| I4 | Object Storage bucket name | `backend.tf` |
| I5 | Hetzner project name | Provider config |
