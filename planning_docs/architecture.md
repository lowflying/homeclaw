# Architecture

> This document is the architectural authority for the cheredie-claw project. All implementation must follow it. If the code drifts from this document, that is a bug. If this document has gaps, raise them — do not fill them with assumptions.

---

## Status

**Draft** — Initial skeleton. Key facts resolved, some decisions still TBD. See gaps section at the bottom.

---

## Established Facts

| Item | Value |
|---|---|
| Domain | `obfuscatedbadger.lol` (Cloudflare DNS) |
| GitHub user | `lowflying` |
| Hetzner region | EU (Nuremberg — `nbg1`) |
| Server size | **CX31 recommended** (2 vCPU, 8 GB RAM, 80 GB SSD) — enough for both solutions + n8n + PostgreSQL for ~12 family users, resizable if needed |
| HTTPS strategy | Cloudflare Tunnel (proven in `talon/exec-assistant`) — no open ports, automatic TLS |
| Email (receive) | Cloudflare Email Routing → webhook on VPS |
| Email (send) | Resend.com API (free tier: 3k/month) |
| LLM API | Anthropic API (matches existing talon pattern) |
| Workflow orchestration | n8n (matches existing pattern) |
| Persistence | PostgreSQL (matches existing pattern) |
| Telegram interface | Bot via @BotFather (matches existing pattern) |

---

## High-Level Overview

```
Internet
    │
    ▼
[Cloudflare]
    ├── DNS (obfuscatedbadger.lol)
    ├── Email Routing (→ VPS webhook for personal assistant)
    └── Tunnel (cloudflared) ────────────────────────────────┐
                                                             ▼
[Hetzner VPS: CX31, EU/nbg1] ──── Terraform-managed ───────────────┐
    │                                                               │
    ├── [cloudflared] — exposes internal HTTP services via tunnel   │
    │                                                               │
    ├── [n8n] ─────────────────────────────────────────────────────┤
    │       ├── Personal Assistant workflow                         │
    │       │     └── receives email webhook → OpenClaw → reply     │
    │       └── Clarvis-AI workflow                                 │
    │             ├── Telegram trigger → Clarvis-AI → reply         │
    │             ├── 3D Printer integration (TBD)                  │
    │             └── Library email integration                     │
    │                                                               │
    ├── [OpenClaw: Personal Assistant] (Docker Compose)             │
    ├── [Clarvis-AI] (Docker Compose)                               │
    └── [PostgreSQL] (Docker Compose, shared)                       │
                                                                    │
[GitHub Actions] ─────────── terraform + deploy ────────────────────┘
```

**Note on Cloudflare Tunnel:** This replaces the need for a reverse proxy with TLS management. No ports 80/443 need to be open. Cloudflare handles TLS. This is proven in `talon/exec-assistant`.

---

## Infrastructure Layer (`infra/`)

### Provider
- **Hetzner Cloud** via `hcloud` Terraform provider

### Resources (planned)
| Resource | Purpose | Notes |
|---|---|---|
| `hcloud_server` | Main VPS | Size TBD |
| `hcloud_firewall` | Ingress/egress rules | Ports: 22 (SSH), 80, 443, Telegram webhook port |
| `hcloud_network` + `hcloud_subnet` | Private networking | Between resources if we add more later |
| `hcloud_ssh_key` | SSH access | Public key to be added |
| `hcloud_volume` | Persistent storage | For data that must survive server rebuilds |
| DNS records | TBD | If using Hetzner DNS or external provider |

### Environments
- `infra/hetzner/environments/prod/` — production
- Staging: TBD — may be skipped for cost reasons, decision needed

### Modules
- `infra/hetzner/modules/server/` — base server config
- `infra/hetzner/modules/firewall/` — firewall rules
- More TBD as we flesh out

### State
- Terraform state location: **TBD** — options: local (simplest, riskier), Hetzner Object Storage, Terraform Cloud free tier
- **GAP:** Decision needed before any `terraform apply`

---

## Application Layer

### Container Strategy
- Each solution runs as Docker Compose stack on the VPS
- Managed via SSH + deploy scripts or GitHub Actions runner

### Reverse Proxy
- **TBD:** Caddy (simpler, automatic TLS) vs nginx (more familiar)
- Handles TLS termination for all solutions
- Routes by subdomain or path

### Solution: Personal Assistant

