---
name: setup-toolchain
description: Enforce bun + tsgo as toolchain via PreToolUse hooks. Blocks npm, npx, tsc, global installs. Use when setting up toolchain enforcement or banning npm.
---

# Setup Toolchain Enforcement

## What This Sets Up

- **PreToolUse hooks** block banned CLI commands, give actionable suggestions
- **Destructive command guards** prevent `rm -rf` (except safe targets like node_modules/.next/dist/build), `git push --force`, `git reset --hard`, `git checkout .` / `git restore .`
- **SessionStart hook** set env vars for LLM-friendly defaults
- Hooks in `.claude/settings.json` (project-level, committed to git)

## Steps

### 1. Create hook scripts

Copy [`scripts/enforce-toolchain.sh`](scripts/enforce-toolchain.sh) and [`scripts/session-env.sh`](scripts/session-env.sh) to `.claude/hooks/`. Make executable: `chmod +x .claude/hooks/*.sh`

### 2. Configure hooks in `.claude/settings.json`

Add to hooks config (merge existing):
- **PreToolUse** (matcher: `Bash`): `.claude/hooks/enforce-toolchain.sh`
- **SessionStart**: `.claude/hooks/session-env.sh`

### 3. Verify

- [ ] `.claude/hooks/enforce-toolchain.sh` exists, executable
- [ ] `.claude/hooks/session-env.sh` exists, executable
- [ ] `.claude/settings.json` has both hook entries
- [ ] Test: run `npm install` in Claude -- should block
- [ ] Test: run `bun add lodash` in Claude -- should block (missing --yarn)

### 4. Commit

Stage `.claude/hooks/` and `.claude/settings.json`. Commit: `Add toolchain enforcement hooks (bun + tsgo)`