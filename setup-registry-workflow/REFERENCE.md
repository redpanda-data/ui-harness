# Registry Workflow Reference

## registry-check.sh

> Script: [`scripts/registry-check.sh`](scripts/registry-check.sh)

## How It Works

Stop hook checks `git diff --name-only HEAD` for `redpanda-ui/` or `src/redpanda-ui/` changes. Modified but `registry.json` not updated -> **blocks**. No `redpanda-ui/` dir -> exit immediately.

## When It Triggers

| Changed files | registry.json updated? | Changeset added? | Result |
|---|---|---|---|
| `redpanda-ui/button.tsx` | Yes | Yes | Pass |
| `redpanda-ui/button.tsx` | Yes | No | **Block** -- add changeset |
| `redpanda-ui/button.tsx` | No | N/A | **Block** -- rebuild registry |
| `src/components/UserTable.tsx` | N/A | N/A | Pass (not registry file) |

## Registry Rebuild Steps

When blocked:

1. Run `bun run build:registry`
2. Add changeset: `bunx changeset` (pick packages, bump type, summary)
3. Let Claude finish turn -- hook re-checks

## Skipping in Non-Registry Repos

Auto-detect: no `redpanda-ui/` or `src/redpanda-ui/` at repo root -> exit 0. No config needed.

## Component Taxonomy

**Atom** -- single element, no composition. Tests (3-4): callbacks, disabled, `data-testid`, `asChild`.

```tsx
export const Button = ({ variant = 'default', size = 'md', ...props }: ButtonProps) => (
  <button className={cn(buttonVariants({ variant, size }))} {...props} />
)
```

**Molecule** -- 2-3 atoms, limited state. Tests (5-8): atom tests + composition, state transitions, edge cases.

```tsx
export function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false)
  // ...
}
```

**Organism** -- many molecules+atoms, big state, keyboard nav, portals. Tests (8-15): molecule tests + keyboard nav, portal open/close, async filter, controlled/uncontrolled.

```tsx
export function Combobox<T>({ options, onChange }: ComboboxProps<T>) {
  const [state, dispatch] = useReducer(comboboxReducer, initialState)
  // keyboard handler, portal rendering, filtering...
}
```

## Consumer Drift Analysis

### Running Drift Analysis

```bash
# Phase 1-2: Discovery + Comparison
mkdir -p .upstreaming/diffs
for component in packages/registry/src/components/*/; do
  name=$(basename "$component")
  consumer_file="<consumer-path>/$name.tsx"
  [ -f "$consumer_file" ] || continue
  git diff --no-index --ignore-all-space \
    "$component/index.tsx" "$consumer_file" \
    > ".upstreaming/diffs/${name}.diff" 2>/dev/null || true
done

# Phase 3: Remove empty diffs
find .upstreaming/diffs -empty -delete
```

### Import Normalization

Ignore: path alias diff (`@/components/button` vs `../components/button`), `'use client'` directives, biome-ignore comments, whitespace. ONLY these diffs -> **Skip-Import-Only**.

### Staleness Detection

Registry version > consumer pinned -> **Skip-Outdated** (sync FROM registry). Same or older -> proceed.

### Business Logic Detection

```tsx
// SAFE -- prop-based (component API)
if (variant === 'destructive') { /* ... */ }

// UNSAFE -- business data (app-specific)
if (status === 'premium') { /* ... */ }
if (pathname.includes('/dashboard')) { /* ... */ }
```

Business logic mixed with legit fix -> **Skip-Business-Logic**. Re-implement fix clean in registry.