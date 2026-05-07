#!/bin/bash
set -eo pipefail

# Stop hook: enforce development lifecycle completion with auto-remediation.
# Ensures code changes are tested, simplified, pushed, PR'd, CI-checked,
# and review-requested. Instead of just blocking, prescribes exact actions
# so Claude auto-follows and retries.
#
# Lifecycle gates (sequential):
#   0. Untested code? → prescribe: run /tdd
#   1. Uncommitted changes? → prescribe: run /commit-push
#   2. Unpushed commits? → prescribe: git push
#   3. No PR? → prescribe: gh pr create
#   4. CI failing? → prescribe: fix and push
#   5. CI pending? → prescribe: monitor with Monitor tool
#   6. No reviewer? → prescribe: request review
#   All pass → allow finish

source "$(dirname "$0")/../../shared/hook-lib.sh" 2>/dev/null || true

# ── Quick exits (most sessions hit one of these) ────────────────

# Need session tracking to know what we changed
if ! hook_has_session_tracking 2>/dev/null; then
  exit 0
fi

# Need gh CLI for PR/CI operations
if ! command -v gh &>/dev/null; then
  exit 0
fi

# Only enforce on feature branches
branch=$(git branch --show-current 2>/dev/null || true)
case "$branch" in
  main|master|develop|"") exit 0 ;;
esac

# Only enforce if this session touched code files (even if already committed)
_touched_file="$_hook_session_dir/session-touched-files"
if [ ! -f "$_touched_file" ] || [ ! -s "$_touched_file" ]; then
  exit 0
fi
_session_code=$(grep -E '\.(ts|tsx)$' "$_touched_file" 2>/dev/null || true)
# Defense-in-depth: drop any path that points at a secondary worktree
# (subagent scope), lives outside the current worktree (sibling
# worktree / session-id collision), no longer exists, or is not part
# of the current branch diff (stale tracker entry from a prior session,
# rolled-back edit, or subagent that never landed). Prevents false
# "untested source" blocks on sessions that did no real editing.
if [ -n "$_session_code" ] && type _hook_in_secondary_worktree &>/dev/null; then
  # Branch-local change set: files currently dirty OR committed since
  # branch-off. If a tracked entry isn't in this set, it's stale.
  _repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  _branch_changes=""
  for _base in origin/main origin/master main master; do
    if git rev-parse --verify "$_base" &>/dev/null; then
      _branch_changes=$(
        { git diff --name-only "$_base...HEAD" 2>/dev/null
          git diff --name-only HEAD 2>/dev/null
          git ls-files --others --exclude-standard 2>/dev/null; } | sort -u
      )
      break
    fi
  done
  _filtered=""
  while IFS= read -r _p; do
    [ -z "$_p" ] && continue
    [ -e "$_p" ] || continue
    if _hook_in_secondary_worktree "$_p"; then
      continue
    fi
    if type _hook_file_outside_current_worktree &>/dev/null \
      && _hook_file_outside_current_worktree "$_p"; then
      continue
    fi
    if [ -n "$_branch_changes" ] && [ -n "$_repo_root" ]; then
      # Resolve symlinks before stripping (macOS /var → /private/var)
      _p_real=$(cd "$(dirname "$_p")" 2>/dev/null && echo "$(pwd -P)/$(basename "$_p")" || echo "$_p")
      _rel="${_p_real#"$_repo_root"/}"
      if ! grep -Fxq -- "$_rel" <<< "$_branch_changes"; then
        continue
      fi
    fi
    _filtered="${_filtered}${_p}"$'\n'
  done <<< "$_session_code"
  _session_code="${_filtered%$'\n'}"
fi
if [ -z "$_session_code" ]; then
  exit 0
fi

# ── Step 0: Coverage gap analysis ──────────────────────────────
# Run vitest coverage on session-changed source files. If coverage
# is below threshold, block with specific gap report. If vitest/
# coverage not available, fall back to session-level test check.

_new_source=false
_has_tests=false
_source_files=""
: "${_repo_root:=$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"

# Newly-added on this branch = diff-filter=A vs default base + untracked.
# Edits to pre-existing files do NOT count as "new source" — those files
# may already have committed tests, and conflict-resolution Edits during
# rebase would otherwise trip a false "untested source" block.
_added_on_branch=""
_added_base_found=false
for _base in origin/main origin/master main master; do
  if git rev-parse --verify "$_base" &>/dev/null; then
    _added_base_found=true
    _added_on_branch=$(
      { git diff --name-only --diff-filter=A "$_base...HEAD" 2>/dev/null
        git ls-files --others --exclude-standard 2>/dev/null; } | sort -u
    )
    break
  fi
done

