---
name: setup-biome
description: Install Biome linter with Ultracite preset, create biome.jsonc config, and configure Claude Code Stop hook for auto-fix before finishing. Use when setting up linting, formatting, Biome, Ultracite, or code quality enforcement.
---

# Setup Biome + Ultracite

- **Biome** linter/formatter + **Ultracite** opinionated preset
- Stop hook auto-fix lint/format on changed JS/TS files (skip `noUnusedImports`, avoid deletion loops)
- Strict: `noConsole`, cognitive complexity 15, `noDeprecatedImports`, restricted imports (moment/lodash/classnames/mobx/yup)

## Steps

### 1. Install
```bash
bun add -D @biomejs/biome ultracite --yarn
```

### 2. Create `biome.jsonc`
From [REFERENCE.md](REFERENCE.md). Extend `ultracite/biome/core` + `ultracite/biome/react`. VCS git on. Test files re-enable `noExplicitAny`.

### 3. Package.json scripts
```json
{
  "scripts": {
    "lint": "biome check .",
    "lint:fix": "biome check --write .",
    "lint:file": "biome check",
    "lint:fix:file": "biome check --write"
  }
}
```

### 4. Hook
Copy `scripts/biome-autofix.sh` -> `.claude/hooks/`. `chmod +x`. Add to Stop.

### 5. Verify
- [ ] `bun run lint` + `bun run lint:fix` work
- [ ] Hook executable + configured