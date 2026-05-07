#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests

# ── Check 1: Warn when route files exceed 300 LOC ───────────────
# Large route components should be split. Suggest /request-refactor-plan.
# Detect route files by path OR content (supports any directory structure).

is_route=false
if echo "$file_path" | grep -qE '/routes/'; then
  is_route=true
elif grep -qE 'createFileRoute|createRoute|createLazyRoute' "$file_path" 2>/dev/null; then
  is_route=true
fi

if [ "$is_route" = true ]; then
  loc=$(wc -l < "$file_path" | tr -d ' ')
  if [ "$loc" -gt 300 ]; then
    hook_warn "Route file is ${loc} LOC (limit: 300). Split into smaller components or use /request-refactor-plan."
  fi
fi

exit 0
