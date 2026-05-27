# Evals for setup-tanstack-router skill

GEN_SCRIPT="$REPO_ROOT/setup-tanstack-router/scripts/tanstack-router-gen.sh"
CHECK_SCRIPT="$REPO_ROOT/setup-tanstack-router/scripts/tanstack-router-check.sh"
SKILL_DIR="$REPO_ROOT/setup-tanstack-router"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/SETUP.md" "SETUP.md exists"
run_executable_eval "$GEN_SCRIPT" "tanstack-router-gen.sh is executable"
run_executable_eval "$CHECK_SCRIPT" "tanstack-router-check.sh is executable"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-tanstack-router" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "react-router-dom" "SKILL.md mentions react-router-dom ban"
run_content_eval "$SKILL_DIR/SKILL.md" "validateSearch" "SKILL.md mentions validateSearch"
run_content_eval "$SKILL_DIR/SKILL.md" "nuqs" "SKILL.md mentions nuqs"

# ══════════════════════════════════════════════════════════════════
# Gen script evals
# ══════════════════════════════════════════════════════════════════

# ── Gen: skip non-Edit/Write ──────────────────────────────────────

run_hook_eval "$GEN_SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"echo"}}' \
  0 "gen: skip Bash tool"

# ── Gen: skip non-route files ─────────────────────────────────────

run_hook_eval "$GEN_SCRIPT" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/src/components/Button.tsx"}}' \
  0 "gen: skip non-route file"

run_hook_eval "$GEN_SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/src/utils/helpers.ts"}}' \
  0 "gen: skip utility file"

# ── Gen: skip non-TS/TSX files in routes ──────────────────────────

run_hook_eval "$GEN_SCRIPT" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/src/routes/README.md"}}' \
  0 "gen: skip non-TS file in routes"

# ── Gen: skip empty/missing path ──────────────────────────────────

run_hook_eval "$GEN_SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":""}}' \
  0 "gen: skip empty file_path"

run_hook_eval "$GEN_SCRIPT" \
  '{"tool_name":"Edit","tool_input":{}}' \
  0 "gen: skip no file_path field"

# ── Gen: script content ──────────────────────────────────────────

run_content_eval "$GEN_SCRIPT" "/routes/" "gen: checks for routes directory"
run_content_eval "$GEN_SCRIPT" "bun run generate:routes" "gen: uses package.json script"
run_content_eval "$GEN_SCRIPT" "suppressOutput" "gen: suppresses output"

# ══════════════════════════════════════════════════════════════════
# Check script evals
# ══════════════════════════════════════════════════════════════════

# ── Check: skip non-Edit/Write ────────────────────────────────────

run_hook_eval "$CHECK_SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"echo"}}' \
  0 "check: skip Bash tool"

run_hook_eval "$CHECK_SCRIPT" \
  '{"tool_name":"Read","tool_input":{"file_path":"foo.tsx"}}' \
  0 "check: skip Read tool"

# ── Check: skip non-JS/TS files ──────────────────────────────────

run_hook_eval "$CHECK_SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.go"}}' \
  0 "check: skip .go file"

run_hook_eval "$CHECK_SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.css"}}' \
  0 "check: skip .css file"

# ── Check: skip nonexistent file ─────────────────────────────────

run_hook_eval "$CHECK_SCRIPT" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/nonexistent-router-abc123.tsx"}}' \
  0 "check: skip nonexistent file"

# ── Check 1: Ban react-router-dom imports ─────────────────────────

_rt_tmpdir=$(mktemp -d /tmp/router-evals-XXXXXX)
tmpfile="$_rt_tmpdir/test.tsx"
printf "import { useNavigate } from 'react-router-dom'\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: react-router-dom import" "banned"

# tmpfile reused in tmpdir

# ── Check 2: Ban window.location navigation ──────────────────────

tmpfile="$_rt_tmpdir/test.tsx"
printf "window.location.href = '/dashboard'\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: window.location.href assignment" "full reload"

# tmpfile reused in tmpdir

tmpfile="$_rt_tmpdir/test.tsx"
printf "window.location.assign('/dashboard')\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: window.location.assign()"

# tmpfile reused in tmpdir

# ── Check 3: Warn on window.location.reload() ────────────────────

tmpfile="$_rt_tmpdir/test.tsx"
printf "window.location.reload()\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: window.location.reload() (exit 0)" "blank flash"

# tmpfile reused in tmpdir

