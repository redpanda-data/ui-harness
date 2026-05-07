#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Check 1: Use ConnectError.from() in ConnectRPC files ─────────
# In files that import from @connectrpc/, throw new Error() loses
# gRPC status codes. Use ConnectError.from() for consistency.

file_content=$(cat "$file_path")

# Gate: file uses connectrpc OR is in a project that does (sibling files import it)
_uses_connect=false
if echo "$file_content" | grep -qE "from\s+['\"]@connectrpc/"; then
  _uses_connect=true
elif echo "$file_path" | grep -qE '/(routes|hooks|components)/'; then
  # Check if project uses connectrpc (nearest package.json or sibling imports)
  _dir=$(dirname "$file_path")
  while [ "$_dir" != "/" ]; do
    if [ -f "$_dir/package.json" ] && grep -q '@connectrpc' "$_dir/package.json" 2>/dev/null; then
      _uses_connect=true
      break
    fi
    _dir=$(dirname "$_dir")
  done
fi

if [ "$_uses_connect" = true ]; then
  if echo "$added_lines" | grep -qE 'throw\s+new\s+Error\('; then
    # Flag if near fetch/RPC context — queryFn, mutationFn, loader, fetch handler
    if echo "$file_content" | grep -qE 'queryFn|mutationFn|loader|\.fetch\(|callUnaryMethod'; then
      if ! hook_has_escape "connect-error"; then
        hook_warn "Use ConnectError.from() not throw new Error() in data-fetching code. Preserves gRPC status codes for consistent error handling. Escape: // allow: connect-error [reason]"
      fi
    fi
  fi
fi

exit 0
