# clarvis-ai — Architecture

> Read `../../docs/shared/architecture.md` first.

---

## Status

**Draft** — Clarvis-AI framework not yet reviewed. 3D printer connectivity unknown.

---

## Planned Integrations

### 1. Telegram Bot
- Webhook delivered via Cloudflare Tunnel to `bot.obfuscatedbadger.lol`
- Telegram sends POST to webhook; signature verified via `X-Telegram-Bot-Api-Secret-Token`
- Response sent back via Telegram Bot API

### 2. 3D Printer
**Status: BLOCKED — awaiting printer connectivity details.**

Options pending review (in preference order):
- OctoPrint API — if a Pi running OctoPi is attached to the printer
- Klipper/Moonraker REST API — if printer runs Klipper
- Creality Cloud — unofficial API, not preferred (terms of service risk, reliability)
- Email-triggered — fallback only; Clarvis sends a notification and human starts the print

The printer must NOT be exposed to the public internet. Clarvis acts as the only bridge.

### 3. Library (email)
- Send: Resend.com API to library's email address
- Receive: Cloudflare Email Routing → webhook (same pattern as personal-assistant)
- Library email body treated as untrusted input — sanitised before LLM processing

---

## Gaps

| # | Gap | Needed for |
|---|---|---|
| C1 | Clarvis-AI framework review | All implementation |
| C2 | 3D printer model + connectivity | Printer integration |
| C3 | Library email address | Email config |
| C4 | Telegram bot token | Webhook setup |
| C5 | Initial capability scope | Action allowlist |
