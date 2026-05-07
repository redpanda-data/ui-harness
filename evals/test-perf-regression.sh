# Evals for perf-regression-stop.sh
# Static checks only — full integration requires running a dev server
# and Lighthouse, out of scope for unit evals.

HOOK="$REPO_ROOT/.claude/hooks/perf-regression-stop.sh"

run_file_eval "$HOOK" "perf-regression-stop.sh exists"
run_executable_eval "$HOOK" "perf-regression-stop.sh executable"
run_content_eval "$REPO_ROOT/skill-manifest.json" "perf-regression-stop.sh" \
  "manifest registers perf-regression-stop"
run_content_eval "$REPO_ROOT/hooks/hooks.json" "perf-regression-stop.sh" \
  "hooks.json registers perf-regression-stop"

# Graceful skip conditions documented
run_content_eval "$HOOK" "PERF_REGRESSION_SKIP" "hook honors PERF_REGRESSION_SKIP env"
run_content_eval "$HOOK" "lighthouse" "hook uses lighthouse CLI"
run_content_eval "$HOOK" "lhci" "hook falls back to lhci"
run_content_eval "$HOOK" "baselines" "hook uses .claude/baselines dir"
run_content_eval "$HOOK" "perf.json" "hook writes perf.json baseline"

# Metrics covered
run_content_eval "$HOOK" "largest-contentful-paint" "hook captures LCP"
run_content_eval "$HOOK" "cumulative-layout-shift" "hook captures CLS"
run_content_eval "$HOOK" "total-blocking-time" "hook captures TBT"

# Principle cross-reference
run_content_eval "$HOOK" "\\[ETHOS:" "hook cross-references ETHOS principle"

# Graceful skip behavior: no session tracking → exit 0
export CLAUDE_SESSION_ID="eval-perf-$$"
_d="/tmp/hook-session-$CLAUDE_SESSION_ID"
mkdir -p "$_d"
# No session-touched-files → should skip
_ec=0
bash "$HOOK" < /dev/null > /dev/null 2>&1 || _ec=$?
if [ "$_ec" -eq 0 ]; then
  echo "  PASS  no-session-tracking exits 0"
  PASS=$((PASS + 1))
else
  echo "  FAIL  no-session-tracking exit was $_ec"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: no-session-tracking exit"
fi
find /tmp -maxdepth 1 -name "hook-session-eval-perf-*" -exec rm -rf {} + 2>/dev/null || true
unset CLAUDE_SESSION_ID
