# Planning Session: OpenClaw + Homeclaw Full Stack Deployment on Hetzner

**Date:** 2026-03-19
**Persona:** infra/planner
**Topic:** End-to-end deployment design — Hetzner VPS, OpenClaw, Clarvis-AI, Home Procurement agent
**Status:** Draft — awaiting security review + gap resolution

---

## 1. Scope

Design the full deployment architecture for:

1. **Infrastructure** — Hetzner VPS provisioned via Terraform, managed via Terragrunt, deployed via GitHub Actions CI/CD
2. **OpenClaw instance** — The core agent framework powering `personal-assistant` and `home-procurement` solutions
3. **Clarvis-AI instance** — Telegram-facing AI assistant (separate framework, same VPS)
4. **Home Procurement agent** — New solution: receives a purchase brief via Telegram, sources vendors, sends inquiry emails, tracks quotes, and delivers a comparison report

Out of scope this session: 3D printer integration (connector unknown), calendar integration (PA3 gap), confidence scoring thresholds (PA3 gap).

---

## 2. Use Cases Driving This Design

### 2A — Clarvis-AI (existing, solution folder already scoped)

Already designed in `solutions/clarvis-ai/`. Deployment requirements:
- Telegram webhook endpoint at `bot.obfuscatedbadger.lol`
- Webhook signature verification on every request
- Email send/receive via Resend.com + Cloudflare Email Routing
- Anthropic API (Sonnet for reasoning tasks, Haiku for lightweight)
- PostgreSQL database: `clarvis_ai`

**What's still needed:** Clarvis-AI framework review (C1), 3D printer connectivity (C2). These are NOT blockers for the deployment infrastructure — the infra can be provisioned before the solution is complete.

### 2B — Home Procurement Agent (new)

**User problem:** Ordering large home items (doors, windows, etc.) requires getting quotes from multiple companies. This is tedious — finding vendors, drafting consistent inquiry emails, tracking responses, comparing quotes.

**Agent capability:**
1. User sends Telegram message: `[home-procurement] I need quotes for 3 solid-core interior doors (32"x80") and 2 casement windows (36"x48") — get me 3 vendors`
2. Agent reasons about the specification, identifies vendor categories, checks a configured vendor list or uses pre-configured contacts
3. Agent drafts standardised inquiry emails with item specs, quantity, desired delivery location, and quote deadline
4. Agent sends emails via Resend.com from `procurement@obfuscatedbadger.lol`
5. Agent writes a procurement record to PostgreSQL (`home_procurement` DB) with job ID, items, vendors contacted, sent timestamp
6. When vendor replies arrive (Cloudflare Email Routing → webhook), agent parses the quote, updates the job record
7. On user request (`[home-procurement] show me quotes for job X`), agent compiles the comparison table and replies via Telegram
8. User confirms preferred vendor; agent sends acceptance email

**Security surface:** Vendor email replies are untrusted input — subject to the same prompt injection controls as personal-assistant.

---

## 3. Infrastructure Design

### 3.1 Server

**Decision:** Hetzner CX31 (2 vCPU, 8GB RAM, 80GB SSD, Nuremberg/nbg1)

**Rationale:**
- Three Docker Compose stacks (clarvis-ai, personal-assistant, home-procurement) plus shared PostgreSQL and cloudflared tunnel
- Memory estimate: ~1.5GB for PostgreSQL + 3 × ~500MB for solution containers + ~200MB for cloudflared + OS overhead ≈ 4.5GB. CX31's 8GB provides headroom.
- CPU: All solutions are I/O-bound (waiting on Anthropic API). 2 vCPU sufficient.
- Disk: 80GB covers OS + Docker images + database growth for 12+ months with current scope.

**Gap A1 — needs explicit confirmation before `terraform apply`.**

If any solution adds vector search or significant data storage, revisit CX41.

### 3.2 Attached Volume

A **separate Hetzner Volume (10GB, expandable)** will back the PostgreSQL data directory. This decouples database data from the OS disk — if the server is rebuilt, the volume is re-attached. Snapshots are taken from the volume, not the root disk.

```
hcloud_volume: "homeclaw-postgres-data"
  size: 10GB
  location: nbg1
  automount: false  # mounted via cloud-init / ansible
  format: ext4
```

