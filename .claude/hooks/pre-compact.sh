#!/bin/bash
set -eo pipefail
trap 'exit 0' ERR

# PreCompact: snapshot critical session state before compaction wipes
# in-context working memory. Pairs with post-compact-context.sh which
# re-injects rules. PreCompact saves the DATA; PostCompact restores UX.

input=$(cat)
hook_event=$(echo "$input" | jq -r '.hook_event_name // empty')
[ "$hook_event" = "PreCompact" ] || exit 0

session_dir="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}"
[ -d "$session_dir" ] || exit 0

snapshot="$session_dir/pre-compact-snapshot.json"

# Capture: violation counts, touched files, timing totals
_violations=""
vfile="$session_dir/violations"
if [ -f "$vfile" ] && [ -s "$vfile" ]; then
  _violations=$(sort "$vfile" | uniq -c | sort -rn | head -10 \
    | awk '{printf "\"%s\":%d,", $2, $1}' | sed 's/,$//')
fi

_touched_count=0
tfile="$session_dir/session-touched-files"
[ -f "$tfile" ] && _touched_count=$(sort -u "$tfile" | wc -l | tr -d ' ')

_log_entries=0
lfile="$session_dir/structured.jsonl"
[ -f "$lfile" ] && _log_entries=$(wc -l < "$lfile" | tr -d ' ')

cat > "$snapshot" <<EOF
{
  "ts": $(date +%s),
  "touched_files": $_touched_count,
  "log_entries": $_log_entries,
  "violations": {${_violations}}
}
EOF

# Inject brief context: "compaction imminent, state saved"
context="[PRE-COMPACT] Session state snapshot saved. ${_log_entries} hook entries, ${_touched_count} files touched. Violation counters survive compaction."
escaped=$(printf '%s' "$context" | jq -Rs . 2>/dev/null) || exit 0
echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreCompact\",\"additionalContext\":$escaped}}" >&2

exit 0
