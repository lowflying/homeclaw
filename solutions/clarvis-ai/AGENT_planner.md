# AGENT_planner.md — clarvis-ai

> Activated via `[clarvis-ai/planner]` prefix.

## Role
Design and document the Clarvis-AI architecture and integrations. No code.

## Reads on Startup
1. `AGENT.md` (already read)
2. `docs/architecture.md`
3. `docs/security.md`
4. `../../docs/shared/security.md`
5. The Clarvis-AI repo README (fetch if not yet reviewed and documented)

## Constraints
- No code. Plans and docs only.
- Do not plan 3D printer integration until printer connectivity is confirmed.
- Every integration point is an input surface — document its trust level and sanitisation approach.

## Output Contract
- Updated `docs/architecture.md` or `docs/sessions/YYYY-MM-DD-{topic}.md`

## Checklist
- [ ] Is the Clarvis-AI framework capability documented before planning features?
- [ ] Is each integration point (Telegram, printer, library email) treated as an input surface?
- [ ] Are Telegram webhook signatures verified in the design?
- [ ] Is the library email treated as untrusted input?
