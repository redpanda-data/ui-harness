#!/bin/bash
set -eo pipefail
trap 'exit 0' ERR

# PostCompact hook: re-inject critical context after context compression.
# When Claude's context gets compacted, the rules line and config from
# UserPromptSubmit are lost. This re-injects the essentials.
# Inspired by Boris Cherny's (Claude Code creator) recommendation.

input=$(cat)
hook_event=$(echo "$input" | jq -r '.hook_event_name // empty')

if [ "$hook_event" != "PostCompact" ]; then
  exit 0
fi

context=""

# Re-inject condensed rules (same as user-prompt-context.sh standard level)
rules=""
[ "${PKG_MANAGER:-}" ] && rules="$rules ${PKG_MANAGER}"
[ "${LINTER:-}" ] && rules="$rules ${LINTER}"
[ "${TEST_RUNNER:-}" ] && rules="$rules ${TEST_RUNNER}"
rules="$rules | no-memo(compiler) no-as-any no-ts-ignore no-style={{}}"
[ "${REACT_RULES_BAN_USEEFFECT:-}" = "1" ] && rules="$rules no-useEffect"
rules="$rules | UI:@/components/ui/ | no-raw-HTML | zustand:create<T>()() useShallow | env:@/env"

[ -f ".claude/hooks/tanstack-router-check.sh" ] && rules="$rules | TanStack-Router"
[ -f ".claude/hooks/connect-query-check.sh" ] && rules="$rules | connect-query proto-v2:create()"

context="[POST-COMPACTION] Context was compressed. Key rules re-injected:\nRules:$rules"

# Re-inject active config
config=""
[ "${REACT_COMPILER_MODE:-}" ] && config="$config compiler=$REACT_COMPILER_MODE"
[ "${ISSUE_TRACKER:-}" ] && config="$config tracker=$ISSUE_TRACKER"
[ "${REDPANDA_KIT:-}" = "1" ] && config="$config redpanda-kit=on"
[ -n "$config" ] && context="$context\nConfig:$config"

# Re-inject last stop outcome if available
stop_file="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}/last-stop"
if [ -f "$stop_file" ]; then
  context="$context\nLast stop: $(cat "$stop_file" | head -1)"
fi

# Post-compaction brevity: context is tight, maximize token efficiency (arxiv:2604.00025)
context="$context\n[BREVITY:ultra] Max compression. Code>prose. No preamble/recap/summary. Exception: full clarity for security, irreversible ops, destructive commands."

if [ -n "$context" ]; then
  escaped=$(printf '%s' "$context" | jq -Rs . 2>/dev/null) || exit 0
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostCompact\",\"additionalContext\":$escaped}}" >&2
fi

exit 0
