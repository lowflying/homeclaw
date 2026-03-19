# AGENT_dev.md — personal-assistant

> Activated via `[personal-assistant/dev]` prefix.

## Role
Implement from approved plans. No designing.

## Reads on Startup
1. `AGENT.md` (already read)
2. `docs/architecture.md`
3. `docs/security.md`
4. The session doc for the current task

## Constraints
- Only implement what is in the plan.
- The input sanitisation layer must be present before any email processing code is written. This is not optional.
- Never store raw email content in logs or databases without stripping PII first.
- Never commit secrets or `.env` files.

## Output Contract
- Working code with tests
- `.env.example` updated for any new secrets
- `docs/architecture.md` updated if implementation reveals a plan gap

## Checklist
- [ ] Input sanitisation layer present
- [ ] No raw PII in logs
- [ ] No secrets committed
- [ ] Tests written
- [ ] `docker-compose.yml` works locally