### 3.3 Networking

```
Public internet
    │
    ▼
Cloudflare (DNS + CDN + Tunnel)
    │
    ▼ (encrypted tunnel, no open ports)
VPS: cloudflared daemon
    │
    ├── bot.obfuscatedbadger.lol      → clarvis-ai webhook container (port 8001)
    ├── assistant.obfuscatedbadger.lol → personal-assistant webhook (port 8002)
    ├── procurement.obfuscatedbadger.lol → home-procurement webhook (port 8003)
    └── mail.obfuscatedbadger.lol     → Resend sending domain (DNS only, no VPS)

VPS Firewall:
    - TCP 22: owner IP(s) only
    - All inbound: DENY (tunnel handles all other traffic)
    - All outbound: ALLOW
```

No load balancer needed at current scale. Cloudflare Tunnel handles TLS termination.

**Gap S1 (SSH port):** Keep 22 vs. non-standard. **Recommendation: use non-standard port (e.g., 2222)** — reduces noise from scanners significantly with zero cost. Decision needed before provisioning.

**Gap S2 (owner IPs):** SSH allowlist needs explicit IPs before firewall resource is written.

### 3.4 Terraform Module Structure

```
terraform/
├── environments/
│   └── prod/
│       ├── main.tf          # calls modules, wires outputs
│       ├── variables.tf     # no defaults for secrets; all from env/tfvars
│       ├── outputs.tf       # server IP, volume ID, etc.
│       └── backend.tf       # Hetzner Object Storage S3-compat backend
└── modules/
    ├── server/              # hcloud_server, hcloud_ssh_key, cloud-init
    ├── firewall/            # hcloud_firewall, rules
    ├── network/             # hcloud_network, hcloud_subnet (future expansion)
    └── volume/              # hcloud_volume, attachment
```

**No Terragrunt at this stage.** Single environment (`prod`). Terragrunt's value is wrapping multiple environments — introducing it now adds complexity without benefit. When `staging` is added, refactor to Terragrunt at that point.

> ADR-T01: No Terragrunt until second environment is needed. Module boundaries already provide the isolation needed for a future refactor.

### 3.5 Terraform State Backend

```hcl
terraform {
  backend "s3" {
    bucket                      = "homeclaw-tfstate"          # Gap I4
    key                         = "prod/terraform.tfstate"
    region                      = "eu-central-1"              # Hetzner Object Storage region
    endpoint                    = "https://nbg1.your-objectstorage.com"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

Credentials passed via environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) — never in files.

Local backup: `terraform/environments/prod/.terraform.tfstate.backup` — gitignored.

### 3.6 Cloud-Init (Server Bootstrap)

On first boot, cloud-init will:
1. Create non-root deploy user (`homeclaw`)
2. Add owner SSH public key (Gap I2) to `~homeclaw/.ssh/authorized_keys`
3. Set SSH config: `PasswordAuthentication no`, `PermitRootLogin no`, `AllowUsers homeclaw`, `Port 2222`
4. Install Docker + Docker Compose plugin (official Docker apt repo)
5. Install `cloudflared` (Cloudflare repo)
6. Mount the attached volume at `/mnt/postgres-data`
7. Set up `ufw` firewall rules (belt-and-suspenders alongside Hetzner firewall)

Cloud-init template stored at `terraform/modules/server/cloud-init.yaml.tpl`.

---

## 4. Application Stack

### 4.1 Shared Services (single Compose stack)

```yaml
# /opt/homeclaw/shared/docker-compose.yml

services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - /mnt/postgres-data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - homeclaw-internal

  cloudflared:
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel --config /etc/cloudflared/config.yml run
    volumes:
      - /etc/cloudflared:/etc/cloudflared:ro
    networks:
      - homeclaw-internal

networks:
  homeclaw-internal:
    driver: bridge
    name: homeclaw-internal
```

`init.sql` creates databases on first run:
```sql
CREATE DATABASE clarvis_ai;
CREATE DATABASE personal_assistant;
CREATE DATABASE home_procurement;
CREATE USER clarvis WITH PASSWORD '...';  -- secrets from .env
GRANT ALL PRIVILEGES ON DATABASE clarvis_ai TO clarvis;
-- etc.
```

### 4.2 Cloudflared Tunnel Config

```yaml
# /etc/cloudflared/config.yml
tunnel: <tunnel-id>         # from `cloudflared tunnel create homeclaw`
credentials-file: /etc/cloudflared/homeclaw.json

