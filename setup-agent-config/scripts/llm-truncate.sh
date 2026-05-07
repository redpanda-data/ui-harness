#!/bin/bash
set -euo pipefail
trap 'exit 0' ERR

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

result=$(echo "$input" | jq -r '.tool_result // empty')

if [ -z "$result" ]; then
  exit 0
fi

line_count=$(echo "$result" | wc -l | tr -d ' ')

if [ "$line_count" -gt 200 ]; then
  # Keep first 20 and last 30 lines, truncate the middle
  head_lines=$(echo "$result" | head -20)
  tail_lines=$(echo "$result" | tail -30)
  truncated_count=$((line_count - 50))

  summary=$(printf "%s\n\n... (%d lines truncated) ...\n\n%s" "$head_lines" "$truncated_count" "$tail_lines")
  escaped=$(echo "$summary" | jq -Rs . 2>/dev/null) || exit 0
  echo "{\"suppressOutput\":true,\"systemMessage\":$escaped}"
  exit 0
fi

exit 0
