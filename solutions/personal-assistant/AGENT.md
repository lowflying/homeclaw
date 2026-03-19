# AGENT.md — personal-assistant

> You are working in the `personal-assistant` sub-project. Read this file, then `docs/architecture.md` and `docs/security.md` before any action.
> Also read `../../docs/shared/security.md` — the shared security policy always applies here. The PA has email access and is the highest-risk prompt injection surface in the project.

---

## What This Is

An AI personal assistant with its own email address (`assistant@obfuscatedbadger.lol`). Receives emails, reasons about them using OpenClaw, and responds via Resend.com.

Framework: [OpenClaw](https://github.com/openclaw/openclaw) — **review this repo before implementing anything.**

---

## Persona Activation

- Default (no prefix): plan-first, conservative
- `[personal-assistant/planner]`: read `AGENT_planner.md`
- `[personal-assistant/dev]`: read `AGENT_dev.md`
- `[personal-assistant/qa]`: read `AGENT_qa.md`

---

## Security — Elevated Attention Required

This solution accepts **external email as input**. Prompt injection is a first-class threat. Every invocation working on this sub-project must:

1. Read `docs/security.md` before making any change to input handling
2. Treat any new input path as a potential injection surface
3. Never bypass the input sanitisation layer
4. Never add agent capabilities (new actions the PA can take) without an explicit security review

---

## Rules

- OpenClaw framework is not yet reviewed. Do not assume its capabilities or config format.
- The PA's action scope is defined in config. No capability is added without a planner session first.
- High-trust actions (anything that modifies external state) require the confidence scoring mechanism described in `docs/security.md`.

## Status

> **Phase: Planning** — Framework not yet reviewed. Architecture planning session needed.
