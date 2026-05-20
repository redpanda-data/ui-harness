---
name: codex-compat
description: Generate Codex hooks.json and AGENTS.md from Claude Code hooks. Maps supported hooks directly, including Edit|Write apply_patch aliases, and keeps Stop batch checks only as fallback. Use when setting up Codex compatibility or dual-agent support.
---

# Codex Compatibility Layer

Codex now supports Claude-style lifecycle hooks for `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, and `Stop`. `PreToolUse`/`PostToolUse` matchers support `Bash`, MCP tool names, `apply_patch`, and `Edit|Write` aliases. Map `Edit|Write` hooks direct whenever possible.

## What This Creates

- **`.codex/hooks.json`** -- direct translation for supported Claude hooks
- **`.codex/hooks/codex-batch-check.sh`** -- fallback only for checks that cannot run per tool event
- **`AGENTS.md`** + **`CLAUDE.md`** -- shared project rules (Codex reads AGENTS.md, Claude Code reads CLAUDE.md)
- **compatibility matrix** -- classify hooks as `direct`, `direct with shim`, `fallback only`, or `unsupported`

## Steps

1. Read `.claude/settings.json` and classify every hook with the [REFERENCE.md](REFERENCE.md) compatibility matrix.
2. Generate `.codex/hooks.json`:
   - `SessionStart`, `UserPromptSubmit`, `Stop` -> direct
   - `PreToolUse` / `PostToolUse` with `Bash`, `Edit|Write`, `apply_patch`, `mcp__.*` -> direct
   - `PermissionRequest` for `Bash` / MCP / `apply_patch` -> direct where scripts understand Codex payloads
   - Unsupported Claude events or handler types -> omit, document, or route to fallback only when semantics stay safe
3. Copy `scripts/codex-batch-check.sh` -> `.codex/hooks/` only if fallback hooks are needed. `chmod +x`.
4. Generate `AGENTS.md` + `CLAUDE.md` from [REFERENCE.md](REFERENCE.md) template.

## Verify

- [ ] `.codex/hooks.json` contains direct `Edit|Write` PostToolUse hooks when source has them
- [ ] Batch checker is absent unless a real fallback-only hook needs it
- [ ] `AGENTS.md` + `CLAUDE.md` at repo root
- [ ] `.claude/settings.json` unchanged
