# Agent System Design

> Cross-cutting design decisions for how Claude agents are structured, invoked, and chained across all sub-projects.
> This doc is the authority on persona design, Telegram routing, sequential chaining, and compaction mitigation.
> Read this before designing any agent workflow.

---

## Principles

1. **Files are the memory, not conversations.** Every decision, plan, and output lands in a file. Conversations are ephemeral. Files survive compaction, session restarts, and interface changes.
2. **One bot, many personas.** No per-persona or per-project Telegram bots. One bot, routed by message prefix.
3. **Atomic tasks.** Each Telegram message = one Claude invocation = one clear output artifact. Brainstorming produces a session doc. Planning produces an architecture doc. Implementation produces code. Never open-ended.
4. **Sequential chaining over parallel.** Agents hand off via files. Planner writes a spec → dev reads it and codes → QA reads both and reviews. Each step is a separate invocation. Robust, auditable, compaction-safe.

---

## Persona System

### How Personas Work

Each sub-project contains a default `AGENT.md` plus optional persona-specific files:

```
solutions/clarvis-ai/
├── AGENT.md           ← default: conservative, plan-first, safe
├── AGENT_planner.md   ← elicit requirements, produce docs, no code
├── AGENT_dev.md       ← implement from docs, write tests, no planning
├── AGENT_qa.md        ← review, challenge, find security gaps
```

Claude Code reads `AGENT.md` automatically. Personas are activated by **injecting a read instruction into the prompt** at invocation time — not by separate bots or config changes.

### Telegram Message Format

Messages to the Telegram bot follow a structured prefix convention:

```
[project/persona] task description
```

Examples:
```
[clarvis-ai/planner] design the telegram webhook integration
[personal-assistant/dev] implement the email receive handler
[infra/dev] write terraform for the hetzner firewall
[clarvis-ai/qa] review the prompt injection mitigations
[clarvis-ai] what's the current status of the webhook work     ← no persona = default AGENT.md
```

If no persona is specified, the default `AGENT.md` is used (conservative, plan-first).

### How the Bridge Routes This

The homelabber planner step is extended to parse the prefix and produce:

```json
{
  "task_type": "dev",
  "project_path": "/home/lowflying/homeclaw/solutions/clarvis-ai",
  "persona_file": "AGENT_dev.md",
  "prompt": "You are acting as the dev persona for this project. First read AGENT_dev.md in this directory, then read docs/architecture.md, then: implement the email receive handler",
  "description": "clarvis-ai/dev: implement email receive handler"
}
```

The `persona_file` field is new. The bridge injects a read instruction at the top of the prompt before the task. No other changes to the bridge are needed.

**Routing table** lives in the homelabber planner system prompt — a mapping of short project names to full paths:

```
clarvis-ai      → /home/lowflying/homeclaw/solutions/clarvis-ai
personal-assistant → /home/lowflying/homeclaw/solutions/personal-assistant
infra           → /home/lowflying/homeclaw/infra
```

This table must be kept in sync with the actual directory structure.

---

## Sequential Agent Chaining (Agent Teams)

A "team" of agents is a sequence of Claude invocations where each step reads the previous step's output from a file and writes its own output to a file.

### Example: Feature Development Chain

```
Telegram: [clarvis-ai/planner] design the 3d printer integration

Step 1 — Planner invocation:
  reads:  AGENT_planner.md, docs/architecture.md, docs/security.md
  writes: docs/sessions/2026-03-19-3d-printer-integration.md
  output: structured spec with requirements, open questions, proposed approach

--- human reviews the spec doc, optionally edits it ---

Telegram: [clarvis-ai/dev] implement docs/sessions/2026-03-19-3d-printer-integration.md

Step 2 — Dev invocation:
  reads:  AGENT_dev.md, docs/architecture.md, docs/sessions/2026-03-19-3d-printer-integration.md
  writes: source files + tests
  output: implementation

Telegram: [clarvis-ai/qa] review docs/sessions/2026-03-19-3d-printer-integration.md against current code

Step 3 — QA invocation:
  reads:  AGENT_qa.md, docs/sessions/2026-03-19-3d-printer-integration.md, source files
  writes: docs/sessions/2026-03-19-3d-printer-integration-review.md
  output: issues found, security gaps, suggested changes
```

