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
- Warn when Query-primed loaders are consumed via `useLoaderData` instead of `useQuery`/`useSuspenseQuery`
- Warn when router uses `queryClient` context without `defaultPreloadStaleTime: 0`
- Warn when router uses `queryClient` context without `createRootRouteWithContext`

Auto-regen route tree on route file change.

## TanStack Router + Query

When a route needs server data, prefer this ownership split:

- **Router loader**: start fetching early after navigation intent.
- **TanStack Query**: own cache, refetch, invalidation, and garbage collection.
- **Component**: read via `useQuery()` or `useSuspenseQuery()` so Query has an active observer.

Do **not** enforce suspense globally. Choose per field/page:

- `useSuspenseQuery()` for blocking, page-critical data that should use route pending/error boundaries.
- `useQuery()` for deferred or secondary data with inline loading/empty/error states.

```tsx
export const Route = createFileRoute('/dashboards/$dashboardId')({
  loader: ({ context, params }) => {
    context.queryClient.prefetchQuery(dashboardQueryOptions(params.dashboardId))
  },
  component: Dashboard,
})

function Dashboard() {
  const params = Route.useParams()
  const dashboard = useSuspenseQuery(dashboardQueryOptions(params.dashboardId))
  const widgetCount = useQuery(widgetCountQueryOptions(params.dashboardId))

  return <DashboardView dashboard={dashboard.data} widgetCount={widgetCount.data} />
}
```

Router setup when Query owns cache:

```tsx
const rootRoute = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  component: RootLayout,
})

const router = createRouter({
  routeTree,
  context: { queryClient },
  defaultPreloadStaleTime: 0,
  defaultPendingComponent: DefaultLoader,
  defaultErrorComponent: DefaultError,
})
```

Avoid `Route.useLoaderData()` for Query-loaded data. It bypasses Query observers, so focus refetch, invalidation refetch, and cache retention can behave surprisingly.

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