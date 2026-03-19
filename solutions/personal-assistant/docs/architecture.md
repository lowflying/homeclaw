# personal-assistant — Architecture

> Read `../../docs/shared/architecture.md` first.

---

## Status

**Draft** — OpenClaw framework not yet reviewed. This file will be populated after the framework review and planning session.

---

## Planned Design (subject to revision after OpenClaw review)

### Flow

```
Email arrives at assistant@obfuscatedbadger.lol
    │
    ▼
Cloudflare Email Routing
    │ forwards to webhook
    ▼
VPS: email webhook endpoint
    │ sanitises input, applies system prompt segregation
    ▼
OpenClaw agent
    │ reasons, decides action
    ▼
Action execution (allowlisted only)
    │
    ├── Send email reply (Resend.com API)
    ├── Create calendar event (TBD — capability to be planned)
    ├── Write to personal notes (TBD)
    └── Refuse + queue for human review (if low confidence or injection suspected)
```

### Email Channel

- **Receive:** Cloudflare Email Routing → webhook → input sanitisation layer
- **Send:** Resend.com API from `assistant@obfuscatedbadger.lol`
- **Sender verification:** SPF/DKIM/DMARC checked before processing. Emails failing these checks are quarantined, not processed.

### OpenClaw

- Framework: https://github.com/openclaw/openclaw
- **Must review this repo before completing this architecture doc.**
- Unknown: config format, supported tools/integrations, deployment model

---

## Gaps

| # | Gap | Needed for |
|---|---|---|
| PA1 | OpenClaw framework review | All implementation |
| PA2 | Initial capability scope (what can the PA actually do?) | Action allowlist |
| PA3 | Confidence scoring threshold for action execution | Security policy |
| PA4 | Calendar integration (which provider?) | Capability planning |
| PA5 | Persistent memory strategy (PostgreSQL schema) | Data model |
