#!/usr/bin/env bash
set -euo pipefail

input=$(cat)
file=$(printf '%s' "$input" | jq -er '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null) || exit 0
tool=$(printf '%s' "$input" | jq -r '.tool_name // ""')
case "$tool" in Read|Edit|Write) ;; *) exit 0 ;; esac
case "/$file" in
  */node_modules/*|*/generated/*|*/vendor/*|*.gen.*|*_pb.*|*_connectquery.*|*.d.ts) exit 0 ;;
esac
case "/$file" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  */locales/*|*/locale/*|*/i18n/*|*/l10n/*|*/translations/*|*/messages/*|*/messages.*|*/translations.*)
    case "$file" in *.json|*.yaml|*.yml|*.po) ;; *) exit 0 ;; esac ;;
  *) exit 0 ;;
esac
if [ -f "$file" ] && head -n 5 "$file" | grep -qE '@generated|DO NOT EDIT'; then exit 0; fi

skill_dir=$(cd "$(dirname "$0")/.." && pwd)
context=$(printf 'UX copy guidance: %s/SKILL.md\nRead %s/REFERENCE.md for the writing/review rules.\n\n' "$skill_dir" "$skill_dir"
  awk 'BEGIN { header=0 } /^---$/ && header < 2 { header++; next } header == 2 { print }' "$skill_dir/SKILL.md")
jq -n --arg context "$context" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$context}}'
