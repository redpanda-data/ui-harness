---
name: setup-conventional-commits
description: Enforce conventional commit format via a PreToolUse hook on Bash that intercepts git commit commands. Replaces commitlint + husky entirely. Use when setting up conventional commits, commit message validation, or enforcing commit format standards.
---

# Setup Conventional Commits

PreToolUse hook (Bash) intercept `git commit -m` -> validate format. Replace commitlint + husky (zero deps).

## Format

```
type(scope): description
```

- **type**: feat|fix|refactor|style|test|docs|chore|perf|ci|build|revert
- **scope**: required, lowercase in parens -- `feat(webui):`, `fix(backend):`
- **description**: lowercase first letter, no trailing period, 5-72 chars
- **body**: optional, encourage feat/fix

## Steps

1. Copy `scripts/conventional-commits-check.sh` + `scripts/_hook-lib.sh` -> `.claude/hooks/`. `chmod +x`.
2. Add to `.claude/settings.json`: PreToolUse (Bash): `.claude/hooks/conventional-commits-check.sh`
3. Optional: `codex-compat` for Codex `.codex/hooks.json`

## Verify
- [ ] Block: `git commit -m "bad message"`, `git commit -m "feat: missing scope"`, `git commit -m "feat(ui): A"` (uppercase)
- [ ] Allow: `git commit -m "feat(ui): add button component"`
- [ ] Ignore non-commit Bash commands