#!/bin/bash
set -euo pipefail

# Baseline bash-drain measurement over last N days of Claude Code transcripts.
# Feeds the Phase-3 before/after comparison in the Hook Effectiveness plan.
#
# Usage:
#   bash-drain-baseline.sh               # last 30 days, 200-file stratified sample
#   bash-drain-baseline.sh --days 14     # custom window
#   bash-drain-baseline.sh --full        # no sampling (slow; ~2000 files)
#   bash-drain-baseline.sh --out PATH    # override output path
#
# Output: JSON written to ~/.claude/hook-metrics/bash-drain-baseline-<date>.json
# Schema: { "generated_at", "window_days", "sample_size", "total_sessions",
#           "total_bash_calls", "total_bytes", "p50_bytes", "p90_bytes",
#           "p99_bytes", "cap_hits_30k_plus", "drain_counts": {...},
#           "top_commands": [...] }

DAYS=30
SAMPLE=200
FULL=0
OUT_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="$2"; shift 2 ;;
    --sample) SAMPLE="$2"; shift 2 ;;
    --full) FULL=1; shift ;;
    --out) OUT_OVERRIDE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

METRICS_DIR="${HOME}/.claude/hook-metrics"
mkdir -p "$METRICS_DIR"

TODAY=$(date -u +%Y-%m-%d)
OUT="${OUT_OVERRIDE:-$METRICS_DIR/bash-drain-baseline-${TODAY}.json}"

TMPDIR=$(mktemp -d)
if [ -z "${KEEP_TMP:-}" ]; then
  trap 'rm -rf "$TMPDIR"' EXIT
else
  echo "KEEP_TMP=1 → $TMPDIR preserved" >&2
fi

PROJECTS_DIR="${HOME}/.claude/projects"
[ -d "$PROJECTS_DIR" ] || { echo "no projects dir at $PROJECTS_DIR" >&2; exit 1; }

# Collect candidate transcripts modified within the window
FILES_LIST="$TMPDIR/files"
find "$PROJECTS_DIR" -name "*.jsonl" -mtime "-${DAYS}" -type f > "$FILES_LIST" 2>/dev/null || true
TOTAL_FILES=$(wc -l < "$FILES_LIST" | tr -d ' ')

if [ "$FULL" -eq 1 ] || [ "$TOTAL_FILES" -le "$SAMPLE" ]; then
  SAMPLED="$FILES_LIST"
  SAMPLE_SIZE="$TOTAL_FILES"
else
  # Stratified by project dir: sort by mtime within each project dir, round-robin pick.
  # Simple approximation: sort by mtime desc, pick every Nth to spread across projects.
  SAMPLED="$TMPDIR/sampled"
  # shellcheck disable=SC2016
  ls -t $(cat "$FILES_LIST") 2>/dev/null \
    | awk -v n="$SAMPLE" -v t="$TOTAL_FILES" 'BEGIN{step=t/n; if(step<1)step=1} NR==int(i*step)+1 {print; i++}' \
    > "$SAMPLED" || true
  # Fallback if awk got weird: just head
  if [ ! -s "$SAMPLED" ]; then
    ls -t $(cat "$FILES_LIST") 2>/dev/null | head -n "$SAMPLE" > "$SAMPLED"
  fi
  SAMPLE_SIZE=$(wc -l < "$SAMPLED" | tr -d ' ')
fi

echo "Scanning $SAMPLE_SIZE transcripts (of $TOTAL_FILES in last ${DAYS}d)..." >&2

# Extract (command, output_bytes) per bash call.
# Claude Code JSONL schema (as of 2026-04):
#   assistant turn: .type=="assistant", .message.content[] where .type=="tool_use", .name=="Bash", .input.command
#   user turn:      .type=="user", .toolUseResult.stdout / .stderr (preferred) OR
#                    .message.content[] where .type=="tool_result" (content is stringified)
#
# Strategy: walk pairs. We record (id, command) from assistant, then look up
# matching tool_use_id in subsequent user tool_result. Simpler: just count
# output bytes via sum of stdout+stderr len per tool_use_id.

