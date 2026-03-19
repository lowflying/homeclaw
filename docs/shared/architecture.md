# Shared Architecture

> Cross-cutting architectural decisions that apply across all sub-projects.
> Each sub-project has its own `docs/architecture.md` for component-specific decisions.
> Read this before making any decision that touches shared infrastructure, networking, or data.

---

## Established Facts

| Item | Value |
|---|---|
| Domain | `obfuscatedbadger.lol` (Cloudflare DNS) |
| GitHub | `lowflying/homeclaw` |
| Hetzner region | EU / nbg1 (Nuremberg) |
| Server | CX31: 2 vCPU, 8 GB RAM, 80 GB SSD — **awaiting confirmation** |
| HTTPS | Cloudflare Tunnel (`cloudflared`) — no open ports except SSH |
| Email receive | Cloudflare Email Routing → webhook on VPS |
| Email send | Resend.com API (free tier: 3k/month) |
| LLM | Anthropic API — Claude Sonnet for reasoning, Claude Haiku for lightweight tasks |
| Containers | Docker Compose per solution |
| IaC | Terraform (Hetzner provider) |
| Config | YAML |
| CI/CD | GitHub Actions |
| Persistent storage | PostgreSQL (shared instance, separate databases per solution) |

---

## Infrastructure Overview

```
Internet
    │
    ▼
[Cloudflare]
    ├── DNS: obfuscatedbadger.lol
    ├── Email Routing: assistant@obfuscatedbadger.lol → VPS webhook
    └── Tunnel (cloudflared) ─────────────────────────────────┐
                                                               ▼
[Hetzner VPS: CX31, nbg1] ────────── Terraform-managed ─────────────┐
    │                                                                 │
    ├── cloudflared (tunnel daemon)                                   │
    ├── PostgreSQL (shared, Docker Compose)                           │
    │     ├── db: personal_assistant                                  │
    │     └── db: clarvis_ai                                          │
    ├── solutions/personal-assistant (Docker Compose)                 │
    │     └── OpenClaw agent + Resend + Cloudflare email webhook      │
    └── solutions/clarvis-ai (Docker Compose)                         │
          ├── Clarvis-AI agent                                        │
          ├── Telegram bot webhook                                     │
          ├── 3D printer integration (TBD)                            │
          └── Library email integration                               │
                                                                      │
[GitHub Actions] ──── terraform apply + deploy ──────────────────────┘
```

---

## Key Architectural Decisions

### ADR-001: Cloudflare Tunnel over reverse proxy
**Decision:** Use `cloudflared` for all public HTTPS traffic instead of nginx/Caddy.
**Reason:** Already proven in `talon/exec-assistant`. No open ports on VPS (reduced attack surface). Automatic TLS. Cloudflare DDoS protection included. Simpler to operate.
**Consequence:** All services must bind to localhost; cloudflared proxies to them. No direct internet access to services.

### ADR-002: Shared PostgreSQL, isolated databases
**Decision:** One PostgreSQL instance, separate databases per solution.
**Reason:** Simpler operations (one backup, one upgrade path). Sufficient isolation for current threat model. Cheaper than separate instances.
**Consequence:** If compliance requirements escalate (e.g. medical data), solutions may need separate instances. Architecture must support this migration without major rework — use separate DB users with no cross-database permissions.

### ADR-003: Docker Compose per solution, not Kubernetes
**Decision:** Each solution is a Docker Compose stack. No Kubernetes.
**Reason:** CX31 is too small for Kubernetes overhead. Complexity is not justified for ~12 family users. Compose is sufficient and well-understood.
**Consequence:** Scaling beyond one VPS requires rethinking. Acceptable trade-off for now.

### ADR-004: Single environment to start, expandable
**Decision:** One environment (`prod`). No staging.
**Reason:** Cost and complexity. Family-use, not customer-facing.
**How to expand:** Terraform is structured with `environments/prod/` from day one. Adding `environments/staging/` is additive, not a rework. Module boundaries must be maintained so environments don't share state.

### ADR-005: Resend.com + Cloudflare Email Routing for email
**Decision:** Receive via Cloudflare Email Routing, send via Resend.com API.
**Reason:** No mail server to operate. No spam reputation to manage. Cloudflare already manages the domain. Resend has a clean API and good deliverability. Free tiers are sufficient.
**Consequence:** Dependency on two external services for email. Acceptable — both are stable providers. If Resend pricing changes, Mailgun or Postmark are drop-in alternatives.

### ADR-006: One Telegram bot, persona routing by message prefix
**Decision:** Single Telegram bot routes to sub-projects and personas via `[project/persona]` message prefix.
**Reason:** Maintaining one bot per persona/project would be unmanageable. Routing is cheap and flexible.
**See:** `docs/shared/agent-system.md` for full routing design.

---

## Shared Services

### PostgreSQL
- Runs as Docker Compose service on the VPS
- Each solution gets its own database and DB user
- Backups: TBD (Hetzner Volume snapshot or pg_dump to Object Storage)
- Version: PostgreSQL 16

### Cloudflare Tunnel
- One `cloudflared` instance routes to all internal services by hostname
- Config in `infra/cloudflare-tunnel-config.yml`
- Managed outside Terraform (Cloudflare Tunnel has its own credentials)

### Resend.com
- Shared sending domain: `mail.obfuscatedbadger.lol` (or subdomain — TBD)
- One API key for all solutions (one per solution if audit granularity needed later)

---

## Subdomains (Planned)

| Subdomain | Routes to | Purpose |
|---|---|---|
| `assistant.obfuscatedbadger.lol` | personal-assistant service | Email webhook endpoint |
| `bot.obfuscatedbadger.lol` | clarvis-ai service | Telegram webhook endpoint |
| `mail.obfuscatedbadger.lol` | (Resend/Cloudflare Email) | Sending domain (MX/SPF/DKIM) |

---

## Gaps

| # | Gap | Impact |
|---|---|---|
| A1 | Hetzner CX31 confirmed? | Terraform config |
| A2 | PostgreSQL backup strategy | Data durability |
| A3 | 3D printer model/connectivity | Clarvis-AI architecture |
| A4 | Terraform state backend confirmed as Hetzner Object Storage + local copy | Must resolve before first `terraform apply` |
| A5 | Sending subdomain for Resend | Email config |
