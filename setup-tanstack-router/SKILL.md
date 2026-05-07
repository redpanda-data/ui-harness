---
name: setup-tanstack-router
description: Auto-generate TanStack Router route tree and enforce router patterns via PostToolUse hooks. Bans react-router-dom, window.location, untyped hooks. Use when setting up TanStack Router or file-based routing.
paths:
  - "**/routes/**/*.tsx"
  - "**/routes/**/*.ts"
---

# TanStack Router Enforcement

## What This Catches

- Ban `react-router-dom` imports
- Ban `window.location` navigation (block) + reads (warn)
- Warn `window.location.reload()` -- suggest `router.invalidate()`
- Ban `strict: false` in router hooks
- Ban untyped `useParams()`/`useSearch()`/`useLoaderData()`/`useRouteContext()` missing `{ from }`
- Ban `URLSearchParams` -- suggest nuqs
- Warn exported components from route files (break code splitting)
- Require `validateSearch` when `useSearch` in route files

Auto-regen route tree on route file change.

## Customization

Routes dir pattern default `/routes/`. Update grep pattern in hook scripts if project use different convention:

```bash
if ! echo "$file_path" | grep -qE '/routes/'; then    # default
if ! echo "$file_path" | grep -qE '/pages/'; then     # pages-based
if ! echo "$file_path" | grep -qE '/app/routes/'; then # nested
```

## Type-Safe Search Params with nuqs

```tsx
import { useQueryState, parseAsInteger, parseAsString } from 'nuqs'

function UsersPage() {
  const [page, setPage] = useQueryState('page', parseAsInteger.withDefault(1))
  const [filter, setFilter] = useQueryState('filter', parseAsString)
}
```

Setup (install, config, verify): see [SETUP.md](SETUP.md).