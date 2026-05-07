#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Check 1: refetchQueries → invalidateQueries ─────────────────
# invalidateQueries marks cache stale; refetchQueries forces immediate refetch.
# Prefer invalidation — let React Query decide when to refetch.

if echo "$added_lines" | grep -qE '\.refetchQueries\('; then
  if ! hook_has_escape "refetch-queries"; then
    hook_warn "Prefer invalidateQueries() over refetchQueries(). Invalidation lets React Query decide optimal refetch timing. Escape: // allow: refetch-queries [reason]" "query-pattern-refetch"
  fi
fi

# ── Check 2: invalidateQueries without await ─────────────────────
# Cache invalidation is async — must be awaited or UI shows stale data.

no_await=$(echo "$added_lines" | grep -E 'invalidateQueries\(' | grep -vE 'await' || true)
if [ -n "$no_await" ]; then
  if ! hook_has_escape "await-invalidate"; then
    hook_warn "Always await invalidateQueries() — without await, subsequent code may see stale cache. Escape: // allow: await-invalidate [reason]" "query-pattern-await"
  fi
fi

exit 0
