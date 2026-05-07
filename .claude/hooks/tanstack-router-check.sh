#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_get_added_lines

# ── Check 1: Ban react-router-dom imports ─────────────────────────────

if echo "$added_lines" | grep -qE "from\s+['\"]react-router-dom['\"/]"; then
  hook_block "react-router-dom banned. Use TanStack Router: useNavigate, useParams({from}), useSearch(validateSearch), <Link>."
fi

# ── Check 2: Ban window.location for navigation ──────────────────────

if echo "$added_lines" | grep -qE 'window\.location\.(href|assign|replace)\s*[=(]'; then
  hook_block "No window.location nav (full reload). Use navigate({to}) or <Link> from @tanstack/react-router."
fi

# ── Check 2b: Ban navigate(-1) / history.back() ─────────────────────

if echo "$added_lines" | grep -qE 'navigate\(\s*-1\s*\)|history\.back\(\)|history\.go\(\s*-'; then
  hook_warn "navigate(-1) can exit app if no history. Use explicit route path."
fi

# ── Check 3: Ban URLSearchParams in client code ──────────────────────

if echo "$added_lines" | grep -qE '\bnew URLSearchParams\b|searchParams\.(get|set|append)\b'; then
  _is_client_file=false
  if echo "$file_path" | grep -qE '/(routes|components|pages|hooks|stores)/'; then
    _is_client_file=true
  fi
  file_content="${file_content:-$(cat "$file_path" 2>/dev/null || true)}"
  if echo "$file_content" | grep -qE "@tanstack/react-router|from ['\"]react"; then
    _is_client_file=true
  fi
  if [ "$_is_client_file" = true ]; then
    hook_block "No URLSearchParams in client code. Use TanStack Router validateSearch+zod or nuqs."
  fi
fi

# ── Check 4: Warn on window.location.reload() ────────────────────────

if echo "$added_lines" | grep -qE '(window\.)?location\.reload\(\)'; then
  hook_warn "No hard reloads (blank flash, loses state). Use router.invalidate() or queryClient.invalidateQueries()."
fi

# ── Check 5: Warn on window.location reads ────────────────────────────

if echo "$added_lines" | grep -qE 'window\.location\.(search|pathname|hash|origin)\b'; then
  hook_warn "No window.location reads. Use useParams({from}) or useSearch({from}) for type-safe access. For origin, use router basePath or env config."
fi

# ── Check 5b: Catch bare location.href (without window. prefix) ──────

bare_location=$(echo "$added_lines" | grep -E '\blocation\.(href|assign|replace|reload)\b' | grep -vE 'window\.location' || true)
if [ -n "$bare_location" ]; then
  hook_warn "Bare location.href detected. Use TanStack Router navigate({to}) or <Link>. For external redirects, use window.open() sparingly with user confirmation."
fi

# ── Check 5c: Warn on window.open() for OAuth/redirect flows ─────────

if echo "$added_lines" | grep -qE 'window\.open\('; then
  hook_warn "window.open() detected. For OAuth redirects, prefer server-side redirect or TanStack Router navigate. If needed, document why in comment."
fi

# ── Check 6: Ban strict: false in router hook calls ───────────────────

if echo "$added_lines" | grep -qE 'strict:\s*false'; then
  file_content=$(cat "$file_path")
  if echo "$file_content" | grep -qE "from\s+['\"]@tanstack/react-router"; then
    hook_block "No strict:false. Use { from: '/route/\$param' } for typed params."
  fi
fi

# ── Check 7: Ban empty-args useParams/useSearch/useLoaderData/useRouteContext ─

if echo "$added_lines" | grep -qE '\b(useParams|useSearch|useLoaderData|useRouteContext)\(\s*\)'; then
  if ! echo "$added_lines" | grep -qE 'Route\.(useParams|useSearch|useLoaderData|useRouteContext)\(\s*\)'; then
    file_content=$(cat "$file_path")
    if echo "$file_content" | grep -qE "from\s+['\"]@tanstack/react-router"; then
      match=$(echo "$added_lines" | grep -oE '\b(useParams|useSearch|useLoaderData|useRouteContext)\(\s*\)' | head -1)
      hook_block "$match needs { from: '/route/\$param' } for type safety. Or use Route.$match."
    fi
  fi
fi

# ── Check 8: Warn on exported components from route files ──────────────

if echo "$file_path" | grep -qE '/routes/'; then
  non_route_exports=$(echo "$added_lines" | grep -E 'export\s+(function|const)\s+[A-Z]' | grep -v 'export\s*const\s*Route\b' || true)
  if [ -n "$non_route_exports" ]; then
    hook_warn "No component exports from route files (breaks code splitting). Move to separate files."
  fi
fi

# ── Check 9: Missing validateSearch when useSearch is used ────────────

if echo "$added_lines" | grep -qE '\buseSearch\b'; then
  if echo "$file_path" | grep -qE '/routes/'; then
    file_content=$(cat "$file_path")
    if ! echo "$file_content" | grep -qF 'validateSearch'; then
      hook_block "useSearch requires validateSearch on route. Add zod schema: validateSearch: z.object({...})."
    fi
  fi
fi

exit 0
