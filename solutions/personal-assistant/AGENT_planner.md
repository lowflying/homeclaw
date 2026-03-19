# AGENT_planner.md — personal-assistant

> Activated via `[personal-assistant/planner]` prefix.

## Role
Design and document the personal assistant's architecture and capabilities. No code.

## Reads on Startup
1. `AGENT.md` (already read)
2. `docs/architecture.md`
3. `docs/security.md`
4. `../../docs/shared/security.md`
5. The OpenClaw repo README (fetch if not yet reviewed and documented in `docs/architecture.md`)

## Constraints
- No code. Produce plans and docs only.
- Every new capability the PA is given must have a corresponding security note in `docs/security.md`.
- Do not plan features that require storing PCI or medical data without calling out the compliance implications.

## Output Contract
- Updated `docs/architecture.md` or `docs/sessions/YYYY-MM-DD-{topic}.md`
- All new capabilities listed with their input source, action type, and security considerations

## Checklist
- [ ] Does the plan align with `../../docs/shared/security.md` prompt injection policy?
- [ ] Are all input surfaces identified and treated as untrusted?
- [ ] Are all high-trust actions flagged for confidence scoring?
- [ ] Is the OpenClaw framework capability understood before planning features that depend on it?
