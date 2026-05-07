#!/bin/bash
set -eo pipefail

# Stop hook: aggregate session JSONL log into compact summary.
# Persists to ~/.claude/hook-metrics/ for /hook-audit skill.
# No source code stored — just rule names, counts, and decisions.

session_dir="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}"
log_file="$session_dir/structured.jsonl"

# Nothing logged this session — skip silently
if [ ! -f "$log_file" ] || [ ! -s "$log_file" ]; then
  exit 0
fi

# Ensure jq available (metrics are best-effort, don't block on missing jq)
if ! command -v jq &>/dev/null; then
  exit 0
fi

metrics_dir="$HOME/.claude/hook-metrics"
mkdir -p "$metrics_dir" 2>/dev/null || exit 0

# Session metadata
session_date=$(date +%Y-%m-%d)
session_id="${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-unknown}}"
total_entries=$(wc -l < "$log_file" | tr -d ' ')

# Compute session duration from first/last timestamps
first_ts=$(head -1 "$log_file" | jq -r '.ts // 0')
last_ts=$(tail -1 "$log_file" | jq -r '.ts // 0')
duration_minutes=$(( (last_ts - first_ts) / 60 ))

# Count files touched this session
touched_file="$session_dir/session-touched-files"
files_touched=0
files_by_ext=""
if [ -f "$touched_file" ]; then
  files_touched=$(sort -u "$touched_file" | wc -l | tr -d ' ')
  # Extension breakdown — used by /hook-audit to filter "silent hooks where
  # the gate could have fired" from "silent hooks where it couldn't."
  files_by_ext=$(sort -u "$touched_file" | awk -F/ '{print $NF}' | awk -F. '
    NF>1 { e=$NF; if (e ~ /^[a-zA-Z0-9_+-]+$/) ext[e]++ }
    NF==1 { ext["none"]++ }
    END { for (e in ext) printf "\"%s\":%d,", e, ext[e] }
  ' | sed 's/,$//')
fi

# Aggregate by decision type and rule
blocks=$(jq -r 'select(.decision=="block") | .rule' "$log_file" | sort | uniq -c | sort -rn | head -10 | while read -r count rule; do
  printf '"%s":%d,' "$rule" "$count"
done | sed 's/,$//')

warns=$(jq -r 'select(.decision=="warn") | .rule' "$log_file" | sort | uniq -c | sort -rn | head -10 | while read -r count rule; do
  printf '"%s":%d,' "$rule" "$count"
done | sed 's/,$//')

denies=$(jq -r 'select(.decision=="deny") | .rule' "$log_file" | sort | uniq -c | sort -rn | head -10 | while read -r count rule; do
  printf '"%s":%d,' "$rule" "$count"
done | sed 's/,$//')

# Count unique hooks that fired
hooks_fired=$(jq -r '.hook' "$log_file" | sort -u | wc -l | tr -d ' ')

# Aggregate nudge/info/diagnostic/block-strict (new tiers in 2.2.2)
nudges=$(jq -r 'select(.decision=="nudge") | .rule' "$log_file" | sort | uniq -c | sort -rn | head -10 | while read -r count rule; do
  printf '"%s":%d,' "$rule" "$count"
done | sed 's/,$//')

infos=$(jq -r 'select(.decision=="info") | .rule' "$log_file" | sort | uniq -c | sort -rn | head -10 | while read -r count rule; do
  printf '"%s":%d,' "$rule" "$count"
done | sed 's/,$//')

diagnostics=$(jq -r 'select(.decision=="diagnostic") | .rule' "$log_file" | sort | uniq -c | sort -rn | head -10 | while read -r count rule; do
  printf '"%s":%d,' "$rule" "$count"
done | sed 's/,$//')

# Latency aggregation per hook (P50 + P95 + count) — requires ms field (added 2.2.2)
perf_ms=$(jq -r 'select(.ms != null) | [.hook, .ms] | @tsv' "$log_file" 2>/dev/null \
  | sort -k1,1 \
  | awk -F'\t' '
      { hook=$1; ms=$2+0; times[hook] = (times[hook] ? times[hook] "," ms : ms); count[hook]++ }
      END {
        for (h in times) {
          n = split(times[h], arr, ",")
          # sort asc
          for (i=1; i<=n; i++) for (j=i+1; j<=n; j++) if (arr[j]<arr[i]) { t=arr[i]; arr[i]=arr[j]; arr[j]=t }
          p50 = arr[int(n/2)+1]
          p95 = arr[int(n*0.95)+1]
          if (p95 == "") p95 = arr[n]
          printf "\"%s\":{\"p50\":%d,\"p95\":%d,\"n\":%d},", h, p50, p95, n
        }
      }
    ' | sed 's/,$//')

# Build summary JSON
# Filename includes first_ts so multiple sessions on the same day don't
# overwrite each other when CLAUDE_SESSION_ID falls through to "unknown"
# (was clobbering — fixed 2026-04-29). Bump schema_version on shape change.
out_file="$metrics_dir/${session_date}-${session_id:0:8}-${first_ts:-$$}.json"
cat > "$out_file" <<EOF
{
  "schema_version": 3,
  "date": "$session_date",
  "session_id": "${session_id:0:8}",
  "first_ts": ${first_ts:-0},
  "duration_minutes": $duration_minutes,
  "files_touched": $files_touched,
  "files_by_ext": {${files_by_ext}},
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