while IFS= read -r _src_file; do
  [ -z "$_src_file" ] && continue
  case "$_src_file" in
    *.test.*|*.spec.*)
      _has_tests=true
      continue ;;
    *.gen.*|*_pb.*|*_connectquery.*)
      continue ;;
  esac
  # Vendor/registry files: can't write colocated tests (vendor-file-check
  # blocks edits there), so don't enforce colocated-test rule on them.
  if echo "$_src_file" | grep -qE '/(redpanda-ui|components/ui/registry|vendor|fumadocs)/'; then
    continue
  fi
  if echo "$_src_file" | grep -qE '/(routes|components|hooks|features|modules|pages|views)/'; then
    # Only flag as new-source if file was ADDED on this branch
    # (not merely edited). Falls back to flagging only when base lookup
    # failed entirely — an empty added-set means "nothing new", skip.
    if [ "$_added_base_found" = true ] && [ -n "$_repo_root" ]; then
      _sf_real=$(cd "$(dirname "$_src_file")" 2>/dev/null && echo "$(pwd -P)/$(basename "$_src_file")" || echo "$_src_file")
      _sf_rel="${_sf_real#"$_repo_root"/}"
      grep -Fxq -- "$_sf_rel" <<< "$_added_on_branch" || continue
    fi
    _new_source=true
    _source_files="${_source_files} ${_src_file}"
  fi
done <<< "$_session_code"