# ── Check 4: Warn on window.location reads ───────────────────────

tmpfile="$_rt_tmpdir/test.tsx"
printf "const path = window.location.pathname\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: window.location.pathname (exit 0)" "window.location"

# tmpfile reused in tmpdir

# ── Check 5: Ban strict: false ────────────────────────────────────

tmpfile="$_rt_tmpdir/test.tsx"
printf "import { useParams } from '@tanstack/react-router'\nconst params = useParams({ strict: false })\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: strict: false" "strict"

# tmpfile reused in tmpdir

# ── Check 5: Allow strict: false in non-router files ─────────────

tmpfile="$_rt_tmpdir/test.ts"
printf "const config = { strict: false }\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: strict: false in non-router file"

# tmpfile reused in tmpdir

# ── Check 6: Ban empty-args useParams() ───────────────────────────

tmpfile="$_rt_tmpdir/test.tsx"
printf "import { useParams } from '@tanstack/react-router'\nconst params = useParams()\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: useParams() without args" "from"

# tmpfile reused in tmpdir

# ── Check 6: Allow Route.useParams() ─────────────────────────────

tmpfile="$_rt_tmpdir/test.tsx"
printf "import { useParams } from '@tanstack/react-router'\nconst params = Route.useParams()\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: Route.useParams()"

# tmpfile reused in tmpdir

# ── Check 6: Ban empty-args useSearch() ───────────────────────────

tmpfile="$_rt_tmpdir/test.tsx"
printf "import { useSearch } from '@tanstack/react-router'\nconst search = useSearch()\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: useSearch() without args"

# tmpfile reused in tmpdir

# ── Check 7: Ban URLSearchParams ──────────────────────────────────

# Put in a routes-like path so the client-side detection works
_rt_routes_dir="$_rt_tmpdir/routes"
mkdir -p "$_rt_routes_dir"
tmpfile="$_rt_routes_dir/test.tsx"
printf "import { useSearch } from '@tanstack/react-router'\nconst params = new URLSearchParams(window.location.search)\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: new URLSearchParams in client code" "URLSearchParams"
tmpfile="$_rt_tmpdir/test.tsx"

# tmpfile reused in tmpdir

# ── Check 8: Warn on exported components from route files ────────

tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/src/routes"
tmpfile="$tmpdir/src/routes/users.tsx"
printf "export function UserCard() { return <div /> }\nexport const Route = createFileRoute('/users/')({})\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: exported component from route file (exit 0)" "code splitting"

rm -rf "$tmpdir"

# ── Check 8: Allow export const Route only ───────────────────────

tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/src/routes"
tmpfile="$tmpdir/src/routes/users.tsx"
printf "export const Route = createFileRoute('/users/')({})\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: only Route export from route file"

rm -rf "$tmpdir"

# ── Check 9: Missing validateSearch with useSearch in route ───────

tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/src/routes"
tmpfile="$tmpdir/src/routes/users.tsx"
printf "import { useSearch } from '@tanstack/react-router'\nconst search = useSearch({ from: '/users' })\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: useSearch without validateSearch in route file" "validateSearch"

rm -rf "$tmpdir"

# ── Check 8: Allow useSearch with validateSearch in route ─────────

tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/src/routes"
tmpfile="$tmpdir/src/routes/users.tsx"
printf "import { useSearch } from '@tanstack/react-router'\nimport { z } from 'zod'\nconst Route = createFileRoute('/users/')({ validateSearch: z.object({ page: z.number() }) })\nconst search = useSearch({ from: '/users' })\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: useSearch with validateSearch in route file"

rm -rf "$tmpdir"


# ── Check 10: Warn on Query loader consumed via useLoaderData ─────

tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/src/routes"
tmpfile="$tmpdir/src/routes/dashboard.tsx"
printf "import { createFileRoute } from '@tanstack/react-router'
import { queryOptions, useQuery } from '@tanstack/react-query'
const dashboardQueryOptions = () => queryOptions({ queryKey: ['dashboard'], queryFn: fetchDashboard })
export const Route = createFileRoute('/dashboard')({ loader: ({ context }) => context.queryClient.prefetchQuery(dashboardQueryOptions()), component: Dashboard })
function Dashboard() { const data = Route.useLoaderData(); return <div /> }
" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: Query-primed loader data read via useLoaderData" "active observer"

rm -rf "$tmpdir"

