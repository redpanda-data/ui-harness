#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Check: mutate()/mutateAsync() must include onError callback ──
# Silent mutation failures = data loss risk. Users must see feedback.

# Gate: only check files with mutation usage
file_content=$(cat "$file_path")
if ! echo "$file_content" | grep -qE 'useMutation|mutate\(|mutateAsync\('; then
  exit 0
fi

# Check for mutate/mutateAsync calls in added lines without onError
mutation_calls=$(echo "$added_lines" | grep -E '\b(mutate|mutateAsync)\s*\(' || true)

if [ -n "$mutation_calls" ]; then
  # Check if onError exists anywhere in the mutation setup (file-level check)
  has_onerror=false
  if echo "$file_content" | grep -qE 'onError\s*[:=(\[]'; then
    has_onerror=true
  fi

  if [ "$has_onerror" = false ]; then
    if ! hook_has_escape "mutation-onerror"; then
      hook_block "mutate()/mutateAsync() without onError callback. Add onError to show user feedback on failure. Use ConnectError.from(error) + formatToastErrorMessageGRPC(). Escape: // allow: mutation-onerror [reason]"
    fi
  fi
fi

exit 0