# Adjacent-test fallback: if every new source file has a committed
# or adjacent test on disk (prior-session work, parallel worktree,
# or tests in __tests__/), treat the session as tested. Prevents the
# "no test files written this session" false-flag on worktree /
# multi-session flows where the session may only touch source.
_adjacent_tests_for_all=true
for _sf in $_source_files; do
  _sf=${_sf# }
  [ -z "$_sf" ] && continue
  _sf_base=${_sf%.*}
  _sf_ext=${_sf##*.}
  _sf_dir=$(dirname "$_sf")
  _sf_name=$(basename "$_sf" ".$_sf_ext")
  # Co-located / __tests__ adjacent, any ts/tsx ext (cross-ext OK:
  # Foo.tsx + Foo.test.ts is a valid pattern for hooks/utils).
  _found_adjacent=false
  for _alt_ext in ts tsx; do
    if [ -f "${_sf_base}.test.${_alt_ext}" ] || \
       [ -f "${_sf_base}.spec.${_alt_ext}" ] || \
       [ -f "${_sf_base}.browser.test.${_alt_ext}" ] || \
       [ -f "${_sf_dir}/__tests__/${_sf_name}.test.${_alt_ext}" ] || \
       [ -f "${_sf_dir}/__tests__/${_sf_name}.spec.${_alt_ext}" ] || \
       [ -f "${_sf_dir}/__tests__/${_sf_name}.browser.test.${_alt_ext}" ]; then
      _found_adjacent=true
      break
    fi
  done
  if [ "$_found_adjacent" = true ]; then
    continue
  fi
  # Global branch scan: any test file anywhere with matching basename.
  # Covers prior-session tests in src/__tests__, test/, etc. Includes
  # untracked files (--others) — session may have written the test but
  # not yet staged it.
  _globs=(
    "**/${_sf_name}.test.ts" "**/${_sf_name}.test.tsx"
    "**/${_sf_name}.spec.ts" "**/${_sf_name}.spec.tsx"
    "**/${_sf_name}.browser.test.ts" "**/${_sf_name}.browser.test.tsx"
  )
  if {
    git ls-files -- "${_globs[@]}" 2>/dev/null
    git ls-files --others --exclude-standard -- "${_globs[@]}" 2>/dev/null
  } | grep -q .; then
    continue
  fi
  _adjacent_tests_for_all=false
  break
done
if [ "$_adjacent_tests_for_all" = true ] && [ -n "$_source_files" ]; then
  _has_tests=true
fi

# Skip if no new source files in testable dirs
if [ "$_new_source" = false ]; then
  : # no enforcement needed
elif command -v vitest &>/dev/null || [ -x "./node_modules/.bin/vitest" ]; then
  # Try coverage analysis — run related tests with coverage
  _vitest_bin="vitest"
  [ -x "./node_modules/.bin/vitest" ] && _vitest_bin="./node_modules/.bin/vitest"

  _cov_json=$(mktemp -d)/coverage
  _cov_report=""
  _cov_report=$($_vitest_bin run --coverage.enabled --coverage.reporter=json \
    --coverage.reportsDirectory="$_cov_json" \
    --reporter=json --run 2>/dev/null || true)

  _cov_summary="$_cov_json/coverage-summary.json"
  if [ -f "$_cov_summary" ]; then
    # Check coverage for each session-changed source file
    _low_coverage=""
    _threshold=60  # line coverage threshold

    for _sf in $_source_files; do
      # Try absolute and relative path keys in coverage JSON
      _abs_path=$(cd "$(dirname "$_sf")" 2>/dev/null && echo "$(pwd -P)/$(basename "$_sf")" || echo "$_sf")
      _pct=$(jq -r --arg f "$_abs_path" '.[$f].lines.pct // empty' "$_cov_summary" 2>/dev/null || true)
      [ -z "$_pct" ] && _pct=$(jq -r --arg f "$_sf" '.[$f].lines.pct // empty' "$_cov_summary" 2>/dev/null || true)

      if [ -n "$_pct" ] && [ "$_pct" != "100" ]; then
        _pct_int=${_pct%.*}
        if [ "${_pct_int:-0}" -lt "$_threshold" ]; then
          _low_coverage="${_low_coverage}\n  $(basename "$_sf"): ${_pct}% lines covered"
        fi
      fi
    done

    if [ -n "$_low_coverage" ]; then
      hook_stop_block "Coverage gaps found in session-changed files:${_low_coverage}\nRun /tdd to analyze coverage gaps and write tests targeting uncovered code. Then run /simplify."
    fi

    rm -rf "$(dirname "$_cov_json")" 2>/dev/null || true
  else
    # Coverage run failed or not configured. Without coverage output we
    # can't prove tests are missing — only that we couldn't verify. Warn
    # (exit 0) rather than block; the nudge still surfaces but the
    # session isn't hostage to a broken tooling path.
    if [ "$_has_tests" = false ]; then
      hook_warn "New source files on branch with no adjacent / branch-scoped tests (coverage analysis unavailable). Consider /tdd to write tests, then /simplify."
    fi
  fi
else
  # No vitest available — warn only. Hook can't verify coverage; a hard
  # block here would punish the user for a repo without the test tool.
  if [ "$_has_tests" = false ]; then
    hook_warn "New source files on branch with no adjacent / branch-scoped tests. Consider /tdd to write tests, then /simplify."
  fi
fi

# ── Step 0b: Uncommitted changes → commit ──────────────────────
# Session-scoped: only block on dirty files this session actually touched.
# Pre-existing dirty work (dep-bumps, WIP from prior sessions, untracked
# scratch files) must not hostage-hold the Stop hook — that was the
# original "hook is super noisy" bug.
_session_dirty=$(hook_session_changed_files)
if [ -n "$_session_dirty" ]; then
  _dirty_count=$(echo "$_session_dirty" | wc -l | tr -d ' ')
  hook_stop_block "${_dirty_count} uncommitted file(s) from this session. Run /commit-push to commit and push. Then retry."
fi

# Need a remote to push to
if ! git remote get-url origin &>/dev/null 2>&1; then
  exit 0
fi

# ── Step 1: Unpushed commits → push ─────────────────────────────

unpushed=""
if git rev-parse --verify "origin/$branch" &>/dev/null 2>&1; then
  unpushed=$(git log "origin/$branch..HEAD" --oneline 2>/dev/null || true)
else
  # Branch never pushed — all commits since default branch are unpushed
  for base in origin/main origin/master; do
    if git rev-parse --verify "$base" &>/dev/null 2>&1; then
      unpushed=$(git log --oneline "$base..HEAD" 2>/dev/null || true)
      break
    fi
  done
fi

if [ -n "$unpushed" ]; then
  _count=$(echo "$unpushed" | wc -l | tr -d ' ')
  hook_stop_block "${_count} unpushed on '$branch'. Run: git push -u origin $branch — then retry."
fi

# ── Step 2: No PR → create one ──────────────────────────────────

pr_number=$(gh pr list --head "$branch" --json number --jq '.[0].number' 2>/dev/null || true)

if [ -z "$pr_number" ]; then
  hook_stop_block "No PR for '$branch'. Create one NOW: gh pr create --fill — then retry."
fi

# ── Step 3 & 4: CI status ───────────────────────────────────────

pr_data=$(gh pr view "$pr_number" --json statusCheckRollup,reviewRequests 2>/dev/null || true)
ci_states=$(echo "$pr_data" | jq -r '.statusCheckRollup[]?.state // empty' 2>/dev/null || true)

if [ -n "$ci_states" ]; then
  if echo "$ci_states" | grep -qi "FAILURE\|ERROR"; then
    hook_stop_block "CI FAILING on PR #$pr_number. Read failures with: gh pr checks $pr_number — fix the issues, commit, push. Then use Monitor tool on 'gh pr checks $pr_number --watch' to stream results. Do not stop until CI green."
  fi

  # CI pending is a wait condition, not a code-quality issue. Emit a
  # warn (exit 0) instead of blocking: hostage-holding the session
  # across long CI runs is noise, and the user can stream status with
  # Monitor if they actively want to watch. Failures still block.
  if echo "$ci_states" | grep -qi "PENDING\|EXPECTED\|QUEUED\|IN_PROGRESS"; then
    if ! echo "$ci_states" | grep -qi "SUCCESS"; then
      hook_warn "CI still running on PR #$pr_number. Stream with: gh pr checks $pr_number --watch (via Monitor tool) if you want live status."
    fi
  fi
fi

# ── Step 5: Review requested → assign reviewer ──────────────────

reviewer_count=$(echo "$pr_data" | jq -r '.reviewRequests | length' 2>/dev/null || echo "0")

if [ "$reviewer_count" = "0" ] || [ -z "$reviewer_count" ]; then
  hook_stop_block "CI green but no reviewer on PR #$pr_number. Request review NOW: gh pr edit $pr_number --add-reviewer <user> — then retry."
fi

# ── Lifecycle complete ───────────────────────────────────────────
exit 0
