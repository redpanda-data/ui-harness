# Project Rules

This project enforces strict code organization and data mutation patterns:

## File organization
- **Custom hooks (`function use*`) must live in `src/hooks/` directory**, never inline in route files.
- Route files in `src/routes/` should contain ONLY route configuration and the page component.
- Route files should stay under 300 lines. If they grow larger, split into smaller components.

## Data mutations
- **Side-effect operations (POST, PUT, DELETE, PATCH) must use `useMutation`** from TanStack Query or Connect Query.
- Never use raw `fetch()` with `method: 'DELETE'` or `method: 'POST'` inside event handlers — wrap in a `useMutation` hook.
- Each mutation deserves its own custom hook in `src/hooks/`.

## Error handling
- In files using ConnectRPC (`@connectrpc/*`), use `ConnectError.from()` for error wrapping, not `throw new Error()`.
- **Route files with `loader` must have `errorComponent`** for graceful error handling.

## Data updates
- When using `FieldMask` for update operations, compute `paths` dynamically from dirty fields instead of hardcoding them. Example: `paths: Object.keys(form.formState.dirtyFields).map(camelToSnake)`.

## Forms
- Form validation mode must be `onChange` for immediate feedback. Never use `onBlur` or `onSubmit`.

## Package manager
- Use bun with `--yarn` flag.

# Task

Create the following files for a "Connections" page that shows OAuth provider connections:

## 1. `src/hooks/use-connections.ts`
A custom hook that:
1. Fetches connection status from `/api/connections` using `useQuery`
2. Exports a `useDisconnect` mutation hook that sends a DELETE request to `/api/connections/:name`
3. Uses `useMutation` for the disconnect operation (NOT raw fetch in a handler)
4. Returns `{ connections, isLoading, error, disconnect, isDisconnecting }`

## 2. `src/routes/connections.tsx`
A route component that:
1. Uses `createFileRoute` from `@tanstack/react-router`
2. Has a `loader` that prefetches connections data via `queryClient.ensureQueryData`
3. Has an `errorComponent` for graceful error handling (required for routes with loaders)
4. Imports and uses the hooks from `src/hooks/use-connections.ts` (does NOT define hooks inline)
5. Shows a grid of connection cards
6. Has "Connect" and "Disconnect" buttons using `<Button>` from `@/components/ui/button`
7. Uses the `disconnect` mutation from the hook (NOT raw fetch in onClick handler)
8. Has a form for filtering connections — must use `mode: 'onChange'`
9. Stays under 300 lines
