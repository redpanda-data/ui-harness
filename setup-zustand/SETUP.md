# Zustand Setup

## Steps

### 1. Create hook script

Copy [`scripts/zustand-check.sh`](scripts/zustand-check.sh) and [`scripts/_hook-lib.sh`](scripts/_hook-lib.sh) into `.claude/hooks/`. Make executable.

### 2. Configure hook in `.claude/settings.json`

Add to hooks config: **PostToolUse** (matcher: `Edit|Write`): `.claude/hooks/zustand-check.sh`

### 3. Verify

- [ ] Hook blocks `create<State>()` single-parens in files importing zustand
- [ ] Hook blocks `(s) => ({ ... })` inline object selectors
- [ ] Hook blocks `localStorage` in zustand store files
- [ ] Hook skips non-TS/TSX files
- [ ] Hook skips files that don't import zustand (for checks 1 and 3)

### 4. Commit

Stage and commit: `Add zustand best practices enforcement hook`
