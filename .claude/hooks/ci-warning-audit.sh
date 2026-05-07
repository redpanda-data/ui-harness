#!/bin/bash
set -eo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

# Stop hook: green-CI warning audit.
# "Green != done in CI either". When PR CI is all SUCCESS, fetch the run logs
# and scan for curated warning patterns (deprecations, console errors,
# skipped tests, etc). Surface findings as a systemMessage (hook_warn, not
# hook_stop_block) so the agent remediates without being hostage-held.
#
# Gates:
#   - gh CLI available
#   - feature branch (not main/master)
#   - session touched code
#   - PR exists for branch
#   - all CI checks SUCCESS (not pending, not failing — those are handled
#     by lifecycle-stop.sh)
#   - not already audited for this SHA (cached in session dir)
#
# Cost: one `gh run view --log` fetch per new SHA, piped directly to grep.
# Skip via env: CI_WARNING_AUDIT=0

source "$(dirname "$0")/../../shared/hook-lib.sh" 2>/dev/null || true

[ "${CI_WARNING_AUDIT:-1}" = "0" ] && exit 0

command -v gh &>/dev/null || exit 0

branch=$(git branch --show-current 2>/dev/null || true)
case "$branch" in
  main|master|develop|"") exit 0 ;;
esac

hook_has_session_tracking 2>/dev/null || exit 0

_touched_file="$_hook_session_dir/session-touched-files"
[ -f "$_touched_file" ] && [ -s "$_touched_file" ] || exit 0

pr_number=$(gh pr list --head "$branch" --json number --jq '.[0].number' 2>/dev/null || true)
[ -n "$pr_number" ] || exit 0

# Only audit when CI is fully green. Pending/failing → defer to lifecycle-stop.
pr_data=$(gh pr view "$pr_number" --json statusCheckRollup,headRefOid 2>/dev/null || true)
[ -n "$pr_data" ] || exit 0

ci_states=$(echo "$pr_data" | jq -r '.statusCheckRollup[]?.state // empty' 2>/dev/null || true)
[ -n "$ci_states" ] || exit 0
echo "$ci_states" | grep -qiE 'FAILURE|ERROR|PENDING|EXPECTED|QUEUED|IN_PROGRESS' && exit 0
echo "$ci_states" | grep -qi 'SUCCESS' || exit 0

sha=$(echo "$pr_data" | jq -r '.headRefOid // empty' 2>/dev/null)
[ -n "$sha" ] || exit 0

# Per-SHA cache — do not re-audit the same commit
_cache="$_hook_session_dir/ci-warning-audit.${sha}.done"
[ -f "$_cache" ] && exit 0

# Find the run that produced this SHA
run_id=$(gh run list --branch "$branch" --limit 5 --json databaseId,headSha,status,conclusion \
  --jq "[.[] | select(.headSha == \"$sha\") | select(.status == \"completed\") | select(.conclusion == \"success\") | .databaseId][0]" \
  2>/dev/null || true)
[ -n "$run_id" ] && [ "$run_id" != "null" ] || { touch "$_cache" 2>/dev/null; exit 0; }

# Build combined pattern. Curated; favor precision over recall to avoid noise.
_pat='DeprecationWarning:|ExperimentalWarning:|\(node:[0-9]+\) [A-Z][a-zA-Z]*Warning|UnhandledPromiseRejection|Unhandled promise rejection|Unhandled Rejection|Unhandled Errors|MaxListenersExceededWarning|PossibleEventEmitterMemoryLeak|Warning: An update to .* inside a test was not wrapped in act|Warning: ReactDOM\.render|Warning: Each child in a list should have a unique "key"|Warning: validateDOMNesting|Warning: Failed prop type|Warning: Cannot update a component .* while rendering|Warning: Received .* for a non-boolean attribute|npm WARN deprecated|bun install .*warn|peer dep missing|\[vitest\].*warn|playwright.*warning|Test ended with interrupted|@ts-expect-error|@ts-ignore'

# Fetch + grep with timeout. `gh run view --log` can be huge; pipe streams it.
_tmp=$(mktemp 2>/dev/null) || exit 0
trap 'rm -f "$_tmp" 2>/dev/null' EXIT

if command -v timeout &>/dev/null; then
  _runner=(timeout 45)
elif command -v gtimeout &>/dev/null; then
  _runner=(gtimeout 45)
else
  _runner=()
fi

"${_runner[@]}" gh run view "$run_id" --log 2>/dev/null \
  | grep -E "$_pat" 2>/dev/null \
  | head -30 > "$_tmp" || true

# Always mark audited so we don't retry on the same SHA
touch "$_cache" 2>/dev/null

if [ ! -s "$_tmp" ]; then
  _hook_log_entry "info" "ci-clean" ci-warning-audit
  exit 0
fi

_count=$(wc -l < "$_tmp" | tr -d ' ')
_sample=$(head -6 "$_tmp" | cut -c1-200)

_msg="CI green on PR #${pr_number} but run ${run_id} has ${_count} warning line(s):
${_sample}
Fetch full: gh run view ${run_id} --log | grep -E 'Warning|Deprecation|Unhandled'
Fix at source. Green is not the bar — zero warnings is."

_hook_log_entry "warn" "ci-warnings" ci-warning-audit
hook_warn "$_msg" "ci-warnings"
