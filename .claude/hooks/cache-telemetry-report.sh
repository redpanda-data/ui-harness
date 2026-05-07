#!/bin/bash
set -eo pipefail

# Cache-telemetry report: summarize sessions to decide 1h-vs-5m cache policy.
# Run manually: bash .claude/hooks/cache-telemetry-report.sh
#
# Reads from: ~/.claude/hook-metrics/cache-telemetry.jsonl
# Answers: "if we downgrade all 1h cache writes to 5m, are we losing reuse?"

log="$HOME/.claude/hook-metrics/cache-telemetry.jsonl"
if [ ! -f "$log" ]; then
  echo "no telemetry yet: $log"
  exit 0
fi

python3 - "$log" <<'PY'
import json, sys
from statistics import median

path = sys.argv[1]
sessions = []
with open(path) as f:
    for line in f:
        try: sessions.append(json.loads(line))
        except Exception: continue

if not sessions:
    print("no sessions in log")
    sys.exit(0)

n = len(sessions)
by_model = {}
for s in sessions:
    m = s.get("model","unknown")
    by_model.setdefault(m, []).append(s)

print(f"== CACHE TELEMETRY REPORT ({n} sessions) ==\n")

for model, rows in by_model.items():
    cc1h = sum(r["tokens"].get("cache_create_1h",0) for r in rows)
    cc5  = sum(r["tokens"].get("cache_create_5m",0) for r in rows)
    cr   = sum(r["tokens"].get("cache_read",0) for r in rows)
    durs = [r.get("duration_s",0) for r in rows]
    wasted = [r.get("wasted_1h_ratio",0) for r in rows if r["tokens"].get("cache_create_1h",0) > 0]

    # Cost model (Opus API-equiv)
    price = {"opus":{"cc5":18.75,"cc1h":30.0,"cr":1.5},
             "sonnet":{"cc5":3.75,"cc1h":6.0,"cr":0.3},
             "haiku":{"cc5":1.25,"cc1h":2.0,"cr":0.1}}.get(model,{"cc5":18.75,"cc1h":30.0,"cr":1.5})
    cost_1h_actual = cc1h * price["cc1h"] / 1e6
    cost_1h_as_5m  = cc1h * price["cc5"] / 1e6
    save_if_downgraded = cost_1h_actual - cost_1h_as_5m

    print(f"{model.upper()} — {len(rows)} sessions")
    print(f"  cache_create_1h  : {cc1h/1e6:>7.2f}M tok (${cost_1h_actual:>7.2f} at 2x)")
    print(f"  cache_create_5m  : {cc5/1e6:>7.2f}M tok")
    print(f"  cache_read       : {cr/1e6:>7.2f}M tok")
    if durs:
        print(f"  session duration : median={median(durs)}s  p95={sorted(durs)[int(len(durs)*0.95)]}s  max={max(durs)}s")
    if wasted:
        avg_waste = sum(wasted)/len(wasted)
        print(f"  1h-write sessions: {len(wasted)}  avg_waste_ratio={avg_waste:.2f}")
        print(f"  ** est wasted    : ${cost_1h_actual * avg_waste:>7.2f} (could save ${save_if_downgraded * avg_waste:>7.2f} if downgraded to 5m)")
    print()

print("\nRECOMMENDATION:")
print("  Collect 7+ days of data before deciding.")
print("  If median session duration < 600s and wasted_ratio > 0.5 → drop 1h cache, use 5m only.")
print("  If long multi-hour sessions dominate → keep 1h.")
PY
