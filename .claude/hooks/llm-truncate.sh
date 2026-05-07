#!/bin/bash
# PostToolUse Bash: cap tool-result output size before it enters Claude's context.
#
# Previous version capped at 200 lines. Now caps at bytes (more precise) and
# writes full output to /tmp/bash-<sha>.log so Claude can re-read on demand.
#
# Cap threshold: LLM_TRUNCATE_BYTES (default 4096).
# Keep-head and keep-tail: LLM_TRUNCATE_HEAD (80), LLM_TRUNCATE_TAIL (120).

set -euo pipefail
trap 'exit 0' ERR

# Source hook-lib for _hook_log_bash_drain. Optional — silently skip if missing.
source "$(dirname "$0")/source-hook-lib.sh" 2>/dev/null || true

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

result=$(echo "$input" | jq -r '.tool_result // empty')

if [ -z "$result" ]; then
  exit 0
fi

cap_bytes="${LLM_TRUNCATE_BYTES:-4096}"
head_lines="${LLM_TRUNCATE_HEAD:-80}"
tail_lines="${LLM_TRUNCATE_TAIL:-120}"

result_bytes=${#result}

if [ "$result_bytes" -le "$cap_bytes" ]; then
  exit 0
fi

# Record cap-hit for drain measurement. Command snippet helps attribution.
cmd_for_log=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
bytes_truncated=$((result_bytes - cap_bytes))
if command -v _hook_log_bash_drain >/dev/null 2>&1; then
  _hook_log_bash_drain "cap_hit" "$cmd_for_log" "$bytes_truncated"
fi

# Stash full output so Claude can re-read if needed
log_dir="/tmp/claude-bash-logs"
mkdir -p "$log_dir" 2>/dev/null || true
sha=$(printf '%s' "$result" | cksum | awk '{print $1}')
log_path="$log_dir/bash-${sha}.log"
printf '%s' "$result" > "$log_path" 2>/dev/null || true

# Build truncated view
line_count=$(printf '%s' "$result" | wc -l | tr -d ' ')
head_block=$(printf '%s' "$result" | head -n "$head_lines")
tail_block=$(printf '%s' "$result" | tail -n "$tail_lines")
truncated_lines=$((line_count - head_lines - tail_lines))
if [ "$truncated_lines" -lt 0 ]; then truncated_lines=0; fi

summary=$(printf '%s\n\n... [%d lines / %d bytes truncated -- full: %s] ...\n\n%s' \
  "$head_block" "$truncated_lines" "$((result_bytes - cap_bytes))" "$log_path" "$tail_block")

escaped=$(printf '%s' "$summary" | jq -Rs . 2>/dev/null) || exit 0
echo "{\"suppressOutput\":true,\"systemMessage\":$escaped}"
exit 0
