#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Check 1: Warn on hardcoded FieldMask paths arrays ────────────
# Static paths arrays in FieldMask can drift when proto schema changes.
# Suggest computing paths dynamically from dirty/changed fields.

if echo "$added_lines" | grep -qE 'FieldMaskSchema|FieldMask|fieldMask|field_mask|updateMask|update_mask'; then
  # Count hardcoded path strings in paths array — match both single/double quotes,
  # across multiple lines (paths: [\n  'x',\n  'y'\n])
  file_content=$(cat "$file_path")
  # Extract the paths array block (up to closing bracket) and count string literals
  path_block=$(echo "$file_content" | sed -n '/paths.*\[/,/\]/p' 2>/dev/null || true)
  path_count=$(echo "$path_block" | grep -oE "['\"][a-z_]+['\"]" 2>/dev/null | wc -l | tr -d '[:space:]')
  path_count=${path_count:-0}

  if [ "$path_count" -gt 2 ]; then
    if ! hook_has_escape "field-mask"; then
      hook_warn "FieldMask with ${path_count} hardcoded paths. Compute from dirty fields: Object.keys(form.formState.dirtyFields). Escape: // allow: field-mask [reason]"
    fi
  fi
fi

exit 0
