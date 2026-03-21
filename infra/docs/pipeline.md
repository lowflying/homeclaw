# infra — CI/CD Pipeline

> Design decisions for the GitHub Actions pipeline. The YAML lives at `../.github/workflows/`.

---

## Status

**Implemented (infra phase complete)** — Terraform plan/apply workflows written. Shared stack deploy workflow written. Solution deploy workflows deferred until images exist.

---

## Pipeline Stages

1. **Validate** — `terraform fmt -check`, `terraform validate`, YAML lint (on every PR + push to main)
2. **Plan** — `terraform plan` on every PR; output posted as PR comment
3. **Apply** — `terraform apply` on merge to `main`, behind manual approval gate
4. **Deploy** — SSH into VPS, pull latest Docker images, restart Compose stacks

Manual approval gate on apply: **yes** — required until infra is stable.

---

## GitHub Actions Secrets

> These are the actual secret names as configured in the repo. Do not rename without updating the workflow YAML.

| Secret name | What it is | Notes |
|---|---|---|
| `HCLOUD_TOKEN` | Hetzner API token | ✓ Confirmed present |
| `HOS_ACCESS_KEY` | Hetzner Object Storage access key (backend) | ✓ Confirmed present |
| `HOST_SECRET_KEY` | Hetzner Object Storage secret key (backend) | ✓ Present — name is a typo (should be `HOS_SECRET_KEY`); leave as-is |
| `VPS_SSH_KEY` | Private SSH key for deployment (`keys/hetzner_deploy`) | Must add before deploy stage |
| `VPS_HOST` | VPS IPv4 address | Populated after first `terraform apply` |
| `ANTHROPIC_API_KEY` | Anthropic API key (for solution containers) | Must add before deploy stage |

---

## Backend Auth in CI

```yaml
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.HOS_ACCESS_KEY }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.HOST_SECRET_KEY }}
```

---

## Workflow Files

| File | Trigger | Purpose |
|---|---|---|
| `tf-plan.yml` | PR touching `infra/terraform/**` | terraform validate + plan, posts output as PR comment |
| `tf-apply.yml` | `workflow_dispatch` (manual) | terraform apply with `production` environment gate |
| `deploy-infra.yml` | `workflow_dispatch` (manual, post-apply) | SSH deploy of shared stack (postgres + cloudflared) |

## Open Gaps

- `VPS_SSH_KEY` — add before running `deploy-infra` (private key from `infra/keys/hetzner_deploy`)
- `VPS_HOST` — add after `terraform apply` (from `terraform output server_ipv4`)
- `POSTGRES_PASSWORD`, `CLARVIS_DB_PASSWORD`, `PERSONAL_ASSISTANT_DB_PASSWORD`, `PROCUREMENT_DB_PASSWORD` — add before `deploy-infra`
- `ANTHROPIC_API_KEY` — needed for solution deploys (not infra phase)
- Solution deploy workflows — deferred until Docker images exist
- Cloudflare Tunnel provisioning — manual one-time step; see `docs/runbooks/cloudflare-tunnel-setup.md`
