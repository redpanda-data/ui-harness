#!/bin/bash
set -euo pipefail

# PreToolUse WebFetch: detect duplicate fetches within the same session.
# 30d audit data:
#   https://code.claude.com/docs/en/claude_code_docs_map.md → fetched 20x
#   https://code.claude.com/docs/en/skills.md               → 5x (0.14M chars wasted)
#   https://code.claude.com/docs/en/hooks.md                → 7x
#   TOTAL dup waste: 0.56M chars / month
#
# Strategy: session-scoped cache. On 2nd+ fetch of same URL+prompt, emit
# a nudge (additionalContext) reminding the model the content is already
# in this conversation. Escalate message on 3rd+ dup. Don't deny — the
# model may truly need a refresh (docs changed), but should think twice.

_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else exit 0; fi

_in=$(cat)
tool_name=$(echo "$_in" | jq -r '.tool_name // empty' 2>/dev/null || true)

if [ "$tool_name" != "WebFetch" ]; then
  exit 0
fi

url=$(echo "$_in" | jq -r '.tool_input.url // empty' 2>/dev/null || true)
prompt=$(echo "$_in" | jq -r '.tool_input.prompt // empty' 2>/dev/null || true)

[ -z "$url" ] && exit 0

# Hash url+prompt (same URL with different prompts = valid, not a dup)
if command -v md5 >/dev/null 2>&1; then
  hash=$(printf '%s|%s' "$url" "$prompt" | md5 | awk '{print $NF}')
elif command -v md5sum >/dev/null 2>&1; then
  hash=$(printf '%s|%s' "$url" "$prompt" | md5sum | cut -d' ' -f1)
else
  exit 0
fi

cache_file="$_hook_session_dir/webfetch-seen"
mkdir -p "$_hook_session_dir" 2>/dev/null || true
touch "$cache_file" 2>/dev/null || true

# Count prior occurrences of this hash this session.
# grep -c emits its own "0" and exits 1 on no-match; filtering via awk
# avoids the double-zero bug from "|| echo 0" concatenation.
count=$(awk -v h="$hash" '$1==h {n++} END {print n+0}' "$cache_file" 2>/dev/null || printf 0)
count=${count:-0}

# Record this attempt regardless
printf '%s %s %s\n' "$hash" "$(date +%s)" "$url" >> "$cache_file" 2>/dev/null || true

if [ "$count" -eq 0 ]; then
  # First fetch — silent pass
  exit 0
fi

short_url=$(printf '%s' "$url" | cut -c1-70)

if [ "$count" -eq 1 ]; then
  msg="[webfetch-dedup] This URL already fetched once this session (${short_url}). Content is in conversation context -- scroll up rather than re-fetch unless you expect the page changed."
else
  msg="[webfetch-dedup] This URL fetched ${count}x already this session (${short_url}). STRONG sign of a loop or lost context. Re-read your prior tool_result instead of re-fetching. If you truly need a refresh, note WHY in your next message."
fi

_hook_log_entry "nudge" "webfetch-dedup" 2>/dev/null || true
printf '%s' "$msg" | jq -Rs '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:.}}' >&2

exit 0
