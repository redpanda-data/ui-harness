#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Check 1: Hard block `as never` / `as any` ───────────────────
# These suppress TypeScript entirely. Fix types properly.

if echo "$added_lines" | grep -qE '\bas\s+never\b'; then
  hook_block "No 'as never' casts. Fix the underlying type mismatch — use type guards, generics, or discriminated unions."
fi

if echo "$added_lines" | grep -qE '\bas\s+any\b'; then
  hook_block "No 'as any' casts. Fix types properly — type guards, generics, schema validation."
fi

if echo "$added_lines" | grep -qE '\bas\s+Record<string,\s*(any|unknown)>'; then
  hook_block "No 'as Record<string, any/unknown>'. Use concrete interface or type guard."
fi

if echo "$added_lines" | grep -qF '@ts-ignore'; then
  hook_block "@ts-ignore banned. Fix type error directly."
fi

if echo "$added_lines" | grep -qF '@ts-expect-error'; then
  hook_block "@ts-expect-error banned. Fix underlying type error."
fi

# ── Check 2: Warn on `as TypeName` casts in .tsx ─────────────────
# Prefer type guards (isServerlessCluster(x)) over casts (x as Cluster).
# Allow: 'as const', 'as string', 'as number', 'as boolean' (primitives).

as_casts=$(echo "$added_lines" | grep -E '\bas\s+[A-Z][A-Za-z]+' | grep -vE '\bas\s+const\b|\bas\s+unknown\b|\bas\s+React\.' || true)

if [ -n "$as_casts" ]; then
  _count=$(echo "$as_casts" | wc -l | tr -d '[:space:]')
  if [ "${_count:-0}" -gt 2 ]; then
    if ! hook_has_escape "as-cast"; then
      sample=$(echo "$as_casts" | head -2 | sed 's/^+//' | tr '\n' ' ')
      hook_warn "${_count} type casts with 'as'. Prefer type guards for safety. Found: $sample. Escape: // allow: as-cast [reason]" "as-cast"
    fi
  fi
fi

exit 0
