# Redpanda Frontend Kit Reference

## What This Adds Over frontend-starter-kit

| Addition | What it does |
|---|---|
| Chakra UI ban | Block `@chakra-ui/react` imports |
| Legacy import ban | Block `@redpanda-data/ui` imports |
| `UI_LIB_DIRS` | Set `components/ui\|redpanda-ui` for hook exclusion |
| `REDPANDA_KIT=1` | Enable registry pattern nudges |
| setup-registry-workflow | Stop hook for registry.json rebuild reminders |

## Registry Pattern Nudges (REDPANDA_KIT=1)

`REDPANDA_KIT=1` -> orchestration-guidance add nudges:

| Detected pattern | Nudge |
|---|---|
| `useForm` + ConnectRPC imports | Consider `useProtoForm` for proto-backed forms |
| `<h1>`--`<h6>`, `<p>` raw HTML | Use `Heading`/`Text` from registry |
| Key-value / labels / tags patterns | Consider `KeyValueField` + `BadgeGroup` |

Warn, no block. Surface registry components Claude no know.

## Redpanda-Specific Environment

Set in `.claude/hooks/session-env.sh`:

```bash
echo "export UI_LIB_DIRS=components/ui|redpanda-ui" >> "$CLAUDE_ENV_FILE"
echo "export REDPANDA_KIT=1" >> "$CLAUDE_ENV_FILE"
```

## Component Import Paths

Import from `@/components/redpanda-ui/<name>`. Never `@chakra-ui` or `@redpanda-data/ui`.

## UI Registry Docs

Registry docs: `https://redpanda-ui-registry.netlify.app/docs/<component>`

### Key Patterns

| Pattern | When to use | Registry URL |
|---|---|---|
| `useProtoForm` | Forms backed by ConnectRPC/protobuf schemas | `/docs/use-proto-form` |
| `KeyValueField` + `BadgeGroup` | Editable labels, tags, env vars, HTTP headers | `/docs/patterns/key-value` |
| `Heading` / `Text` | All text -- never raw `<h1>`-`<h6>` or `<p>` | `/docs/components/heading` |
| `DataTable` | Sortable, filterable tabular data | `/docs/components/data-table` |
| `FormFooter` | Consistent submit/cancel button layout | `/docs/components/form-footer` |

## Cross-Repo Visibility (Module Federation)

Symlink remotes so Claude can read:

```bash
mkdir -p linked-repos && echo "linked-repos/" >> .gitignore
ln -s /path/to/remote-app-1/src linked-repos/remote-1
```

Document in `CLAUDE.md`. Claude follow symlinks transparent.

## UI Registry Symlink

```bash
ln -s /path/to/ui-registry linked-repos/ui-registry
```

Modify `@/components/redpanda-ui/` -> also update `linked-repos/ui-registry/`. With `REDPANDA_KIT=1`, orchestration nudge upstream PR.

## Package Source Code (opensrc)

[opensrc](https://github.com/vercel-labs/opensrc) fetch third-party source matching lockfile version:

```bash
npx opensrc zustand
opensrc list
```

## Dependency Changes

Handled by `bundle-guard.sh` (heavy deps) + `orchestration-guidance.sh` (package.json nudge).