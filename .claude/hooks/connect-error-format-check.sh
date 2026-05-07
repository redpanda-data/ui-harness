#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

file_content=$(cat "$file_path")

# ── Gate: only React/hook files with mutation or fetch context ────
is_relevant=false
if echo "$file_content" | grep -qE 'useMutation|mutationFn|mutateAsync|\.mutate\(|onError|catch\s*\('; then
  is_relevant=true
fi
[ "$is_relevant" = false ] && exit 0

# ── Check 1: catch blocks should use ConnectError.from() ─────────
# In projects using ConnectRPC, error formatting should be consistent.

_uses_connect=false
if echo "$file_content" | grep -qE "from\s+['\"]@connectrpc/"; then
  _uses_connect=true
elif echo "$file_path" | grep -qE '/(routes|hooks|components)/'; then
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
  # Check for catch blocks that create new Error instead of ConnectError.from
  if echo "$added_lines" | grep -qE 'catch\s*\('; then
    if echo "$added_lines" | grep -qE 'throw\s+new\s+Error\(|new\s+Error\('; then
      if ! hook_has_escape "connect-error-format"; then
        hook_warn "Use ConnectError.from(error) in catch blocks, not new Error(). Preserves gRPC status codes. Escape: // allow: connect-error-format [reason]" "connect-error-format-throw"
      fi
    fi
  fi

  # Check for toast error without formatToastErrorMessageGRPC
  if echo "$added_lines" | grep -qE 'toast\.(error|warning)\(|showToast\('; then
    if ! echo "$added_lines" | grep -qE 'formatToastErrorMessageGRPC|formatErrorMessage'; then
      if ! hook_has_escape "connect-error-format"; then
        hook_warn "Use formatToastErrorMessageGRPC(ConnectError.from(error)) for toast errors. Consistent gRPC error formatting. Escape: // allow: connect-error-format [reason]" "connect-error-format-toast"
      fi
    fi
  fi
fi

# ── Check 2: mutate/mutateAsync without onError ──────────────────
# Mutations should always handle errors explicitly.

if echo "$added_lines" | grep -qE '\.(mutate|mutateAsync)\s*\('; then
  # Check if onError is defined nearby in the mutation options
  if ! echo "$file_content" | grep -qE 'onError\s*:|onError\s*\('; then
    if ! hook_has_escape "mutation-error"; then
      hook_warn "mutate()/mutateAsync() called but no onError handler found. Add onError to handle failures. Escape: // allow: mutation-error [reason]" "connect-error-format-onerror"
    fi
  fi
fi

exit 0
