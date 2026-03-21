# AGENT.md — infra

> You are working in the `infra/` sub-project. Read this file, then read `docs/architecture.md` and `docs/security.md` before taking any action.
> Also read `../docs/shared/security.md` — the shared security policy always applies.

---

## What This Is

Terraform-managed Hetzner Cloud infrastructure for the homeclaw project, plus documentation for the GitHub Actions deployment pipeline.

---

## Persona Activation

If you were invoked with a persona prefix, read the corresponding file before proceeding:
- Default (no prefix): this file only — conservative, plan-first
- `[infra/planner]`: also read `AGENT_planner.md`
- `[infra/dev]`: also read `AGENT_dev.md`

---

## Rules

- **No `terraform apply` without explicit user approval.** Always run `terraform plan` first and show the output.
- **State backend is Hetzner Object Storage + local copy.** Never change this without discussion.
- **Single environment (`prod`).** Module boundaries must allow `staging` to be added additively. Never hardcode environment-specific values outside of `environments/prod/`.
- **Hetzner API token is a secret.** Never in code or vars files. Always from environment variable or GitHub Actions secret.
- Firewall rules must match `docs/security.md` exactly. If there is a gap, flag it.

---

## Structure

```
infra/
├── AGENT.md
├── AGENT_planner.md
├── AGENT_dev.md
├── README.md
├── docs/
│   ├── architecture.md     ← infra-specific decisions
│   ├── security.md         ← infra-specific security
│   └── pipeline.md         ← CI/CD design
└── terraform/
    ├── environments/
    │   └── prod/
    └── modules/
        ├── server/
        ├── firewall/
        └── network/
```

## BAU Tasks (pre-approved, no confirmation needed)

- **Owner IP update** — The owner's home IP is dynamic. Before any Terraform work, check if the IP in `firewall.tf` matches the current egress IP (`curl -s ifconfig.me`). If it differs, update the CIDR in `firewall.tf`. This is non-destructive and pre-approved.

---

## Status

> **Phase: Pre-deploy** — Terraform written. All critical gaps resolved. Awaiting `terraform apply` approval. CI/CD pipeline YAML not yet written.
