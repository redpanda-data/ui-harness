#!/bin/bash
set -eo pipefail

# PreToolUse(Bash): block GitHub PR review-thread replies by default.
#
# Why: replying inside an existing PR discussion/thread can make the agent
# carry on a conversation as the authenticated human. Keep existing top-level
# PR behavior (for example `gh pr comment ... "@claude review"`), but stop
# threaded replies unless the user explicitly opts into that exact action.
#
# Escape hatch: prefix the command with CLAUDE_ALLOW_PR_THREAD_REPLY=1 after
# the user explicitly asks for a PR thread reply.

source "$(dirname "$0")/source-hook-lib.sh" 2>/dev/null || true

hook_parse_bash

case "$command" in
  CLAUDE_ALLOW_PR_THREAD_REPLY=1\ *|*" CLAUDE_ALLOW_PR_THREAD_REPLY=1 "*) exit 0 ;;
esac

_compact=$(printf '%s' "$command" | tr '\n\r\t' '   ' | sed -E 's/[[:space:]]+/ /g')

_is_thread_reply=false
_reason=""

# REST: create a reply for a PR review comment.
# POST /repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies
if echo "$_compact" | grep -Eq '(^|[;&|[:space:]])gh api '; then
  if echo "$_compact" | grep -Eq 'repos/[^[:space:]]+/[^[:space:]]+/pulls/[0-9]+/comments/[0-9]+/replies'; then
    if echo "$_compact" | grep -Eq '(^|[[:space:]])(-f|--field|-F|--raw-field|--method[=[:space:]]*(POST|PATCH|PUT)|-X[[:space:]]*(POST|PATCH|PUT))([[:space:]]|$)'; then
      _is_thread_reply=true
      _reason="gh api is creating a PR review comment reply"
    fi
  fi

  # GraphQL: addPullRequestReviewThreadReply mutation.
  if echo "$_compact" | grep -qi 'addPullRequestReviewThreadReply'; then
    _is_thread_reply=true
    _reason="gh api graphql is adding a PR review thread reply"
  fi
fi

if [ "$_is_thread_reply" = true ]; then
  hook_deny "Refusing PR thread reply: $_reason. Agents may keep top-level PR behavior, but must not reply inside existing PR discussions/threads in your name. If you explicitly approved this exact reply, rerun with CLAUDE_ALLOW_PR_THREAD_REPLY=1 prefixed." "github-write-guard"
fi

exit 0
