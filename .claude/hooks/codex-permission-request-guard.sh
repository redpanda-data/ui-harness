#!/bin/bash
set -eo pipefail

# Codex PermissionRequest adapter.
# Reuses existing Claude PreToolUse deny guardrails when Codex is about to ask
# for approval. Converts legacy `permissionDecision: deny` / exit-2 hook output
# into Codex's PermissionRequest `decision.behavior: deny` shape.

input=$(cat 2>/dev/null || echo '{}')
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)
hook_dir=$(cd "$(dirname "$0")" && pwd)

case "$tool_name" in
  Bash)
    candidates="enforce-toolchain.sh conventional-commits-check.sh branch-safety-check.sh"
    ;;
  *)
    exit 0
    ;;
esac

_extract_message() {
  payload=$(cat)

  # Most hooks emit one pretty-printed JSON object.
  if echo "$payload" | jq -e . >/dev/null 2>&1; then
    echo "$payload" | jq -r '.systemMessage // .hookSpecificOutput.permissionDecisionReason // .reason // empty' 2>/dev/null
    return 0
  fi

  # Fallback for hooks that mix log lines with compact JSON lines.
  printf '%s
' "$payload" | awk 'NF { print }' | while IFS= read -r line; do
    if echo "$line" | jq -e . >/dev/null 2>&1; then
      msg=$(echo "$line" | jq -r '.systemMessage // .hookSpecificOutput.permissionDecisionReason // .reason // empty' 2>/dev/null || true)
      [ -n "$msg" ] && { printf '%s
' "$msg"; return 0; }
    fi
  done
}

for script in $candidates; do
  path="$hook_dir/$script"
  [ -x "$path" ] || continue

  output=""
  status=0
  output=$(printf '%s' "$input" | "$path" 2>&1 >/dev/null) || status=$?

  denied=false
  if [ "$status" -eq 2 ]; then
    denied=true
  elif echo "$output" | grep -q '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"'; then
    denied=true
  fi

  if [ "$denied" = true ]; then
    message=$(printf '%s\n' "$output" | _extract_message | head -1)
    [ -n "$message" ] || message="Permission request denied by frontend-skills guard ($script)."
    jq -n --arg msg "$message" '{hookSpecificOutput:{hookEventName:"PermissionRequest",decision:{behavior:"deny",message:$msg}}}'
    exit 0
  fi
done

exit 0
