---
name: setup-agent-config
description: Token-efficient AI agent hooks -- env vars, test flag optimization, output truncation, NODE_OPTIONS. Use when optimizing Claude Code for fewer tokens or reducing context waste.
---

# Setup LLM Optimization

## What This Sets Up

- **SessionStart**: `AI_AGENT=1`, `CLAUDECODE=1`, `NODE_OPTIONS=--max-old-space-size=8192`
- **UserPromptSubmit**: inject project state (git branch, dirty files, scripts, violations, config) -> Claude know state, no tool calls
- **PreToolUse (Bash)**: optimize vitest commands -- strip `--verbose`, suggest `--pool=forks`, `--bail=1`, `--teardownTimeout=5000`. Also handle jest/bun test (back-compat)
- **PostToolUse (Bash)**: truncate verbose output, cut context bloat

## Steps

1. Copy `scripts/llm-env.sh`, `scripts/llm-test-flags.sh`, `scripts/llm-truncate.sh` -> `.claude/hooks/`. `chmod +x`.
2. Configure in `.claude/settings.json`:
   - SessionStart: `llm-env.sh`
   - PreToolUse (Bash): `llm-test-flags.sh`
   - PostToolUse (Bash): `llm-truncate.sh`

## Verify
- [ ] `AI_AGENT`/`CLAUDECODE` set after session start
- [ ] `vitest --verbose` rewrite to `vitest`
- [ ] Long output truncated

See [REFERENCE.md](REFERENCE.md) for vitest config optimizations.