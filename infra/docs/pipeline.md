# infra — CI/CD Pipeline

> Design decisions for the GitHub Actions pipeline. The YAML lives at `../.github/workflows/`.

---

## Status

**Draft** — Not yet implemented. To be designed after infra Terraform is written.

---

## Planned Pipeline Stages

1. **Validate** — `terraform fmt -check`, `terraform validate`, YAML lint
2. **Plan** — `terraform plan` on every PR, output posted as PR comment
3. **Apply** — `terraform apply` on merge to `main` (manual approval gate recommended initially)
4. **Deploy** — SSH into VPS, pull latest Docker images, restart Compose stacks

## Secrets Required in GitHub Actions

| Secret name | What it is |
|---|---|
| `HCLOUD_TOKEN` | Hetzner API token |
| `TF_BACKEND_ACCESS_KEY` | Hetzner Object Storage access key |
| `TF_BACKEND_SECRET_KEY` | Hetzner Object Storage secret key |
| `VPS_SSH_KEY` | Private SSH key for deployment |
| `VPS_HOST` | VPS IP address |
| `ANTHROPIC_API_KEY` | Anthropic API key (for solution deploys) |

## Gaps

- Manual approval gate on apply: yes or no? Recommended yes until infra is stable.
- Docker image registry: GitHub Container Registry (ghcr.io) or Docker Hub?
- Deployment strategy: SSH + docker compose pull? Or push-based with an agent on the VPS?
