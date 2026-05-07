---
name: setup-react-compiler
description: Install React Compiler with rsbuild and enforce compiler-friendly patterns via PostToolUse hooks. Flags manual memoization, derived state, useRef cache. Use when setting up React Compiler or post-compiler patterns.
---

# Setup React Compiler

## What This Sets Up

- **babel-plugin-react-compiler** with rsbuild
- PostToolUse hook flags: `useMemo`/`useCallback`/`React.memo` (compiler handle), derived-state-via-useEffect, `useRef` as memo cache
- `'use no memo'` escape hatch + auto-skip component library dirs
- Annotation mode (`REACT_COMPILER_MODE=annotation`) for brownfield: flag only files with `"use memo"`

See [REFERENCE.md](REFERENCE.md) for post-compiler rules.

## Steps

### 1. Install
```bash
bun add -D babel-plugin-react-compiler @rsbuild/plugin-babel --yarn
```

### 2. Configure rsbuild
```ts
import { pluginBabel } from '@rsbuild/plugin-babel';
export default {
  plugins: [
    pluginBabel({
      babelLoaderOptions: {
        plugins: [['babel-plugin-react-compiler', {
          compilationMode: 'annotation', // 'infer' for greenfield
        }]],
      },
    }),
  ],
};
```

Brownfield: set `REACT_COMPILER_MODE=annotation` in session-env.sh.

### 3. Component library
Add `'use no memo'` to all `.tsx` in component library dir.

### 4. Hook
Copy `scripts/react-compiler-check.sh` + `scripts/_hook-lib.sh` -> `.claude/hooks/`. `chmod +x`. Add to PostToolUse (Edit|Write).

### 5. Verify
- [ ] rsbuild config has babel plugin
- [ ] Hook executable + configured
- [ ] Component library files have `'use no memo'`