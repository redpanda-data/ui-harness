#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_get_added_lines

# ── Check 1: Ban custom hook definitions in route files ──────────
# Custom hooks (function use*) must live in /hooks/ directory,
# not inline in route files.
# Detect route files by path OR content (supports any directory structure).

is_route=false
if echo "$file_path" | grep -qE '/routes/'; then
  is_route=true
elif grep -qE 'createFileRoute|createRoute|createLazyRoute' "$file_path" 2>/dev/null; then
  is_route=true
fi

if [ "$is_route" = true ]; then
  if echo "$added_lines" | grep -qE '^\+?(export\s+)?(function\s+use[A-Z]|const\s+use[A-Z]\w*\s*=)'; then
    if ! hook_has_escape "inline-hook"; then
      hook_warn "Custom hook defined in route file. Move to /hooks/ directory. Escape: // allow: inline-hook [reason]"
    fi
  fi
fi

exit 0
