#!/bin/bash
set -eo pipefail

# Stop hook: log session-level cache behavior for 1h-vs-5m ROI decision.
# Data goal: over 7-14 days, learn whether sessions actually re-read 1h
# cache writes after the 5m window. If not, downgrade all writes to 5m
# (2x cheaper). Writes NDJSON to ~/.claude/hook-metrics/cache-telemetry.jsonl.

_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else exit 0; fi

_in=$(cat)
session_id=$(echo "$_in" | jq -r '.session_id // empty' 2>/dev/null || true)
transcript=$(echo "$_in" | jq -r '.transcript_path // empty' 2>/dev/null || true)

[ -z "$session_id" ] && exit 0
[ -z "$transcript" ] || [ ! -f "$transcript" ] && exit 0

# Aggregate usage from the session transcript (Python inline, no heredoc injection)
read_only_py() {
  python3 - <<'PY' "$1"
import json, sys, os
from datetime import datetime, timezone

path = sys.argv[1]
totals = {
    "cc5": 0, "cc1h": 0, "cr": 0, "input": 0, "output": 0,
    "requests": 0, "model": "unknown",
}
first_ts = None
last_ts = None

try:
    with open(path) as f:
        for line in f:
            try: obj = json.loads(line)
            except Exception: continue
            if obj.get("type") != "assistant":
                continue
            msg = obj.get("message", {}) or {}
            u = msg.get("usage") or {}
            cc = u.get("cache_creation", {}) or {}
            cc5 = cc.get("ephemeral_5m_input_tokens", 0) or 0
            cc1h = cc.get("ephemeral_1h_input_tokens", 0) or 0
            if cc5 == 0 and cc1h == 0:
                cc5 = u.get("cache_creation_input_tokens", 0) or 0
            totals["cc5"] += cc5
            totals["cc1h"] += cc1h
            totals["cr"] += u.get("cache_read_input_tokens", 0) or 0
            totals["input"] += u.get("input_tokens", 0) or 0
            totals["output"] += u.get("output_tokens", 0) or 0
            totals["requests"] += 1
            m = (msg.get("model") or "").lower()
            if "opus" in m: totals["model"] = "opus"
            elif "sonnet" in m and totals["model"] == "unknown": totals["model"] = "sonnet"
            elif "haiku" in m and totals["model"] == "unknown": totals["model"] = "haiku"
            ts = obj.get("timestamp")
            if ts:
                if first_ts is None or ts < first_ts: first_ts = ts
                if last_ts is None or ts > last_ts: last_ts = ts
except Exception as e:
    print(json.dumps({"error": str(e)}))
    sys.exit(0)

duration_s = 0
if first_ts and last_ts:
    try:
        t0 = datetime.fromisoformat(first_ts.replace("Z","+00:00"))
        t1 = datetime.fromisoformat(last_ts.replace("Z","+00:00"))
        duration_s = int((t1 - t0).total_seconds())
    except Exception: pass

# Heuristic: did 1h cache actually get reused?
# If cc1h > 0 but session duration < 5 min, the 1h extension paid for nothing.
wasted_1h_ratio = 0.0
if totals["cc1h"] > 0 and duration_s < 300:
    wasted_1h_ratio = 1.0
elif totals["cc1h"] > 0 and duration_s < 3600:
    # Partial waste if duration < 1h; rough score
    wasted_1h_ratio = round(1.0 - (duration_s - 300) / 3300, 3)

out = {
    "ts": datetime.now(timezone.utc).isoformat(),
    "session_id": os.environ.get("SESSION_ID", ""),
    "model": totals["model"],
    "duration_s": duration_s,
    "requests": totals["requests"],
    "tokens": {
        "input": totals["input"],
        "cache_read": totals["cr"],
        "cache_create_5m": totals["cc5"],
        "cache_create_1h": totals["cc1h"],
        "output": totals["output"],
    },
    "wasted_1h_ratio": wasted_1h_ratio,
}
print(json.dumps(out))
PY
}

mkdir -p "$HOME/.claude/hook-metrics" 2>/dev/null || true
export SESSION_ID="$session_id"
line=$(read_only_py "$transcript" 2>/dev/null || true)
if [ -n "$line" ] && echo "$line" | jq -e . >/dev/null 2>&1; then
  echo "$line" >> "$HOME/.claude/hook-metrics/cache-telemetry.jsonl" 2>/dev/null || true
fi

exit 0
