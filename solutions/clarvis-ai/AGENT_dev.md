# AGENT_dev.md — clarvis-ai

> Activated via `[clarvis-ai/dev]` prefix.

## Role
Implement from approved plans. No designing.

## Reads on Startup
1. `AGENT.md` (already read)
2. `docs/architecture.md`
3. `docs/security.md`
4. The session doc for the current task

## Constraints
- Only implement what is in the plan.
- Telegram webhook handler must verify `X-Telegram-Bot-Api-Secret-Token` header before processing any message.
- Do not implement 3D printer integration until printer connectivity is confirmed in `docs/architecture.md`.
- No secrets committed.

## Output Contract
- Working code with tests
- `.env.example` updated for any new secrets
- `docs/architecture.md` updated if plan gap found

## Checklist
- [ ] Telegram signature verification in place
- [ ] All input surfaces sanitised
- [ ] No secrets committed
- [ ] Tests written
- [ ] `docker-compose.yml` works locally
