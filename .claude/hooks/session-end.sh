#!/bin/bash
set -eo pipefail

# SessionEnd: aggregate session JSONL into summary. Runs ONCE per session
# (replaces metrics-summary-stop.sh which ran on every turn end = wasteful).
# Also writes a memory summary for next-session context.

session_dir="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}"
log_file="$session_dir/structured.jsonl"

[ -f "$log_file" ] && [ -s "$log_file" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

metrics_dir="$HOME/.claude/hook-metrics"
mkdir -p "$metrics_dir" 2>/dev/null || exit 0

session_date=$(date +%Y-%m-%d)
session_id="${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-unknown}}"
total_entries=$(wc -l < "$log_file" | tr -d ' ')

first_ts=$(head -1 "$log_file" | jq -r '.ts // 0')
last_ts=$(tail -1 "$log_file" | jq -r '.ts // 0')
duration_minutes=$(( (last_ts - first_ts) / 60 ))

touched_file="$session_dir/session-touched-files"
files_touched=0
[ -f "$touched_file" ] && files_touched=$(sort -u "$touched_file" | wc -l | tr -d ' ')

_top() {
  local dec="$1"
  jq -r "select(.decision==\"$dec\") | .rule" "$log_file" | sort | uniq -c | sort -rn | head -10 \
    | while read -r count rule; do printf '"%s":%d,' "$rule" "$count"; done | sed 's/,$//'
}

blocks=$(_top "block")
warns=$(_top "warn")
denies=$(_top "deny")
nudges=$(_top "nudge")
infos=$(_top "info")
diagnostics=$(_top "diagnostic")

perf_ms=$(jq -r 'select(.ms != null) | [.hook, .ms] | @tsv' "$log_file" 2>/dev/null \
  | awk -F'\t' '
      { hook=$1; ms=$2+0; times[hook] = (times[hook] ? times[hook] "," ms : ms); count[hook]++ }
      END {
        for (h in times) {
          n = split(times[h], arr, ",")
          for (i=1; i<=n; i++) for (j=i+1; j<=n; j++) if (arr[j]<arr[i]) { t=arr[i]; arr[i]=arr[j]; arr[j]=t }
          p50 = arr[int(n/2)+1]
          p95 = arr[int(n*0.95)+1]
          if (p95 == "") p95 = arr[n]
          printf "\"%s\":{\"p50\":%d,\"p95\":%d,\"n\":%d},", h, p50, p95, n
        }
      }
    ' | sed 's/,$//')

hooks_fired=$(jq -r '.hook' "$log_file" | sort -u | wc -l | tr -d ' ')

cat > "$metrics_dir/${session_date}-${session_id:0:8}.json" <<EOF
{
  "schema_version": 2,
  "date": "$session_date",
  "session_id": "${session_id:0:8}",
  "duration_minutes": $duration_minutes,
  "files_touched": $files_touched,
  "total_entries": $total_entries,
  "hooks_fired": $hooks_fired,
  "blocks": {${blocks}},
  "warns": {${warns}},
  "denies": {${denies}},
  "nudges": {${nudges}},
  "infos": {${infos}},
  "diagnostics": {${diagnostics}},
  "perf_ms": {${perf_ms}}
}
EOF

exit 0
