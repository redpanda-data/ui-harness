#!/bin/bash
set -eo pipefail

# PreToolUse Bash: warn (never deny) on commands that blow up token cost.
# Complements llm-truncate.sh (post-output cap). This fires pre-execution
# so the model sees the nudge before it pays the cost.
#
# Every nudge also logs to ~/.claude/hook-metrics/bash-drains.jsonl via
# _hook_log_bash_drain so we can measure fire rate against baseline.

source "$(dirname "$0")/source-hook-lib.sh" 2>/dev/null || true
hook_parse_bash

nudge=""

_fire() {
  # $1 = drain_type, $2 = nudge text appended to $nudge
  local dtype="$1" text="$2"
  nudge="$nudge | $text"
  if command -v _hook_log_bash_drain >/dev/null 2>&1; then
    _hook_log_bash_drain "$dtype" "$command" 0
  fi
}

# NOTE: nudge-find, nudge-git-log, nudge-cat-artifact, nudge-grep-root removed
# 2026-04-27 — duplicates of CLAUDE.md "Bash Discipline" section. Model honors
# the rule from CLAUDE.md context; per-call advisory was paying tokens for
# behaviour the model already exhibited. Kept rules below are non-obvious or
# repo-specific (not in CLAUDE.md). Re-add via git history if /hook-audit
# shows regression in catch rate.

# git commit without --quiet when lefthook/husky present
# Lefthook/Ultracite pre-commit output (~26k chars per commit) is the #1
# measured bash drain. --quiet suppresses the hook output without
# disabling the hook itself.
if echo "$command" | grep -qE '\bgit +commit\b' && \
   ! echo "$command" | grep -qE '(\-\-quiet|\s-q\b)'; then
  _repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  if [ -n "$_repo_root" ] && \
     { [ -f "$_repo_root/lefthook.yml" ] || [ -f "$_repo_root/lefthook.yaml" ] || [ -d "$_repo_root/.husky" ]; }; then
    _fire "nudge-git-commit" "git commit without --quiet in a lefthook/husky repo: pre-commit output spams tokens. Add --quiet (keeps hooks running, hides their logs)."
  fi
fi

# rtk proxy nudge: advisory-only. Suggest `rtk <cmd>` prefix for output-heavy
# commands that rtk has a filter for (60-90% token cut per rtk gain measurements).
# Fail-open: silent if rtk not installed (rtk-install-check.sh nudges separately).
# Skip when already rtk-prefixed or when auto-rewrite (rtk-rewrite.sh) is wired.
if command -v rtk >/dev/null 2>&1 && ! echo "$command" | grep -qE '^[[:space:]]*rtk[[:space:]]'; then
  _rtk_suggest=""
  case "$command" in
    *"git log"*|*"git status"*|*"git diff"*|*"git show"*|*"git push"*|*"git branch"*|*"git stash"*)
      _rtk_suggest="rtk git ..." ;;
    *"gh pr"*|*"gh api"*|*"gh issue"*|*"gh run"*|*"gh repo"*|*"gh release"*)
      _rtk_suggest="rtk gh ..." ;;
    *"cargo test"*|*"pytest"*|*"bun test"*|*"vitest"*|*"jest"*)
      _rtk_suggest="rtk test ..." ;;
    *"kubectl "*) _rtk_suggest="rtk kubectl ..." ;;
    *"docker "*)  _rtk_suggest="rtk docker ..." ;;
    *"pnpm "*)    _rtk_suggest="rtk pnpm ..." ;;
    *"aws "*)     _rtk_suggest="rtk aws ..." ;;
    *"psql "*)    _rtk_suggest="rtk psql ..." ;;
  esac
  if [ -n "$_rtk_suggest" ]; then
    _fire "nudge-rtk" "prefix with rtk for auto-compression (60-90% token cut per rtk gain): $_rtk_suggest"
  fi
fi

# gh with --json but no --jq / pipe filter
# Measured: gh pr view/api with --json and no filter averaged 6.7k chars,
# 3 calls hit the 30k output cap on the same PR in the sample.
if echo "$command" | grep -qE '\bgh +(pr +view|api|pr +list|issue +view|run +view|repo +view)\b' && \
   echo "$command" | grep -qE '\-\-json\b' && \
   ! echo "$command" | grep -qE '(\-\-jq\b|\| *jq\b|\| *head\b|\| *wc\b|\| *tail\b)'; then
  _fire "nudge-gh-jq" "gh --json without --jq/pipe: returns full blob (often >10k chars). Add --jq '.field' or pipe to jq/head."
fi

# Repeat-command detection: same command run twice in a session = wasted tokens.
# Measured: same gh api fired 4x in one session, same README fetch 3x.
# Uses md5 of the raw command string; session-scoped state.
if [ -n "${_hook_session_dir:-}" ] && [ -d "$_hook_session_dir" ]; then
  _seen_file="$_hook_session_dir/bash-cmd-seen"
  # Hash the command. md5 (macOS) or md5sum (linux). Silent fallback.
  _cmd_hash=""
  if command -v md5 >/dev/null 2>&1; then
    _cmd_hash=$(printf '%s' "$command" | md5 2>/dev/null | cut -c1-16)
  elif command -v md5sum >/dev/null 2>&1; then
    _cmd_hash=$(printf '%s' "$command" | md5sum 2>/dev/null | cut -c1-16)
  fi
  # Only flag commands that are worth caching — skip trivial ones.
  # Heuristic: commands with `gh api`, `gh pr view`, `curl`, `fetch`, longer than 40 chars.
  if [ -n "$_cmd_hash" ] && [ ${#command} -gt 40 ] && \
     echo "$command" | grep -qE '(\bgh +(api|pr +view|issue +view|run +view)\b|\bcurl\b|\bwget\b|\btaskw\b|\bbun +run\b)'; then
    if [ -f "$_seen_file" ] && grep -q "^${_cmd_hash}\$" "$_seen_file" 2>/dev/null; then
      _fire "nudge-repeat-cmd" "Command already ran in this session — output still available via /tmp/claude-bash-logs/ or earlier tool_result. Consider re-using instead of re-fetching."
    fi
    echo "$_cmd_hash" >> "$_seen_file" 2>/dev/null || true
  fi
fi

[ -z "$nudge" ] && exit 0

echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"[bash-verbose]$nudge\"}}" >&2
exit 0
