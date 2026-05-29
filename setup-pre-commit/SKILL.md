---
name: setup-pre-commit
description: Set up Husky, lint-staged, Prettier, typecheck, and test pre-commit.
---

# Setup Pre-Commit

Sets up Husky + lint-staged + Prettier + optional type/test scripts.

## Steps

1. Detect package manager from lockfile. Default npm if unclear.
2. Install dev deps: `husky lint-staged prettier`.
3. Init Husky (`husky init` using detected package runner).
4. Write `.husky/pre-commit`:

```bash
<pm> lint-staged
<pm> run typecheck   # only if script exists
<pm> run test        # only if script exists
```

5. Create `.lintstagedrc`:

```json
{"*":"prettier --ignore-unknown --write"}
```

6. Create `.prettierrc` only if no Prettier config exists.
7. Verify hook executable, `prepare` script present, lint-staged works.
