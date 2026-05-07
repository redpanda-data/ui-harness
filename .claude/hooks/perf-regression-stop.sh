#!/bin/bash
set -eo pipefail

# Stop hook: Core Web Vitals baseline compare via Lighthouse.
# Runs only if session touched route/page/component files AND
# project has a dev script AND lighthouse CLI is available.
# Auto-spins dev server, runs lighthouse once, compares to baseline,
# blocks on >10% regress. Kills dev server on exit.
#
# Graceful skip conditions (exit 0 silent):
#   - no session code touched
#   - no package.json / no dev script
#   - lhci + lighthouse both missing
#   - dev server failed to bind
#   - baseline absent (captures current as baseline)
#
# Escape: PERF_REGRESSION_SKIP=1 in env.

source "$(dirname "$0")/source-hook-lib.sh" 2>/dev/null || true

[ "${PERF_REGRESSION_SKIP:-0}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
hook_has_session_tracking 2>/dev/null || exit 0

_touched=$(hook_session_changed_files "ts|tsx" 2>/dev/null)
echo "$_touched" | grep -qE '/(routes|pages|components|views)/' || exit 0

_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
[ -f "$_root/package.json" ] || exit 0
_dev=$(jq -r '.scripts.dev // empty' "$_root/package.json" 2>/dev/null)
[ -z "$_dev" ] && exit 0

# Need lighthouse or lhci. Prefer lhci (wrapper with baseline mgmt).
_lh=""
command -v lhci >/dev/null 2>&1 && _lh="lhci"
[ -z "$_lh" ] && command -v lighthouse >/dev/null 2>&1 && _lh="lighthouse"
[ -z "$_lh" ] && exit 0

# Port detection: vite config, next config, or 3000 fallback.
_port=3000
[ -f "$_root/vite.config.ts" ] && _port=$(grep -oE 'port:\s*[0-9]+' "$_root/vite.config.ts" | grep -oE '[0-9]+' | head -1 || echo 5173)
[ -f "$_root/next.config.js" ] || [ -f "$_root/next.config.ts" ] && _port=3000

# Spin dev server detached.
_log=$(mktemp)
( cd "$_root" && nohup bun run dev >"$_log" 2>&1 & echo $! ) > "$_hook_session_dir/perf-dev-pid" 2>/dev/null || exit 0
_pid=$(cat "$_hook_session_dir/perf-dev-pid" 2>/dev/null)

# Wait up to 30s for port.
_ready=false
for _i in $(seq 1 30); do
  if command -v nc >/dev/null 2>&1 && nc -z localhost "$_port" 2>/dev/null; then _ready=true; break; fi
  if command -v curl >/dev/null 2>&1 && curl -sSf "http://localhost:$_port" >/dev/null 2>&1; then _ready=true; break; fi
  sleep 1
done

_cleanup() {
  [ -n "$_pid" ] && kill "$_pid" 2>/dev/null || true
  rm -f "$_log" "$_hook_session_dir/perf-dev-pid" 2>/dev/null || true
}
trap _cleanup EXIT

[ "$_ready" = false ] && exit 0

# Run lighthouse on the root page.
_out=$(mktemp)
if [ "$_lh" = "lighthouse" ]; then
  lighthouse "http://localhost:$_port" --only-categories=performance \
    --output=json --output-path="$_out" --chrome-flags="--headless" \
    --quiet 2>/dev/null || exit 0
elif [ "$_lh" = "lhci" ]; then
  lhci collect --url="http://localhost:$_port" --numberOfRuns=1 \
    --settings.output=json --settings.outputPath="$_out" 2>/dev/null || exit 0
fi

[ -s "$_out" ] || exit 0

_lcp=$(jq -r '.audits["largest-contentful-paint"].numericValue // empty' "$_out" 2>/dev/null)
_cls=$(jq -r '.audits["cumulative-layout-shift"].numericValue // empty' "$_out" 2>/dev/null)
_tbt=$(jq -r '.audits["total-blocking-time"].numericValue // empty' "$_out" 2>/dev/null)
_ttfb=$(jq -r '.audits["server-response-time"].numericValue // empty' "$_out" 2>/dev/null)

_baseline_dir="$_root/.claude/baselines"
_baseline="$_baseline_dir/perf.json"
mkdir -p "$_baseline_dir" 2>/dev/null

if [ ! -f "$_baseline" ]; then
  cat > "$_baseline" <<EOF
{ "lcp": ${_lcp:-null}, "cls": ${_cls:-null}, "tbt": ${_tbt:-null}, "ttfb": ${_ttfb:-null}, "captured_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)" }
EOF
  exit 0
fi

_b_lcp=$(jq -r '.lcp // empty' "$_baseline" 2>/dev/null)
_b_cls=$(jq -r '.cls // empty' "$_baseline" 2>/dev/null)
_b_tbt=$(jq -r '.tbt // empty' "$_baseline" 2>/dev/null)

_regress=""
_check() {
  local name="$1" cur="$2" base="$3" threshold_pct="$4" abs="${5:-0}"
  { [ -z "$cur" ] || [ -z "$base" ]; } && return 0
  local delta
  if [ "$abs" = "1" ]; then
    delta=$(echo "$cur $base" | awk '{printf "%.3f", $1 - $2}')
    awk -v d="$delta" -v t="$threshold_pct" 'BEGIN { exit !(d > t) }' && \
      _regress="$_regress | $name +$delta (baseline $base, cap +$threshold_pct abs)"
  else
    local pct
    pct=$(echo "$cur $base" | awk '{if ($2==0) print 0; else printf "%.1f", ($1-$2)/$2*100}')
    awk -v p="$pct" -v t="$threshold_pct" 'BEGIN { exit !(p > t) }' && \
      _regress="$_regress | $name +${pct}% (baseline $base, current $cur, cap ${threshold_pct}%)"
  fi
}

_check "LCP" "$_lcp" "$_b_lcp" 10
_check "CLS" "$_cls" "$_b_cls" 0.05 1
_check "TBT" "$_tbt" "$_b_tbt" 10

if [ -n "$_regress" ]; then
  hook_stop_block "Core Web Vitals regression detected:${_regress}. Run /qa to inspect, fix the regression, or update baseline explicitly. [ETHOS: Tests Gate Everything]"
fi

exit 0
