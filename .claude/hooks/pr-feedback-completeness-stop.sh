#!/bin/bash
set -eo pipefail

# Stop hook: enforce every review thread addressed before session exit.
#
# When a human (or the code-reviewer agent on behalf of a human) leaves
# feedback on the PR for the current branch, the AI must reply to AND
# resolve every thread before stopping. No stones unturned before the
# human gets back in the loop.
#
# Checks (in order):
#   1. Unresolved, non-outdated review threads with at least one
#      non-bot comment → block with remediation prompt.
#   2. Reviews in CHANGES_REQUESTED state newer than the last push →
#      block with remediation prompt.
#
# Escape hatches:
#   PR_FEEDBACK_ENFORCEMENT=off  — fully disable (use sparingly)
#   PR_FEEDBACK_MOCK_PR=<num|none>      — eval-only: bypass detection
#   PR_FEEDBACK_MOCK_THREADS=<json>     — eval-only: canned threads
#   PR_FEEDBACK_MOCK_REVIEWS=<json>     — eval-only: canned reviews

source "$(dirname "$0")/source-hook-lib.sh" 2>/dev/null || true

# ── Global disable ───────────────────────────────────────────────
[ "${PR_FEEDBACK_ENFORCEMENT:-on}" = "off" ] && exit 0

# ── Prereqs ──────────────────────────────────────────────────────
command -v jq &>/dev/null || exit 0

# ── PR detection (mockable) ──────────────────────────────────────
if [ -n "${PR_FEEDBACK_MOCK_PR:-}" ]; then
  pr_number="$PR_FEEDBACK_MOCK_PR"
  [ "$pr_number" = "none" ] && exit 0
  owner="mock"
  repo="mock"
else
  command -v gh &>/dev/null || exit 0
  branch=$(git branch --show-current 2>/dev/null || true)
  case "$branch" in
    main|master|develop|"") exit 0 ;;
  esac
  git remote get-url origin &>/dev/null 2>&1 || exit 0
  pr_number=$(gh pr list --head "$branch" --json number --jq '.[0].number' 2>/dev/null || true)
  [ -z "$pr_number" ] && exit 0
  owner_repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
  owner="${owner_repo%/*}"
  repo="${owner_repo#*/}"
  { [ -z "$owner" ] || [ -z "$repo" ]; } && exit 0
fi

# ── Fetch review threads (mockable) ──────────────────────────────
if [ -n "${PR_FEEDBACK_MOCK_THREADS:-}" ]; then
  threads_json="$PR_FEEDBACK_MOCK_THREADS"
else
  threads_json=$(gh api graphql \
    -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){nodes{isResolved isOutdated comments(first:5){nodes{author{login} body}}}}}}}' \
    -f o="$owner" -f r="$repo" -F n="$pr_number" 2>/dev/null || echo "")
fi

unresolved_count=0
unresolved_summary=""
if [ -n "$threads_json" ]; then
  unresolved_count=$(echo "$threads_json" | jq -r '
    [.data.repository.pullRequest.reviewThreads.nodes[]?
     | select(.isResolved == false)
     | select(.isOutdated != true)
     | select([.comments.nodes[]? | select(((.author.login // "") | test("\\[bot\\]$")) | not)] | length > 0)]
    | length' 2>/dev/null || echo "0")
  unresolved_count=${unresolved_count:-0}

  if [ "$unresolved_count" -gt 0 ]; then
    unresolved_summary=$(echo "$threads_json" | jq -r '
      [.data.repository.pullRequest.reviewThreads.nodes[]?
       | select(.isResolved == false)
       | select(.isOutdated != true)
       | select([.comments.nodes[]? | select(((.author.login // "") | test("\\[bot\\]$")) | not)] | length > 0)
       | "  • " + ((.comments.nodes[0].author.login // "?")) + ": " + ((.comments.nodes[0].body // "") | gsub("\\n"; " ") | gsub("\\r"; "") | .[:120])]
      | .[:10] | join("\n")' 2>/dev/null || echo "")
  fi
fi

# ── Fetch CHANGES_REQUESTED reviews (mockable) ───────────────────
if [ -n "${PR_FEEDBACK_MOCK_REVIEWS:-}" ]; then
  reviews_json="$PR_FEEDBACK_MOCK_REVIEWS"
else
  reviews_json=$(gh pr view "$pr_number" --json reviews 2>/dev/null || echo "")
fi

pending_changes_count=0
if [ -n "$reviews_json" ]; then
  # CHANGES_REQUESTED reviews with no later APPROVED or DISMISSED from same author.
  pending_changes_count=$(echo "$reviews_json" | jq -r '
    [.reviews
     | group_by(.author.login // "?")
     | map(sort_by(.submittedAt) | last)
     | .[]?
     | select(.state == "CHANGES_REQUESTED")]
    | length' 2>/dev/null || echo "0")
  pending_changes_count=${pending_changes_count:-0}
fi

# ── Decision ─────────────────────────────────────────────────────
if [ "$unresolved_count" -gt 0 ] || [ "$pending_changes_count" -gt 0 ]; then
  msg="PR #$pr_number has unresolved review feedback. Address ALL before stopping — no stones unturned before handing back to human."

  if [ "$unresolved_count" -gt 0 ]; then
    msg="$msg
$unresolved_count unresolved review thread(s):
$unresolved_summary"
  fi

  if [ "$pending_changes_count" -gt 0 ]; then
    msg="$msg
$pending_changes_count reviewer(s) still in CHANGES_REQUESTED state."
  fi

  msg="$msg

Run /resolve-pr-feedback to triage, fix, reply, and resolve every thread. Push, re-monitor CI. Do not stop until every thread is resolved and no CHANGES_REQUESTED remain. If a comment is not actionable, reply explaining why and resolve."

  hook_stop_block "$msg"
fi

exit 0
