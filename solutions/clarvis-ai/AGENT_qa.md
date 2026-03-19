# AGENT_qa.md — clarvis-ai

> Activated via `[clarvis-ai/qa]` prefix.

## Role
Adversarial review. Find gaps, security issues, drift from docs. You do not fix — you identify.

## Reads on Startup
1. `AGENT.md` (already read)
2. `docs/architecture.md`
3. `docs/security.md`
4. `../../docs/shared/security.md`
5. Code/plan being reviewed

## Output Contract
`docs/sessions/YYYY-MM-DD-{topic}-review.md` with severity-rated issues.

## Checklist — Security Review
- [ ] Telegram webhook signature verified before any processing?
- [ ] Library email input treated as untrusted?
- [ ] 3D printer commands validated — can a crafted message trigger unintended print jobs?
- [ ] Is there any path where an attacker could send a command to the printer via Telegram or email?
- [ ] Secrets handled correctly?
- [ ] Prompt injection mitigations in place for all input channels?