PAIRS="$TMPDIR/pairs.tsv"
> "$PAIRS"

while IFS= read -r jsonl; do
  # One jq pass: emit "CMD<TAB>id<TAB>cmd" for tool_use, "OUT<TAB>id<TAB>bytes" for tool_result.
  # User turns link to their tool_use via .message.content[].tool_use_id (array form).
  # Output bytes come from .toolUseResult.stdout+stderr when present.
  jq -rc '
    if .type=="assistant" then
      (.message.content // []) as $c
      | if ($c|type)=="array" then
          $c[]? | select(.type=="tool_use" and .name=="Bash")
          | "CMD\t\(.id)\t\((.input.command // "") | tostring | gsub("[\t\n]"; " "))"
        else empty end
    elif .type=="user" then
      (.message.content // []) as $c
      | if ($c|type)=="array" then
          ($c[]? | select(.type=="tool_result") | .tool_use_id // "") as $id
          | if ($id|length)>0 then
              (.toolUseResult // {}) as $r
              | if ($r|type)=="object" then
                  (($r.stdout // "") + ($r.stderr // "")) as $out
                  | "OUT\t\($id)\t\($out | length)"
                else
                  ($c[]? | select(.type=="tool_result" and .tool_use_id==$id) | .content // "") as $body
                  | "OUT\t\($id)\t\($body | tostring | length)"
                end
            else empty end
        else empty end
    else empty end
  ' "$jsonl" 2>/dev/null >> "$PAIRS" || true
done < "$SAMPLED"

# Join CMD rows with OUT rows on id; emit cmd<TAB>bytes
JOINED="$TMPDIR/joined.tsv"
awk -F'\t' '
  $1=="CMD" { cmd[$2]=$3; next }
  $1=="OUT" && cmd[$2] { print cmd[$2] "\t" $3 }
' "$PAIRS" > "$JOINED"

TOTAL_CALLS=$(wc -l < "$JOINED" | tr -d ' ')
TOTAL_BYTES=$(awk -F'\t' '{s+=$2} END{print s+0}' "$JOINED")

# Percentiles via sort
BYTES_SORTED="$TMPDIR/bytes-sorted"
awk -F'\t' '{print $2}' "$JOINED" | sort -n > "$BYTES_SORTED"

pct() {
  local p="$1"
  awk -v p="$p" '
    { a[NR]=$1 }
    END{
      if(NR==0){print 0; exit}
      idx=int(NR*p/100); if(idx<1)idx=1
      print a[idx]+0
    }
  ' "$BYTES_SORTED"
}

P50=$(pct 50)
P90=$(pct 90)
P99=$(pct 99)
CAP_HITS=$(awk -F'\t' '$2>=30000' "$JOINED" | wc -l | tr -d ' ')

# Drain pattern counts. Keep regex aligned with bash-verbose-guard.sh.
# Extract commands only (column 1) so grep can do the heavy lifting — more
# portable across macOS (BSD) awk vs GNU awk alternation limits.
CMDS_ONLY="$TMPDIR/cmds.txt"
cut -f1 "$JOINED" > "$CMDS_ONLY"

count_include_exclude() {
  local include="$1" exclude="$2" result
  result=$(
    set +o pipefail
    if [ -z "$exclude" ]; then
      grep -cE "$include" "$CMDS_ONLY" 2>/dev/null || true
    else
      grep -E "$include" "$CMDS_ONLY" 2>/dev/null | grep -cvE "$exclude" 2>/dev/null || true
    fi
  )
  # Take first line only, default to 0 when empty.
  result=$(printf '%s' "$result" | head -1 | tr -d ' \n')
  echo "${result:-0}"
}

NUDGE_GIT_COMMIT=$(count_include_exclude 'git +commit( |$)' '(\-\-quiet|[[:space:]]\-q([[:space:]]|$))')
NUDGE_GH_JQ=$(count_include_exclude 'gh +(pr +view|api|pr +list|issue +view|run +view|repo +view).*\-\-json' '(\-\-jq|\| *jq|\| *head|\| *wc|\| *tail)')
NUDGE_GIT_LOG=$(count_include_exclude 'git +log' '(\-n +[0-9]|\-\-max-count|\-\-oneline|\| *head)')
NUDGE_FIND=$(count_include_exclude '(^|[^a-zA-Z])find +' '(\-maxdepth|\| *head|\| *tail)')
NUDGE_CAT_ARTIFACT=$(count_include_exclude 'cat +(node_modules|dist|build|coverage|\.git/)' '')
NUDGE_GREP_ROOT=$(count_include_exclude 'grep +\-r +[^ ]+ +(\.|/Users|/home)' '(\-\-include|\| *head)')

# Repeat-command: same full command seen more than once per session cannot be
# recovered from our flat JOINED (it has no session id). Approximated here by
# exact command duplicates across the sample.
REPEAT_CMDS=$(awk -F'\t' '{c[$1]++} END{for(k in c)if(c[k]>1)n+=c[k]-1; print n+0}' "$JOINED")

# Top 10 commands by total bytes (sum, sort desc, head)
TOP_CMDS="$TMPDIR/top-cmds.json"
# Subshell disables pipefail — head -10 closing the pipe upstream is expected,
# not an error. Without this, SIGPIPE from sort upstream fails the whole pipe.
(
  set +o pipefail
  awk -F'\t' '{sum[$1]+=$2; cnt[$1]++} END{for(k in sum) printf "%d\t%d\t%s\n", sum[k], cnt[k], k}' "$JOINED" \
    | sort -rn \
    | head -10 \
    | jq -R -s '
        split("\n")
        | map(select(length>0) | split("\t"))
        | map(select(length>=3))
        | map({
            total_bytes: ((.[0] // "0") | tonumber? // 0),
            calls:       ((.[1] // "0") | tonumber? // 0),
            cmd:         ((.[2] // "") | .[0:120])
          })
      ' > "$TOP_CMDS"
)
[ -s "$TOP_CMDS" ] || echo '[]' > "$TOP_CMDS"

# Emit final JSON
jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson window_days "$DAYS" \
  --argjson sample_size "$SAMPLE_SIZE" \
  --argjson total_files "$TOTAL_FILES" \
  --argjson total_bash_calls "$TOTAL_CALLS" \
  --argjson total_bytes "$TOTAL_BYTES" \
  --argjson p50 "$P50" --argjson p90 "$P90" --argjson p99 "$P99" \
  --argjson cap_hits "$CAP_HITS" \
  --argjson nudge_git_commit "$NUDGE_GIT_COMMIT" \
  --argjson nudge_gh_jq "$NUDGE_GH_JQ" \
  --argjson nudge_git_log "$NUDGE_GIT_LOG" \
  --argjson nudge_find "$NUDGE_FIND" \
  --argjson nudge_cat_artifact "$NUDGE_CAT_ARTIFACT" \
  --argjson nudge_grep_root "$NUDGE_GREP_ROOT" \
  --argjson repeat_cmds "$REPEAT_CMDS" \
  --slurpfile top_commands "$TOP_CMDS" \
  '{
    generated_at: $generated_at,
    window_days: $window_days,
    sample_size: $sample_size,
    total_files_in_window: $total_files,
    total_bash_calls: $total_bash_calls,
    total_bytes: $total_bytes,
    p50_bytes: $p50,
    p90_bytes: $p90,
    p99_bytes: $p99,
    cap_hits_30k_plus: $cap_hits,
    drain_counts: {
      nudge_git_commit: $nudge_git_commit,
      nudge_gh_jq: $nudge_gh_jq,
      nudge_git_log: $nudge_git_log,
      nudge_find: $nudge_find,
      nudge_cat_artifact: $nudge_cat_artifact,
      nudge_grep_root: $nudge_grep_root,
      repeat_cmds: $repeat_cmds
    },
    top_commands: $top_commands[0]
  }' > "$OUT"

echo "Wrote $OUT" >&2
jq '{sample_size, total_bash_calls, total_bytes, cap_hits_30k_plus, drain_counts}' "$OUT"
