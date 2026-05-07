#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Check: form.watch() should be useWatch() ─────────────────────
# React Compiler needs useWatch for proper rerender tracking.
# form.watch() doesn't trigger component rerenders reliably.

if echo "$added_lines" | grep -qE '\.watch\(\s*['\''"]|form\.watch\(|\.watch\(\)'; then
  file_content=$(cat "$file_path")
  # Only fire if file uses react-hook-form
  if echo "$file_content" | grep -qE "from\s+['\"]react-hook-form['\"]|useForm\(|useFormContext\("; then
    if ! hook_has_escape "form-watch"; then
      hook_block "Use useWatch() instead of form.watch() for React Compiler compatibility. useWatch triggers proper rerenders. Escape: // allow: form-watch [reason]"
    fi
  fi
fi

exit 0
