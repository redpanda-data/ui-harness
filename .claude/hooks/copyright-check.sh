#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests

# ── Only fire on NEW files (not in HEAD) ─────────────────────────
if git show HEAD:"$file_path" &>/dev/null 2>&1; then
  exit 0  # Existing file, skip
fi

# ── Check: copyright header in first 5 lines ────────────────────
_year=$(date +%Y)
if ! head -5 "$file_path" | grep -qiE 'copyright|license'; then
  # Session-scoped: remind once
  _marker="$_hook_session_dir/copyright-reminded"
  if [ ! -f "$_marker" ]; then
    touch "$_marker"
    hook_warn "New file missing copyright header. Add: // Copyright ${_year} Redpanda Data, Inc." "copyright-header"
  fi
fi

exit 0
