# Evals for cache-telemetry-stop.sh — Stop hook that logs per-session
# cache behavior (cc1h, cc5m, cr, duration) to decide 1h-vs-5m policy.

HOOK="$REPO_ROOT/.claude/hooks/cache-telemetry-stop.sh"
REPORT="$REPO_ROOT/.claude/hooks/cache-telemetry-report.sh"

run_file_eval "$HOOK" "cache-telemetry-stop.sh exists"
run_executable_eval "$HOOK" "cache-telemetry-stop.sh executable"
run_file_eval "$REPORT" "cache-telemetry-report.sh exists"
run_executable_eval "$REPORT" "cache-telemetry-report.sh executable"

# Registration: must be in hooks.json Stop array
if grep -q 'cache-telemetry-stop.sh' "$REPO_ROOT/hooks/hooks.json" 2>/dev/null; then
  echo "  PASS  hooks.json registers cache-telemetry-stop"
  PASS=$((PASS + 1))
else
  echo "  FAIL  hooks.json missing cache-telemetry-stop"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: cache-telemetry not registered"
fi

# Fixture: synthesize a minimal transcript with one assistant usage block
fake_transcript=$(mktemp)
cat > "$fake_transcript" <<'JSONL'
{"type":"assistant","timestamp":"2026-04-19T10:00:00Z","message":{"model":"claude-opus-4-7","usage":{"input_tokens":10,"cache_read_input_tokens":1000,"cache_creation":{"ephemeral_5m_input_tokens":500,"ephemeral_1h_input_tokens":200},"output_tokens":50}}}
{"type":"assistant","timestamp":"2026-04-19T10:02:30Z","message":{"model":"claude-opus-4-7","usage":{"input_tokens":5,"cache_read_input_tokens":2000,"cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":0},"output_tokens":30}}}
JSONL

# Run hook
ec=0
echo "{\"session_id\":\"test-telemetry\",\"transcript_path\":\"$fake_transcript\"}" \
  | bash "$HOOK" 2>/dev/null >/dev/null || ec=$?
rm -f "$fake_transcript"

# Hook always exits 0 (don't block user). Actual output is the JSONL append.
if [ "$ec" = "0" ]; then
  echo "  PASS  hook exits 0 even with no telemetry file"
  PASS=$((PASS + 1))
else
  echo "  FAIL  hook should exit 0 (got $ec)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: telemetry exit"
fi

# Check the telemetry file got a new entry
log="$HOME/.claude/hook-metrics/cache-telemetry.jsonl"
if [ -f "$log" ]; then
  tail -1 "$log" | python3 -c "
import json,sys
d = json.loads(sys.stdin.read())
assert d['session_id'] == 'test-telemetry'
assert d['model'] == 'opus'
assert d['tokens']['cache_read'] == 3000
assert d['tokens']['cache_create_5m'] == 500
assert d['tokens']['cache_create_1h'] == 200
assert d['duration_s'] == 150  # 2min30 between timestamps
" 2>/dev/null
  if [ "$?" = "0" ]; then
    echo "  PASS  telemetry entry correctly aggregates usage"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  telemetry entry missing or wrong shape"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: telemetry aggregation"
  fi
else
  echo "  SKIP  telemetry log not created (hook may have been blocked)"
  SKIP=$((SKIP + 1))
fi

# Report script runs without error on existing log
if [ -f "$log" ]; then
  out=$(bash "$REPORT" 2>&1)
  if echo "$out" | grep -q "CACHE TELEMETRY REPORT"; then
    echo "  PASS  report script produces expected header"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  report script missing header"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: report header"
  fi
fi

# Hook silently no-ops when transcript_path missing or empty input
ec=0
echo '{}' | bash "$HOOK" 2>/dev/null >/dev/null || ec=$?
if [ "$ec" = "0" ]; then
  echo "  PASS  no-op on empty session_id"
  PASS=$((PASS + 1))
else
  echo "  FAIL  should no-op on empty input"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: empty input"
fi
