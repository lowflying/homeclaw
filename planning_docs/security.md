# Security

> This document is the security authority for the cheredie-claw project. All implementation must be consistent with it. If there is a conflict between a feature and security, raise it — don't silently compromise security.

---

## Status

**Draft** — Initial skeleton. Decisions marked TBD need resolution before relevant components are built.

---

## Principles

1. **Secrets never in git.** No API keys, tokens, passwords, or private keys in any committed file. Ever.
2. **Least privilege.** Services get only the permissions they need. No running things as root unless unavoidable.
3. **Defence in depth.** Firewall + application-level auth + TLS — not just one layer.
4. **Auditability.** Changes to infra go through git. We should be able to answer "who changed what and when."

---

## Secrets Management

### Local Development
- Secrets stored in `.env` files per solution/component
- `.env` files are in `.gitignore` — **never commit them**
- A `.env.example` file with dummy values should exist for every component that uses secrets

### CI/CD (GitHub Actions)
- All secrets stored as GitHub Actions encrypted secrets
- Never echoed in logs
- Secrets injected as environment variables at runtime

### On the VPS
- Secrets stored as environment variables in Docker Compose `.env` files on the server
- The `.env` files on the server are managed manually or via a secrets deployment step in CI/CD
- **TBD:** Consider using a secrets manager (Vault, Doppler, etc.) if the number of secrets grows — for now manual + GitHub Actions secrets is acceptable

### Secret Rotation
- TBD — no rotation policy defined yet. Should be considered for:
  - Hetzner API token
  - Telegram bot token
  - Email credentials/API keys
  - Any LLM API keys

---

## Network Security

### Firewall (Hetzner Cloud Firewall)
Inbound rules (draft — to be codified in Terraform):

| Port | Protocol | Source | Purpose |
|---|---|---|---|
| 22 | TCP | Your IP only | SSH access |
| 80 | TCP | Any | HTTP → redirect to HTTPS |
| 443 | TCP | Any | HTTPS (reverse proxy) |
| TBD | TCP | Telegram IP ranges | Telegram webhook (if needed — Telegram docs have IP list) |

Outbound: allow all (can tighten later if needed)

**Important:** SSH must be locked to a known IP or use a VPN/bastion. Wide-open SSH is not acceptable.

### TLS
- All public endpoints must use TLS (HTTPS)
- Certificate management: **TBD** (Caddy handles this automatically; nginx needs Certbot or similar)
- No self-signed certs on public endpoints

### SSH
- Key-based authentication only — no password auth
- `PermitRootLogin no` in sshd config
- Consider non-standard SSH port (e.g. 2222) to reduce noise — TBD

---

## Application Security

### OpenClaw / Personal Assistant
- The assistant's email inbox should be treated as untrusted input — prompt injection via email is a real attack vector
- Consider only processing emails from a whitelist of trusted senders, or adding a sanity filter before passing to LLM
- **TBD:** Authentication for any web-facing endpoints

### Clarvis-AI
- **Telegram:** Verify webhook requests come from Telegram (check `X-Telegram-Bot-Api-Secret-Token` header)
- **3D Printer:** If printer is network-accessible, ensure it's not exposed to the public internet — should be local network only, with Clarvis acting as the bridge
- **Library email:** Treat as untrusted input, same as personal assistant

---

## Sensitive Data

- Log files must not contain secrets, tokens, or PII
- Be careful about what the LLM logs or stores — conversation history may contain sensitive info
- **TBD:** Data retention policy for conversation history

---

## Gaps — Q&A Needed

| # | Gap | Impact |
|---|---|---|
| S1 | Your IP(s) for SSH allowlist | Firewall config |
| S2 | Secrets manager decision (manual vs Vault/Doppler) | Secrets handling on VPS |
| S3 | Data retention policy for LLM conversation history | Storage + privacy |
| S4 | Telegram IP range restriction for webhook | Firewall rules |
| S5 | SSH port — standard (22) vs non-standard | sshd config |
