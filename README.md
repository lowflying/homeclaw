# cheredie-claw

A monorepo for deploying AI-powered solutions to Hetzner VPS using [OpenClaw](https://github.com/openclaw/openclaw) as the agent framework.

> **New to this repo?** Start with `AGENT.md`, then come back here.

---

## Solutions

### 1. Personal Assistant (`solutions/personal-assistant/`)
An AI personal assistant with its own email address, handling day-to-day organisation tasks.

- **Framework:** OpenClaw
- **Email:** TBD (provider and address not yet configured)
- **Status:** Planning

### 2. Clarvis-AI (`solutions/clarvis-ai/`)
A [Clarvis-AI](https://github.com/makermate/clarvis-ai) instance with:
- Telegram bot interface
- 3D printer integration (model/connectivity TBD)
- Library integration (email-only, no API)

- **Framework:** Clarvis-AI on OpenClaw
- **Status:** Planning

---

## Infrastructure

- **Target:** Hetzner VPS
- **IaC:** Terraform (`infra/`)
- **Region:** TBD
- **Config format:** YAML

See `planning_docs/architecture.md` for full architecture decisions.

---

## Repository Structure

```
cheredie-claw/
├── AGENT.md                          # Read on every Claude invocation
├── README.md                         # This file
├── planning_docs/
│   ├── architecture.md               # Architecture authority — follow this
│   └── security.md                   # Security authority — follow this
├── infra/
│   └── hetzner/
│       ├── environments/             # Per-environment terraform (prod, staging)
│       └── modules/                  # Reusable terraform modules
├── solutions/
│   ├── personal-assistant/           # Personal assistant solution
│   └── clarvis-ai/                   # Clarvis-AI solution
├── pipelines/                        # CI/CD pipeline configs
└── docs/                             # Additional documentation
```

---

## Working Rules

- **Plan before acting.** No implementation without a plan, unless in `/bugfix` mode.
- **Architecture docs are law.** `planning_docs/architecture.md` drives all decisions.
- **Secrets never in git.** See `planning_docs/security.md`.
- **Commit as the user.** Match their voice — casual, direct.

---

## GitHub

- **Repo:** TBD (not yet initialised)
- **Owner:** TBD (GitHub username not yet configured)