| Item | Decision | Notes |
|---|---|---|
| Framework | OpenClaw | https://github.com/openclaw/openclaw — **review repo before implementing** |
| Interface | Email (inbound + outbound) | Agent receives emails, responds |
| Email address | `assistant@obfuscatedbadger.lol` | Via Cloudflare Email Routing |
| Email receive | Cloudflare Email Routing | Forwards to webhook endpoint on VPS |
| Email send | Resend.com API | Free tier 3k emails/month, simple API |
| LLM backend | Anthropic API | Claude Sonnet (matches existing pattern) |
| Persistence | PostgreSQL | Conversation history, task memory |
| Orchestration | n8n | Email webhook → OpenClaw → Resend reply |

### Solution: Clarvis-AI

| Item | Decision | Notes |
|---|---|---|
| Framework | Clarvis-AI | https://github.com/makermate/clarvis-ai — **review repo before implementing** |
| Interface 1 | Telegram Bot | Bot created via @BotFather |
| Interface 2 | 3D Printer | **TBD** — Creality model unknown, check OctoPrint/Klipper/Creality Cloud |
| Interface 3 | Library (email) | Email in/out only, no API. Use Resend (send) + Cloudflare Email Routing (receive) |
| HTTPS | Cloudflare Tunnel | Telegram webhook delivered via tunnel |
| LLM backend | Anthropic API | Claude Sonnet |
| Orchestration | n8n | Same pattern as homelabber in talon |

#### 3D Printer Integration Options (TBD — awaiting printer details)
- **OctoPrint API** — if printer runs OctoPrint, REST API available. Most Creality printers support this via a Raspberry Pi running OctoPi.
- **Klipper/Moonraker** — REST API via Moonraker; newer Creality (e.g. Ender 3 S1, K1) can run Klipper
- **Creality Cloud** — newer Creality printers have Wi-Fi + Creality Cloud app; API access is limited/unofficial
- **Email trigger** — fallback if no direct API: Clarvis sends a "job queued" email, someone manually starts it. Ugly but functional.
- **Direct USB** — not viable for remote/AI use, ruled out

**Action needed:** User to check what connectivity the printer has (is there a network interface? OctoPrint running on a Pi? Creality Cloud app connected?).

#### Library Integration
- Email-only. Clarvis sends/receives emails to library address.
- No special API integration needed. Same email stack as personal assistant (Resend + Cloudflare Email Routing).

---

## CI/CD Pipeline (`pipelines/`)

### Strategy (TBD)
- GitHub Actions preferred (free for public repos, available for private)
- On push to `main`: run `terraform plan` + apply, then deploy updated Docker Compose stacks
- Secrets stored in GitHub Actions secrets, not in repo

### Pipeline Stages (draft)
1. Lint / validate (terraform validate, yaml lint)
2. Terraform plan (review on PR)
3. Terraform apply (on merge to main)
4. Deploy solutions (SSH into VPS, pull latest images, restart compose stacks)

---

## Networking & DNS

- **Domain:** TBD — required for TLS and email
- **DNS provider:** TBD — Hetzner DNS or external (Cloudflare etc.)
- **Subdomains needed (draft):**
  - `assistant.{domain}` — personal assistant webhook/interface (if needed)
  - `clarvis.{domain}` or `bot.{domain}` — Telegram webhook endpoint
  - `mail.{domain}` — if self-hosting email (MX record etc.)

---

## Gaps — Q&A Needed

These must be resolved before implementation of the relevant component can begin.

| # | Gap | Impact | Status |
|---|---|---|---|
| G1 | GitHub username | Git remote, CI/CD | **Resolved: `lowflying`** |
| G2 | Domain name(s) | TLS, email, Telegram webhook | **Resolved: `obfuscatedbadger.lol` (Cloudflare)** |
| G3 | Hetzner region | Terraform config | **Resolved: EU / nbg1** |
| G3b | Hetzner server size | Terraform config | Recommendation: CX31 — **awaiting confirmation** |
| G4 | Email provider | Personal assistant architecture | **Resolved: Cloudflare Email Routing + Resend** |
| G5 | 3D printer model + connectivity | Clarvis integration approach | **Open — user to check printer** |
| G6 | Terraform state backend | Must be decided before first `terraform apply` | **Open** |
| G7 | Staging environment needed? | Infra cost + pipeline design | **Open** |
| G8 | OpenClaw config format | Personal assistant implementation | **Open — review repo** |
| G9 | Clarvis-AI config format | Clarvis implementation | **Open — review repo** |
| G10 | Reverse proxy | Removed — using Cloudflare Tunnel instead | **Resolved: N/A** |
