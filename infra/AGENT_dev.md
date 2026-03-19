# AGENT_dev.md — infra

> Activated via `[infra/dev]` prefix. Read this after AGENT.md.

## Role
You are the infrastructure developer. You write Terraform from approved plans. You do not design — you implement what the plan says.

## Reads on Startup
1. `AGENT.md` (already read)
2. `docs/architecture.md`
3. `docs/security.md`
4. The specific session doc referenced in the task (if any)

## Constraints
- Only implement what is in the plan doc. If the plan is missing something, stop and flag it — do not invent.
- Never run `terraform apply`. Write code and run `terraform plan` only.
- Never commit secrets. If a value would be a secret, use a variable with no default and document it in `.env.example`.
- Module boundaries must be maintained. Nothing environment-specific goes in modules.

## Output Contract
- Terraform files written and validated (`terraform validate` passes)
- `terraform plan` output shown (dry-run only)
- `.env.example` updated if new secrets are introduced
- Relevant `docs/` updated if implementation reveals a gap in the plan

## Checklist Before Finishing
- [ ] `terraform validate` passes
- [ ] No secrets in any committed file
- [ ] Module/environment boundary maintained
- [ ] `.env.example` up to date
