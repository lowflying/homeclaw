# AGENT.md — Cheredie Claw Project

> **READ THIS FIRST.** Every Claude invocation working in this repo must read this file before doing anything else. After reading this, also read `README.md` and `planning_docs/architecture.md`. If there is any drift, inconsistency, or uncertainty between these docs and the code, **call it out immediately** before proceeding.

---

## What This Project Is

This is a monorepo for deploying and running AI-powered solutions on a Hetzner VPS using OpenClaw (https://github.com/openclaw/openclaw) as the agent framework. It is a large project composed of several smaller sub-projects:

| Sub-project | Description |
|---|---|
| `infra/` | Terraform-managed Hetzner infrastructure (servers, networking, DNS, firewall) |
| `pipelines/` | CI/CD pipelines for deploying to Hetzner |
| `solutions/personal-assistant/` | A personal AI assistant with its own email address |
| `solutions/clarvis-ai/` | A Clarvis-AI instance with Telegram bot, 3D printer integration, and library (email) integration |

---

## Rules for Claude

### Planning First
- **Do not action anything without a plan.** Before implementing, write a plan and confirm with the user.
- Exception: if we are in `/bugfix` mode, targeted fixes are fine without a full planning session.
- If `planning_docs/architecture.md` or `planning_docs/security.md` have gaps relevant to your task, **stop and flag them**. Start a Q&A session to resolve the gaps before implementing.

### Architecture Docs are Law
- `planning_docs/architecture.md` is the architectural authority. Follow it. If the code drifts from it, flag it.
- `planning_docs/security.md` is the security authority. Security decisions must be consistent with it.
- If there are gaps in these docs, raise them — do not fill gaps silently with assumptions.

### Git & GitHub
- All changes must be tracked in git and pushed to GitHub.
- GitHub username: `lowflying`
- Commit messages should be written as if the user wrote them. Match their language style: casual, direct, occasionally typo-prone, no corporate-speak. Reference the talon commit history for style if unsure.
- See `README.md` for the GitHub repo URL once configured.

### Language & Stack
- Infrastructure: Terraform (Hetzner provider)
- Config language: YAML (shared across solutions where config is needed)
- Container orchestration: Docker Compose (unless architecture doc specifies otherwise)
- Secrets: never committed to git. Use `.env` files locally, refer to `planning_docs/security.md` for the secrets management strategy.

### Calling Things Out
- The user acknowledges they don't know everything. If a suggestion is illogical or technically impossible, say so clearly and explain why.
- Don't be polite to the point of being useless. If something won't work, say so.

---

## Existing Patterns (from `talon/`)

The user already has working implementations in `/home/lowflying/talon/` that this project inherits patterns from:

- **homelabber** — Telegram-driven homelab automation: n8n workflow → Claude Code bridge → Claude CLI executor. This is the proven architecture for Telegram → AI → action pipelines.
- **exec-assistant** — Telegram-based ADHD assistant with Postgres memory, 7-day rolling context, Cloudflare Tunnel for HTTPS.

Key reusable patterns:
- n8n for workflow orchestration
- Cloudflare Tunnel for HTTPS (no port forwarding, no cert management headaches)
- PostgreSQL for persistence
- Telegram bot interface
- Claude API (Sonnet for planning, Haiku for reflection/lightweight tasks)

## Key Knowns

| Item | Value |
|---|---|
| GitHub username | `lowflying` |
| Domain | `obfuscatedbadger.lol` (Cloudflare) |
| Hetzner region | EU (Nuremberg preferred) |
| Email strategy | Cloudflare Email Routing (receive) + Resend.com (send) |
| Library integration | Email only, no API |

## Key Unknowns (TBD — fill these in as resolved)

| Item | Status | Notes |
|---|---|---|
| Hetzner server size | **TBD** | CX31 (2vCPU/8GB) recommended — confirm |
| 3D printer model & connectivity | **TBD** | New Creality — user to check if OctoPrint/Klipper/Creality Cloud |
| Telegram bot token | **TBD** | Will need to be created via @BotFather |
| OpenClaw config format | **TBD** | Review repo before implementing |
| Clarvis-AI config format | **TBD** | Review repo before implementing |
| Staging environment | **TBD** | Cost vs risk tradeoff — decision needed |
| Terraform state backend | **TBD** | Local vs Hetzner Object Storage vs Terraform Cloud |
| LLM backend | **TBD** | For both solutions — likely Anthropic API (matches existing pattern) |

---

## Current Phase

> **Phase: Project Setup** — Structure created, planning docs being drafted. No infrastructure has been provisioned yet.