The human is in the loop between steps — they decide when to advance the chain. This is intentional. Fully automated chaining (planner → dev → qa with no human review) is possible but not recommended until each agent's output is trusted for that project.

### Brainstorming Sessions

Brainstorming via Telegram uses the planner persona with a specific output contract:

```
Telegram: [clarvis-ai/planner] brainstorm approaches for integrating with a creality printer that might not have an api
```

The planner:
1. Opens `docs/sessions/YYYY-MM-DD-{topic}.md` (creates if absent)
2. Writes a structured exploration: options, trade-offs, open questions, recommendation
3. Responds to Telegram with a summary + "full notes in docs/sessions/..."

The session file becomes the continuity artifact. If you want to continue the brainstorm, reference the file:

```
Telegram: [clarvis-ai/planner] continue brainstorm in docs/sessions/2026-03-19-printer-integration.md, focus on the moonraker option
```

---

## Compaction Mitigation

### Why Compaction Happens

Claude's context window is ~200k tokens. When a session (conversation history + files read + output) approaches the limit, older messages are compressed. Decisions made in conversation but not written to files can be lost or distorted.

### Mitigations Built Into This System

| Risk | Mitigation |
|---|---|
| Long Telegram brainstorming sessions losing context | Session files written progressively; each exchange appends to the file |
| Big tasks requiring many file reads | Docs are kept concise; agents read only what's relevant to the task |
| Decisions made in conversation not persisted | Agents write to docs as decisions are made, not at session end |
| Cold-start sessions missing context | Each sub-project's AGENT.md tells Claude exactly which docs to read on startup |
| Architecture drift between sessions | AGENT.md instructs every session to check for drift before acting |

### Practical Rules for Claude Operating in This System

- **Write decisions to files immediately**, not at the end of a session.
- If a task requires reading more than ~5 large files, scope it down or break it into steps.
- After any planning session, do an explicit "capture sweep" — anything decided in conversation that isn't yet in a doc gets written before responding.
- Session files (in `docs/sessions/`) are the working memory for multi-step work. Keep them.
- Never rely on a human remembering what was decided in a previous conversation. If it isn't in a file, it didn't happen.

### Token Budget Awareness

When operating via the Telegram bridge, the prompt includes:
- Persona file (~500–1000 tokens)
- Architecture doc (~1500–3000 tokens)
- Security doc (~1000–2000 tokens)
- The task (~100–500 tokens)
- Any session files referenced (~1000–5000 tokens)

For a typical focused task this is well within budget. Risk areas:
- Asking an agent to "review everything" — scope it
- Chaining many file reads before acting — read only what's needed
- Very long session files — summarise them periodically (the reflection step in homelabber is a good model)

---

## Persona File Conventions

Each persona file should follow this structure:

```markdown
# AGENT_{PERSONA}.md — {Project Name}

## Role
One sentence: what this persona does and does not do.

## Reads on Startup
List of files to read before any action (in order).

## Constraints
What this persona must not do (e.g. AGENT_planner.md: "do not write code").

## Output Contract
What this persona always produces (e.g. "a session doc in docs/sessions/").

## Checklist
Role-specific checklist run before considering a task complete.
```

---

## Open Questions / Future Work

- **Automated chaining:** Could the bridge auto-chain planner → dev → qa for certain task types without human intervention. Not recommended until per-project agent output is trusted. Flag for revisit.
- **Parallel subagents:** Claude's Agent tool supports parallel subagent invocation. For tasks that can be split (e.g. "write tests for module A and module B simultaneously") this is worth exploring. Requires the Agent SDK or Claude Code's built-in Agent tool — not currently available via the Telegram bridge.
- **Persona routing via slash commands:** Instead of `[project/persona]` prefix, consider Telegram slash commands: `/dev clarvis-ai implement the webhook handler`. Cleaner UX, same routing logic.
