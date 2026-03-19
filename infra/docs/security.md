# infra — Security

> Infra-specific security decisions. The shared policy at `../docs/shared/security.md` takes precedence.

---

## Firewall Rules

| Port | Protocol | Source | Status |
|---|---|---|---|
| 22 (TBD — may use non-standard) | TCP | Owner IP(s) only | Planned |
| All others inbound | — | DENY | Planned |
| All outbound | — | Allow | Planned |

**Open gap:** Owner IP(s) and SSH port not yet confirmed. See `docs/architecture.md` gaps I3.

## SSH Hardening

To be applied via cloud-init or Ansible on first boot:
- `PasswordAuthentication no`
- `PermitRootLogin no`
- `AllowUsers <deploy-user>`
- Port: TBD (standard 22 vs non-standard — see shared security gap S1)

## Terraform Secrets

- `HCLOUD_TOKEN` — injected as environment variable only. Never in `.tfvars` files committed to git.
- Backend credentials — injected as `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` env vars for Hetzner Object Storage S3 compat. Never in `backend.tf`.
- Both secrets stored in GitHub Actions secrets for CI and in local `.env` for manual operations.
