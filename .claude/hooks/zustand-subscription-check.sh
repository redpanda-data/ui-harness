#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Check: direct api.* property reads in components ─────────────
# Reading from zustand proxy object (api.someProperty) without
# useStore hook means component won't rerender on state changes.
# Must use useApiStore(state => state.someProperty) or similar.

file_content=$(cat "$file_path")

# Only fire if file is a React component (has JSX return or React import)
if ! echo "$file_content" | grep -qE "from\s+['\"]react['\"]|return\s*\(?\s*<"; then
  exit 0
fi

# Detect api.someProperty reads (but not api function calls like api.fetch())
# Pattern: api.camelCase (property) vs api.camelCase( (function call)
api_reads=$(echo "$added_lines" | grep -oE '\bapi\.[a-z][a-zA-Z]+\b' | grep -vE '\bapi\.(get|set|fetch|post|put|delete|patch|create|update|remove|list|call)\b' || true)

if [ -n "$api_reads" ]; then
  # Check if file imports a store hook for this
  if ! echo "$file_content" | grep -qE 'useApiStore|useStore.*api|useAppStore'; then
    sample=$(echo "$api_reads" | head -3 | tr '\n' ', ' | sed 's/,$//')
    if ! hook_has_escape "zustand-subscription"; then
      hook_warn "Direct api.* property read ($sample) without store subscription. Component won't rerender on changes. Use useApiStore(state => state.property). Escape: // allow: zustand-subscription [reason]" "zustand-api-subscription"
    fi
  fi
fi

exit 0