# ── Check 10: Allow Query loader consumed via useQuery ────────────

tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/src/routes"
tmpfile="$tmpdir/src/routes/dashboard.tsx"
printf "import { createFileRoute } from '@tanstack/react-router'
import { queryOptions, useQuery } from '@tanstack/react-query'
const dashboardQueryOptions = () => queryOptions({ queryKey: ['dashboard'], queryFn: fetchDashboard })
export const Route = createFileRoute('/dashboard')({ loader: ({ context }) => context.queryClient.prefetchQuery(dashboardQueryOptions()), component: Dashboard })
function Dashboard() { const result = useQuery(dashboardQueryOptions()); return <div /> }
" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: Query-primed loader consumed via useQuery"

rm -rf "$tmpdir"

# ── Check 11: Warn when router Query cache lacks preload opt-out ─

tmpfile="$_rt_tmpdir/test.tsx"
printf "import { createRouter } from '@tanstack/react-router'
const router = createRouter({ routeTree, context: { queryClient } })
" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: QueryClient router context without defaultPreloadStaleTime 0" "single cache owner"

# ── Check 11: Allow router Query cache with preload opt-out ──────

tmpfile="$_rt_tmpdir/test.tsx"
printf "import { createRouter } from '@tanstack/react-router'
const router = createRouter({ routeTree, context: { queryClient }, defaultPreloadStaleTime: 0 })
" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: QueryClient router context with defaultPreloadStaleTime 0"


# ── Check 12: Warn when QueryClient context lacks typed root context ─

tmpfile="$_rt_tmpdir/root.tsx"
printf "import { createRootRoute } from '@tanstack/react-router'
export const Route = createRootRoute({ component: App })
const router = createRouter({ routeTree, context: { queryClient }, defaultPreloadStaleTime: 0 })
" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: QueryClient router context without createRootRouteWithContext" "createRootRouteWithContext"

# ── Check 12: Allow typed root context with QueryClient ──────────

tmpfile="$_rt_tmpdir/root.tsx"
printf "import { createRootRouteWithContext } from '@tanstack/react-router'
export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({ component: App })
const router = createRouter({ routeTree, context: { queryClient }, defaultPreloadStaleTime: 0 })
" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: QueryClient router context with createRootRouteWithContext"

# ── Check script content ─────────────────────────────────────────

run_content_eval "$CHECK_SCRIPT" "react-router-dom" "check: bans react-router-dom"
run_content_eval "$CHECK_SCRIPT" "window.location" "check: catches window.location"
run_content_eval "$CHECK_SCRIPT" "strict.*false" "check: catches strict: false"
run_content_eval "$CHECK_SCRIPT" "useParams" "check: catches empty useParams"
run_content_eval "$CHECK_SCRIPT" "URLSearchParams" "check: bans URLSearchParams"
run_content_eval "$CHECK_SCRIPT" "validateSearch" "check: requires validateSearch"
run_content_eval "$CHECK_SCRIPT" "code splitting" "check: warns on route file exports"
run_content_eval "$CHECK_SCRIPT" "nuqs" "check: suggests nuqs"
run_content_eval "$CHECK_SCRIPT" "defaultPreloadStaleTime" "check: nudges router preload cache off with Query"
run_content_eval "$CHECK_SCRIPT" "active observer" "check: nudges Query observer over useLoaderData"
run_content_eval "$CHECK_SCRIPT" "createRootRouteWithContext" "check: nudges typed router context"
run_content_eval "$CHECK_SCRIPT" "hook_block|hook_warn" "check: uses shared output functions"

# ── Check 5b: Warn on bare location.href (no window. prefix) ────

tmpfile="$_rt_tmpdir/test.tsx"
printf "location.href = '/dashboard'\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: bare location.href (exit 0)" "location"

# tmpfile reused in tmpdir

# ── Check 5c: Warn on window.open() ─────────────────────────────

tmpfile="$_rt_tmpdir/test.tsx"
printf "window.open(authUrl, '_blank')\n" > "$tmpfile"

run_hook_eval "$CHECK_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: window.open() detected (exit 0)" "window.open"

# tmpfile reused in tmpdir

# ── Check script content (new patterns) ──────────────────────────

run_content_eval "$CHECK_SCRIPT" "Bare location" "check: catches bare location.href"
run_content_eval "$CHECK_SCRIPT" "window\.open" "check: catches window.open"

rm -rf "$_rt_tmpdir"