ingress:
  - hostname: bot.obfuscatedbadger.lol
    service: http://clarvis-ai:8001
  - hostname: assistant.obfuscatedbadger.lol
    service: http://personal-assistant:8002
  - hostname: procurement.obfuscatedbadger.lol
    service: http://home-procurement:8003
  - service: http_status:404
```

Tunnel token and credentials stored in `/etc/cloudflared/` on VPS, provisioned via GitHub Actions deploy job (not Terraform).

### 4.3 Per-Solution Compose Stacks

Each solution lives in `/opt/homeclaw/{solution}/docker-compose.yml` and connects to the `homeclaw-internal` network (external: true) to reach PostgreSQL.

**Clarvis-AI:**
```yaml
services:
  clarvis-ai:
    image: ghcr.io/lowflying/homeclaw/clarvis-ai:${IMAGE_TAG}
    restart: unless-stopped
    ports: ["127.0.0.1:8001:8001"]
    env_file: .env
    networks:
      - homeclaw-internal
```

**Personal-Assistant:**
```yaml
services:
  personal-assistant:
    image: ghcr.io/lowflying/homeclaw/personal-assistant:${IMAGE_TAG}
    restart: unless-stopped
    ports: ["127.0.0.1:8002:8002"]
    env_file: .env
    networks:
      - homeclaw-internal
```

**Home Procurement:**
```yaml
services:
  home-procurement:
    image: ghcr.io/lowflying/homeclaw/home-procurement:${IMAGE_TAG}
    restart: unless-stopped
    ports: ["127.0.0.1:8003:8003"]
    env_file: .env
    networks:
      - homeclaw-internal
```

All solution containers bind only to `127.0.0.1` — not reachable from outside the VPS. Cloudflared routes to them by name via the shared Docker network.

### 4.4 Image Registry

GitHub Container Registry (`ghcr.io`). Free for public repos; private packages available on free tier. Each solution has its own image, tagged by git SHA + `latest`.

---

## 5. Home Procurement Agent — Detailed Design

### 5.1 Component Map

```
Telegram
  │  user sends: [home-procurement] I need quotes for...
  ▼
homelabber bot (existing)
  │  routes to home-procurement solution
  ▼
home-procurement webhook (FastAPI, port 8003)
  │  verify Telegram signature
  │  sanitize input
  ▼
OpenClaw agent
  │  reads: procurement job spec
  │  writes: jobs table (PostgreSQL)
  │  calls: email_send tool (Resend.com API)
  │  calls: web_search tool (optional — vendor discovery)
  ▼
Resend.com API
  │  sends from: procurement@obfuscatedbadger.lol
  │  to: vendor email addresses
  ▼
Vendor replies → Cloudflare Email Routing
  │  forwards to: procurement.obfuscatedbadger.lol/email/inbound
  ▼
home-procurement inbound email handler
  │  verify Cloudflare signature
  │  sanitize email body
  ▼
OpenClaw agent (quote-parser mode)
  │  extracts: vendor name, item, price, lead time, validity
  │  writes: quotes table (PostgreSQL)
  │  notifies: user via Telegram if all quotes in, or on-demand
  ▼
User requests summary: [home-procurement] show quotes for job X
  ▼
OpenClaw agent (comparison mode)
  │  reads: jobs + quotes tables
  │  renders: comparison markdown table
  ▼
Telegram reply
```

### 5.2 PostgreSQL Schema

```sql
-- home_procurement database

CREATE TABLE jobs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    telegram_user_id BIGINT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'open',  -- open, quotes_in, closed
    brief       TEXT NOT NULL,       -- original user brief, sanitized
    items       JSONB NOT NULL,      -- structured item list
    deadline    DATE
);

