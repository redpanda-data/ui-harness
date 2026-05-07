# React Compiler Reference

## Post-Compiler Mental Model

> "Write React as if every render is free and memoization is automatic."

**Pre-compiler:** manual re-render control, defensive memoization. **Post-compiler:** auto memoization, renders cheap, optimize clarity + correctness.

## Post-React Compiler Coding Rules

1. **Pure function components** -- derive UI from props/state/context. No side effects during render.
2. **Plain JavaScript over hooks** -- `const total = items.reduce(...)` not `useMemo(...)`. Compiler memoizes.
3. **Inline callbacks fine** -- `<Dialog onClose={() => setOpen(false)} />`. No extract to `useCallback`.
4. **Derive, don't store** -- never `useState` + `useEffect` for derived values.
5. **Hooks for semantics** -- `useState` for UI state, `useEffect` for external sync, `useRef` for imperative handles.
6. **No `useRef` as memo cache** -- compiler own caching.
7. **`useMemo`/`useCallback`/`React.memo` = escape hatches** -- only for non-React integration or correctness-critical referential stability. Document why.
8. **Never remove `'use no memo'`** -- last-resort opt-out.
9. **Naming** -- PascalCase components, `use*` hooks (aids compiler inference).

## react-compiler-check.sh

> Script: [`scripts/react-compiler-check.sh`](scripts/react-compiler-check.sh)

## Escape Hatch: 'use no memo'

Compiler break component -> add directive at file top:

```tsx
'use no memo'

export function ProblematicComponent() {
  // Compiler will skip this file
  const value = useMemo(() => expensiveCalc(), [dep])
  return <div>{value}</div>
}
```

Never add/remove directives auto. Document why when adding `'use no memo'`.

## Compiler Modes

| Mode | Behavior | When to use |
|------|----------|-------------|
| `infer` (default) | Heuristic detect components (PascalCase + JSX) and hooks (`use*`) | Most projects |
| `annotation` | Only compile `"use memo"` annotated functions | Incremental adoption |
| `syntax` | Flow-specific component syntax | Rare -- Flow only |
| `all` | Compile all top-level functions | Discouraged |

Assume `infer` unless configured otherwise. Code must work without compiler. Respect existing directives -- trust boundaries, not performance hints.

### Annotation Mode for Legacy Codebases

Opt in file-by-file, skip compile everything.

**Setup:**

```ts
// rsbuild.config.ts (or babel config)
plugins: [
  pluginBabel({
    babelLoaderOptions: {
      plugins: [['babel-plugin-react-compiler', { compilationMode: 'annotation' }]],
    },
  }),
],
```

**Environment variable:**

Set `REACT_COMPILER_MODE=annotation` in SessionStart hook so memoization checks adapt:

```bash
echo "export REACT_COMPILER_MODE=annotation" >> "$CLAUDE_ENV_FILE"
```

**Migration:** Install with `annotation` -> add `"use memo"` per-file while migrate -> remove manual memo in annotated files -> once all annotated, switch to `infer`, remove directives.

**Hook behavior by mode:**

| Mode | File has `"use memo"` | File has `"use no memo"` | No directive | Manual memo flagged? |
|------|----------------------|-------------------------|--------------|---------------------|
| `infer` | N/A (not needed) | Skip -- compiler opted out | Compiled | Yes |
| `annotation` | Compiled | Skip -- compiler opted out | Not compiled | No |

## Component Library Directory

All files in `components/ui/` or `redpanda-ui/` need `'use no memo'` -- registry components need explicit memoization control, consumers may have different compiler settings.

## Post-Compiler Pattern Reference

| Pre-compiler (avoid) | Post-compiler (prefer) |
|---|---|
| `useMemo(() => items.reduce(...), [items])` | `const total = items.reduce(...)` |
| `useCallback(() => setOpen(false), [])` | `() => setOpen(false)` inline |
| `React.memo(Component)` | Plain `function Component()` |
| `useState` + `useEffect` for derived values | Compute inline: `const filtered = items.filter(...)` |
| `useRef` as memoization cache | Plain computation |
| Extract callbacks to variables | Inline in JSX props |
| `useState({a, b, c})` single large object | Multiple `useState` calls |

## When Manual Optimization IS Allowed

Only when: profiling reveal real bottleneck **after** compilation, interfacing with non-React/legacy systems, referential stability for **correctness** (not performance), or precise effect re-execution control beyond compiler inference. Add `'use no memo'` and document why.