---
name: setup-react-rules
description: Enforce React/TS/security rules via PostToolUse hooks -- ban raw HTML, TS escape hatches, XSS vectors, barrel imports, missing passive listeners. Use when enforcing React patterns or component library standards.
---

# Setup React Rules

PostToolUse hooks on Edit/Write (auto-skip component library dirs):

## Enforced Rules

**HTML/Components**: ban raw HTML elements (use `@/components/ui/`), ban inline `style={{}}` (use Tailwind), ban icon inside AlertTitle (use icon prop), require handler on buttons (onClick/asChild/type="submit"/disabled)

**TypeScript**: ban `as any`, `as Record<string,any>`, `@ts-ignore`, `@ts-expect-error`

**Security**: ban `dangerouslySetInnerHTML`, `eval()`, `new Function()`, `.innerHTML =` (XSS/OWASP A03)

**Performance**: ban barrel imports (use direct paths), ban missing `{ passive: true }` on scroll/touch/wheel, ban static import of heavy deps (chart.js/d3/three.js/pdf-lib -- use `React.lazy()`)

**Styling**: ban raw hex/rgb in className (use design tokens), ban `!important`, ban `outline: none` (use focus-visible), ban visual overrides on registry components (use variant prop)

**Navigation**: ban `onClick + navigate()` (use `<Button asChild><Link>`), require `aria-label` on icon-only buttons

**React Compiler**: ban manual `useMemo`/`useCallback`/`React.memo`, ban class components

**Protobuf**: enforce `create()` wrapper for message spreads (v2)

### Opt-in Rules
- `REACT_RULES_BAN_USEEFFECT=1`: ban useEffect/useLayoutEffect/useInsertionEffect. Escape: `// allow: useEffect [reason]`
- `REACT_RULES_BAN_TYPE_ASSERTIONS=1`: ban `as X` (allow `as const`). Force type guards/generics/schema validation.

### Soft Guidance (Claude-enforced, not hooks)
- Named useEffect functions describe purpose. No name without "and"? Split.
- `useSyncExternalStore` for browser API subscriptions (navigator.onLine, matchMedia, scroll)
- Form-level `validate` cross-field validation (react-hook-form v7.72+)

### Functional Programming (Claude-enforced)
- Pure render -- no side effects in component body
- Immutable state -- spread/filter/map, never mutate
- Derive don't sync -- `useMemo` not `useState`+`useEffect`
- `useReducer` for 3+ interrelated `useState`
- Extract data transforms to named pure functions
- Discriminated unions for variant prop types
- Generic `<T>` for reusable typed components

See [REFERENCE.md](REFERENCE.md) for patterns + examples.

## Steps

1. Copy `scripts/react-rules-check.sh` + `scripts/fp-check.sh` + `scripts/tailwind-check.sh` + `scripts/_hook-lib.sh` -> `.claude/hooks/`. `chmod +x`.
2. Add to PostToolUse (Edit|Write) in `.claude/settings.json`.
3. Optional: `codex-compat` for `.codex/hooks.json`.

## Verify
- [ ] Block raw HTML, `as any`, `@ts-ignore` in TSX
- [ ] Auto-skip component library dirs
- [ ] Opt-in rules work when env vars set