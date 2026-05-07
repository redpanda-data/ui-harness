#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Check: function defined that already exists elsewhere ────────
# Scan for new function/const definitions and check if the same
# name exists in other files in the same directory tree.
# Catches the "This function appears twice" pattern.

# Extract new function/const names from added lines
new_funcs=$(echo "$added_lines" | grep -oE '(export\s+)?(function|const)\s+([a-zA-Z_][a-zA-Z0-9_]*)' | awk '{print $NF}' | sort -u || true)

if [ -z "$new_funcs" ]; then
  exit 0
fi

# Get the src root (walk up to find src/ or use repo root)
_src_dir=$(dirname "$file_path")
_repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Only check functions that are likely utilities (lowercase start, >10 chars)
_duplicates=""
while IFS= read -r func_name; do
  [ -z "$func_name" ] && continue
  # Skip short names, React components (PascalCase), hooks (use*)
  case "$func_name" in
    use*|[A-Z]*) continue ;;
  esac
  [ ${#func_name} -lt 8 ] && continue

  # Search for same function name in other files (limit scope to avoid slowness)
  _matches=$(git grep -l "function $func_name\|const $func_name" -- '*.ts' '*.tsx' 2>/dev/null | grep -v "$(basename "$file_path")" | head -3 || true)

  if [ -n "$_matches" ]; then
    _first_match=$(echo "$_matches" | head -1)
    _duplicates="${_duplicates}\n  ${func_name} also in $(basename "$_first_match")"
  fi
done <<< "$new_funcs"

if [ -n "$_duplicates" ]; then
  # Session-scoped: only warn once
  _marker="$_hook_session_dir/duplicate-func-reminded"
  if [ ! -f "$_marker" ]; then
    touch "$_marker"
    hook_warn "Possible duplicate functions:${_duplicates}\nConsider extracting to shared utils." "duplicate-function"
  fi
fi

exit 0
