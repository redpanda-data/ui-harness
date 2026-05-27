---
name: git-guardrails-claude-code
description: Install Claude hooks blocking dangerous git commands before execution.
---

# Git Guardrails

Install PreToolUse Bash hook blocking dangerous git before Claude runs it.

Blocks: `git push`, `git reset --hard`, `git clean -f/-fd`, `git branch -D`, `git checkout .`, `git restore .`.

## Steps

1. Ask scope: project `.claude/settings.json` or global `~/.claude/settings.json`.
2. Copy bundled `scripts/block-dangerous-git.sh` to:
   - project: `.claude/hooks/block-dangerous-git.sh`
   - global: `~/.claude/hooks/block-dangerous-git.sh`
3. `chmod +x` hook.
4. Add PreToolUse Bash command in chosen settings:

```json
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":".claude/hooks/block-dangerous-git.sh"}]}]}}
```

5. Test with blocked command. Confirm hook denies.
