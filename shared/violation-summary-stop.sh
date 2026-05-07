#!/bin/bash
set -eo pipefail

# Stop hook: report aggregated violation summary from the session.
# Reads violations tracked by hook_block/hook_warn/hook_deny in hook-lib.sh.
# Note: set -u removed — CLAUDE_SESSION_ID may be unset in some contexts.

violations_file="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}/violations"

if [ ! -f "$violations_file" ] || [ ! -s "$violations_file" ]; then
  exit 0
fi

# Aggregate violation counts
summary=$(sort "$violations_file" | uniq -c | sort -rn | head -10 | while read -r count label; do
  echo "${count}x ${label}"
done | paste -sd ", " -)

if [ -z "$summary" ]; then
  exit 0
fi

total=$(wc -l < "$violations_file" | tr -d ' ')

# Report as additional context (don't block — just inform)
echo "{\"hookSpecificOutput\":{\"additionalContext\":\"Session violation summary ($total total): $summary\"}}" >&2

# Clean up
rm -f "$violations_file"

exit 0