CREATE TABLE vendors (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    email       TEXT NOT NULL UNIQUE,
    category    TEXT,  -- e.g. 'doors', 'windows', 'general'
    added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE inquiries (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id      UUID NOT NULL REFERENCES jobs(id),
    vendor_id   UUID NOT NULL REFERENCES vendors(id),
    sent_at     TIMESTAMPTZ,
    email_subject TEXT,
    email_body  TEXT,   -- store sanitized copy for audit
    status      TEXT NOT NULL DEFAULT 'sent'  -- sent, replied, no_response
);

CREATE TABLE quotes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inquiry_id  UUID NOT NULL REFERENCES inquiries(id),
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    raw_email   TEXT,       -- sanitized vendor reply (PII stripped in logs)
    line_items  JSONB,      -- extracted structured quote
    total_price NUMERIC(10,2),
    currency    TEXT DEFAULT 'CAD',
    lead_time_days INT,
    valid_until DATE,
    notes       TEXT
);
```

### 5.3 OpenClaw Tools Required

| Tool | Description | Security Note |
|---|---|---|
| `email_send` | Send inquiry email via Resend.com | Allowlisted — only outbound to configured vendor addresses |
| `email_read` | Read inbound vendor reply from DB | Input sanitized before tool is called |
| `db_write` | Write job/inquiry/quote to PostgreSQL | Parameterised queries only, no string interpolation |
| `db_read` | Read job status and quotes | Read-only role for query operations |
| `telegram_send` | Send message to originating user | User ID verified against whitelist |
| `web_search` | Optional: discover vendor contacts | Result treated as untrusted, not passed raw to LLM |

`web_search` is optional — the default behaviour uses a pre-seeded `vendors` table. If no matching vendors exist for a category, agent reports gap to user rather than searching autonomously. This is the safer default; enable web search explicitly per deployment.

### 5.4 Vendor Management

Vendors seeded via a `vendors.csv` file managed in the repo (not secrets — just company names and public contact emails). The deploy job imports this on first run. Users can add vendors via Telegram: `[home-procurement/admin] add vendor Acme Doors acme@example.com category:doors`.

### 5.5 Email Templates

Inquiry email template (rendered by OpenClaw, not raw LLM output — to prevent injection into outbound emails):

```
Subject: Quote Request — [Item Category] — [Job ID]

Hi,

I'm looking for quotes on the following items for a residential project:

[ITEMS TABLE — structured, generated from jobs.items JSONB]

Details:
- Delivery location: [configured in job]
- Quote deadline: [jobs.deadline]
- Reference: [jobs.id]

Please reply to this email with your best pricing, lead time, and any relevant product specs.

Thank you,
[configured sender name]
procurement@obfuscatedbadger.lol
```

The LLM generates the brief description and items structure. The email template is hardcoded — the LLM does not write the final email HTML/text. This prevents prompt injection into outbound emails.

---

## 6. CI/CD Pipeline Design

### 6.1 Pipeline Stages

```
PR opened / push to branch:
  1. Lint & Validate
     - terraform fmt -check
     - terraform validate
     - docker build (for each solution)
     - pytest (unit tests)

  2. Terraform Plan
     - terraform plan -out=tfplan
     - Post plan summary as PR comment (via gh CLI or GitHub Actions PR comment action)

On merge to main:
  3. Build & Push
     - docker build + tag with git SHA
     - docker push to ghcr.io

  4. Terraform Apply (manual approval gate)
     - GitHub Actions environment: "production"
     - Requires manual reviewer approval in GitHub UI
     - terraform apply tfplan

  5. Deploy Solutions
     - SSH into VPS (using VPS_SSH_KEY secret)
     - For each changed solution:
         docker compose pull
         docker compose up -d --remove-orphans
     - Health check: curl each webhook /health endpoint
     - Rollback trigger: if health check fails, docker compose up -d --no-recreate (previous image still tagged)
