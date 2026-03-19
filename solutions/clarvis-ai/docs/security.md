# clarvis-ai — Security

> Shared policy at `../../docs/shared/security.md` takes precedence.

---

## Input Surfaces

| Surface | Trust level | Sanitisation required |
|---|---|---|
| Telegram messages | Untrusted (whitelisted user IDs only) | Yes — before LLM |
| Library email | Untrusted | Yes — before LLM, same as personal-assistant |
| 3D printer API responses | Semi-trusted (internal network) | Validate schema, don't pass raw to LLM |
| Cloudflare webhook headers | Trusted after signature verification | Verify signature first |

## Telegram Security

- All messages processed only from whitelisted Telegram user IDs (same pattern as `talon/homelabber`)
- Webhook endpoint verifies `X-Telegram-Bot-Api-Secret-Token` header on every request
- Non-whitelisted user IDs: silent drop (do not acknowledge)

## 3D Printer Security

- The printer integration must NEVER be reachable from the public internet
- Clarvis is the only system that sends commands to the printer
- Commands are validated against an allowlist before execution (e.g. "start job X", "cancel current job", "get status") — no arbitrary G-code injection
- If the printer connectivity is Creality Cloud (API): evaluate carefully — data leaves the local network; may be unacceptable

## Action Allowlist

| Action | Status |
|---|---|
| Respond via Telegram | Planned |
| Send email to library | Planned |
| Query printer status | Planned (pending connectivity confirmation) |
| Start print job | Planned (pending confirmation) |
| Cancel print job | Planned (pending confirmation) |
| Arbitrary G-code execution | **Prohibited** |
| Access personal-assistant data | **Prohibited** |
