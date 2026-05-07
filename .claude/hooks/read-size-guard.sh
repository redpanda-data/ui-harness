#!/bin/bash
set -eo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else exit 0; fi

# PreToolUse Read: nudge before reading huge files without a limit.
# Data: Read returned 52.6% of all tool_result chars; 35 reads >30k chars
# are the fat tail. Default Read is 2000 lines which on wide files = 150k+
# chars = blown context budget. Nudge, don't deny — some files need full read.

_hook_input=$(cat)
tool_name=$(echo "$_hook_input" | jq -r '.tool_name // empty' 2>/dev/null || true)

if [ "$tool_name" != "Read" ]; then
  exit 0
fi

file_path=$(echo "$_hook_input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
limit=$(echo "$_hook_input" | jq -r '.tool_input.limit // empty' 2>/dev/null || true)
offset=$(echo "$_hook_input" | jq -r '.tool_input.offset // empty' 2>/dev/null || true)

# Skip if no path, limit already set, or file missing
[ -z "$file_path" ] && exit 0
[ -n "$limit" ] && exit 0
[ ! -f "$file_path" ] && exit 0

# Skip images/PDFs/notebooks (Read has native handlers, not line-based)
case "$file_path" in
  *.png|*.jpg|*.jpeg|*.gif|*.webp|*.pdf|*.ipynb) exit 0 ;;
esac

# Measure: lines + bytes. Bail if either tool missing.
if ! command -v wc >/dev/null 2>&1; then exit 0; fi
lines=$(wc -l < "$file_path" 2>/dev/null || echo 0)
bytes=$(wc -c < "$file_path" 2>/dev/null || echo 0)

# Thresholds: >800 lines OR >25KB triggers nudge. Jumbos in audit were 30k+.
if [ "$lines" -lt 800 ] && [ "$bytes" -lt 25000 ]; then
  exit 0
fi

nudge="Large file: ${lines} lines, $((bytes / 1024))KB. Reading full = ~$((bytes / 4)) tokens. Prefer: Grep '<pattern>' to locate, then Read with offset+limit. Or Read with limit:200 first."

_hook_log_entry "nudge" "read-size-guard" 2>/dev/null || true
printf '%s' "$nudge" | jq -Rs '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:("[read-size] " + .)}}' >&2
exit 0