```

### 6.2 Rollback Strategy

Each deploy tags the previous image as `previous` before pulling `latest`. If health check fails post-deploy, the pipeline runs:
```bash
docker compose stop {service}
docker tag ghcr.io/.../service:previous ghcr.io/.../service:latest
docker compose up -d {service}
```

### 6.3 GitHub Actions Secrets Required

| Secret | Description |
|---|---|
| `HCLOUD_TOKEN` | Hetzner API token |
| `TF_BACKEND_ACCESS_KEY` | Hetzner Object Storage access key |
| `TF_BACKEND_SECRET_KEY` | Hetzner Object Storage secret key |
| `VPS_SSH_KEY` | Private SSH key for deploy user |
| `VPS_HOST` | VPS IP address |
| `VPS_SSH_PORT` | SSH port (e.g., 2222) |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token |
| `TELEGRAM_WEBHOOK_SECRET` | Webhook verification secret |
| `RESEND_API_KEY` | Resend.com API key |
| `CLOUDFLARE_TUNNEL_TOKEN` | Cloudflare Tunnel token |
| `POSTGRES_PASSWORD` | Shared PostgreSQL password |
| `GHCR_TOKEN` | GitHub Container Registry write token |

---

## 7. Secret Distribution on VPS

Secrets flow: **GitHub Actions Secrets → SSH deploy job → VPS .env files → Running containers**

Each solution has `/opt/homeclaw/{solution}/.env` written by the deploy job. The deploy job templates the .env from GitHub Actions secrets. Files are mode 600, owned by `homeclaw` user.

Never in git:
- Any `.env` file
- `terraform.tfstate` or `terraform.tfstate.backup`
- `/etc/cloudflared/homeclaw.json`
- PostgreSQL passwords

---

## 8. Backup Strategy

**PostgreSQL:**
- Nightly `pg_dumpall` → compressed file → `rclone` sync to Hetzner Object Storage bucket (`homeclaw-backups`)
- Retention: 7 daily, 4 weekly, 3 monthly
- Restore tested: manual process, documented in `infra/docs/runbooks/restore-postgres.md` (to be written)

**Volume Snapshots:**
- Weekly Hetzner Volume snapshot via Hetzner API (automated via cron in GitHub Actions scheduled workflow)
- Retention: 4 weekly snapshots

**Gap A2 — backup strategy confirmed here.** Implementation deferred to dev phase.

---

## 9. New Solution: home-procurement Folder Structure

```
solutions/home-procurement/
├── AGENT.md
├── AGENT_planner.md
├── AGENT_dev.md
├── AGENT_qa.md
├── docs/
│   ├── architecture.md    (← this section extracted and moved here)
│   ├── security.md
│   └── sessions/
├── src/
│   ├── main.py            (FastAPI app, to be written)
│   ├── agent.py           (OpenClaw agent config, to be written)
│   ├── email_handler.py   (inbound email parser, to be written)
│   ├── models.py          (SQLAlchemy models, to be written)
│   └── templates/
│       └── inquiry.txt    (email template, to be written)
├── tests/
├── Dockerfile
├── docker-compose.yml
└── .env.example
```

---

## 10. Open Gaps — Prioritised

| ID | Description | Blocker for |
|---|---|---|
| **A1** | CX31 server size confirmed? | terraform apply |
| **S1** | SSH port — recommend 2222 | terraform apply |
| **S2** | Owner IP(s) for SSH allowlist | terraform apply |
| **I2** | Owner SSH public key | cloud-init |
| **I4** | Object Storage bucket name | terraform backend |
| **I5** | Hetzner project name | HCLOUD_TOKEN scope |
| **C1** | Clarvis-AI framework review | clarvis-ai dev |
| **PA1** | OpenClaw framework review | all solution dev |
| **HP1** | Initial vendor list for home-procurement | procurement dev |
| **HP2** | Sending subdomain: `procurement@obfuscatedbadger.lol` verified in Resend? | procurement deploy |
| **HP3** | Enable `web_search` tool? (requires decision on vendor discovery strategy) | procurement scoping |

---

## 11. Next Steps (Ordered)

1. **Resolve gaps A1, S1, S2, I2** — these are the only blockers before writing Terraform
2. **Review OpenClaw repo** — needed before any solution dev starts (PA1)
3. **Write Terraform** — `[infra/dev]` task, using this session as the spec
4. **Provision VPS** — manual approval gate; confirm plan before apply
5. **Write home-procurement AGENT.md and docs** — extract section 5 above
6. **Clarvis-AI framework review** — `[clarvis-ai/planner]` task
7. **Begin solution dev** — start with home-procurement (simpler, no external framework unknown)
8. **Pipeline implementation** — `[infra/dev]` task, after VPS is provisioned

---

*Session written by: infra/planner persona*
*Security review: pending — see `2026-03-19-openclaw-hetzner-deploy-security-review.md`*
