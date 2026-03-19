# AGENT.md — homeclaw

> **READ THIS FIRST on every invocation.** This is the project index. After reading this, navigate to the sub-project you're working in and read its own `AGENT.md` and `docs/`. If there is drift between any doc and the code, call it out before proceeding.

---

## What This Is

`homeclaw` is a monorepo for deploying AI-powered solutions to a Hetzner VPS. Each sub-project is self-contained — navigate into it and read its own AGENT.md.

| Directory | What it is |
|---|---|
| `infra/` | Terraform-managed Hetzner infrastructure + GitHub Actions pipeline docs |
| `solutions/personal-assistant/` | OpenClaw email agent — PA with its own email address |
| `solutions/clarvis-ai/` | Clarvis-AI: Telegram bot + 3D printer + library email |

Shared docs (read if your task touches shared concerns):

| File | What it covers |
|---|---|
| `docs/shared/security.md` | Security policy, threat model, non-negotiables |
| `docs/shared/architecture.md` | Shared infrastructure decisions, ADRs |
| `docs/shared/agent-system.md` | Persona design, Telegram routing, sequential chaining |

---

## Global Rules

- **Plan before acting.** No implementation without a written plan, unless in `/bugfix` mode.
- **Docs are the source of truth.** Code is the output of docs. If they drift, flag it.
- **Secrets never in git.** See `docs/shared/security.md`.
- **Single environment for now, expandable.** Terraform must use module boundaries that allow staging to be added without rework. Never hardcode anything that should differ between environments.
- **Challenge bad ideas.** User explicitly wants pushback. Do not agree to be agreeable.
- **Commit as the user.** Casual, direct, no corporate-speak.

## Key Facts

| Item | Value |
|---|---|
| GitHub | `lowflying/homeclaw` |
| Domain | `obfuscatedbadger.lol` (Cloudflare) |
| Hetzner region | EU / nbg1 |
| Email | Cloudflare Email Routing (receive) + Resend.com (send) |
| LLM | Anthropic API (Sonnet for reasoning, Haiku for lightweight) |
| Existing patterns | `/home/lowflying/talon/` — homelabber + exec-assistant |

## Open Items

| Item | Notes |
|---|---|
| Hetzner server size | CX31 recommended — awaiting confirmation |
| 3D printer connectivity | New Creality — user to check when available |
| Telegram bot token | Create via @BotFather when ready |
| OpenClaw config | Review repo before implementing |
| Clarvis-AI config | Review repo before implementing |
| Terraform state | Hetzner Object Storage + local copy — confirmed in principle |

## Current Phase

> **Phase: Project Setup** — Structure and shared docs complete. No infrastructure provisioned yet. Next: infra planning session.
