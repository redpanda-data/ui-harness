---
name: setup-registry-workflow
description: Registry hooks + component taxonomy + consumer drift analysis. Use when maintain shadcn component registry, design system, or analyze drift between consumer repos + registry.
---

# Setup Registry Workflow

## Hooks

- **PostToolUse** (`ui-registry-warn.sh`): warn once/session when edit UI component dirs | prompt upstream PR
- **Stop** (`registry-check.sh`): block if redpanda-ui modified without update `registry.json` + add changeset

## Component Taxonomy (Atomic Design)

Classify every registry component one level. Drive test depth.

| Level | useState | Registry imports | Custom kbd handlers | Portal | Test count |
|-------|----------|-----------------|-------------------|--------|------------|
| **Atom** | 0-1 | 0 | 0 | No | 3-4 |
| **Molecule** | 2 | 1-2 | 1-10 lines | Maybe | 5-8 |
| **Organism** | 3+ | 3+ | 10+ lines | Often | 8-15 |

Tiebreaker: highest-scoring signal win. Radix-provided kbd nav no count.

**Atom**: Single-responsibility primitives | one semantic HTML element/Radix primitive | zero or one controlled/uncontrolled toggle.
Examples: Button, Badge, Input, Label, Separator, Spinner, Skeleton, Checkbox, Switch

**Molecule**: Combine 2-3 atoms | limited local state (open/closed, selected index) | simple portals.
Examples: CopyButton, InputGroup, ButtonGroup, Field, Accordion, Breadcrumb, Card, Tabs

**Organism**: Multiple molecules+atoms | significant state (3+ vars or useReducer) | custom kbd nav | portal rendering.
Examples: Combobox, MultiSelect, DataTable, Dialog, DropdownMenu, Sheet, Sidebar, AutoForm

Component evolve between levels -> verify heuristics | expand tests new minimum | review FP compliance.

## Consumer Drift Analysis

Compare consumer repo components against registry source. Run on upstream sync.

### Process

1. **Discovery** -- scan `packages/registry/src/components/` | match against consumer dirs
2. **Comparison** -- `git diff --no-index --ignore-all-space` per component | skip empty diffs
3. **Filtering** -- apply rules below each non-empty diff
4. **Categorization** -- assign one status per component

### Filter Rules

| Rule | Detect | Action |
|------|--------|--------|
| **Import noise** | Only `@/`->`../` path changes, `'use client'` directives, biome comments | **Skip-Import-Only** |
| **Staleness** | Registry changelog newer than consumer file | **Skip-Outdated** -- consumer sync FROM registry |
| **Business logic** | String equality (`=== 'admin'`), feature flags, API endpoints, route logic, analytics, env checks | **Skip-Business-Logic** -- never upstream app-specific code |

### Business Logic Red Flags

| Pattern | Example |
|---------|---------|
| String equality checks | `title === 'Users'` |
| Hard-coded business data | `tier === 'enterprise'` |
| Feature flags | `featureFlagEnabled` |
| API endpoints | `fetch('/api/console/users')` |
| Route-specific logic | `pathname.includes('/dashboard')` |
| Analytics/tracking | `analytics.track(...)` |

Safe: prop-based logic (`variant === 'destructive'`, `size === 'lg'`).

### Output Statuses

| Status | Meaning |
|--------|---------|
| **Upstream** | Real functional diff, safe merge into registry |
| **Skip-Import-Only** | Only import path/directive noise |
| **Skip-Outdated** | Registry newer -- consumer pull, not push |
| **Skip-Business-Logic** | App-specific logic -- re-implement cleanly if needed |

## Steps

1. Copy `scripts/ui-registry-warn.sh` + `scripts/registry-check.sh` -> `.claude/hooks/` | `chmod +x`
2. Configure `.claude/settings.json`:
   - PostToolUse (Edit|Write): `ui-registry-warn.sh`
   - Stop: `registry-check.sh`

## Verify
- [ ] Both hooks executable
- [ ] Edit `components/ui/` or `redpanda-ui/` trigger warning
- [ ] Modify `redpanda-ui/` without `registry.json` update -> Stop block
- [ ] Modify `redpanda-ui/` with `registry.json` but no changeset -> Stop block