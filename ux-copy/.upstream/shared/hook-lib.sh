#!/bin/bash
# Shared library for Claude Code and Codex hook scripts.
# Source this at the top of PostToolUse and PreToolUse hooks.
# Works with both harnesses — auto-detects protocol differences.
#
# Usage in PostToolUse (Edit|Write) hooks:
#   source "$(dirname "$0")/../../shared/hook-lib.sh"
#   hook_parse_edit_write        # sets: file_path
#   hook_filter_extensions "ts|tsx"
#   hook_get_added_lines         # sets: added_lines
#   ... your checks ...
#   hook_block "Error message"
#
# Usage in PreToolUse (Bash) hooks:
#   source "$(dirname "$0")/../../shared/hook-lib.sh"
#   hook_parse_bash              # sets: command
#   ... your checks ...
#   hook_deny "Error message"
#
# Environment variables:
#   HOOKS_FAIL_CLOSED=1  — treat hook errors (exit 1) as blocks (exit 2)
#                          instead of silently passing. Catches misconfiguration.

# ── Debug mode ───────────────────────────────────────────────────
# Set HOOK_DEBUG=1 to log every decision point to session temp dir.
# Useful for diagnosing hook misfires.
#   tail -f /tmp/hook-session-*/debug.log

_hook_debug_enabled="${HOOK_DEBUG:-}"

_hook_debug() {
  if [ -n "$_hook_debug_enabled" ]; then
    echo "[$(date +%H:%M:%S)] $(basename "$0"): $*" >> "$_hook_session_dir/debug.log" 2>/dev/null || true
  fi
}

# ── Default ERR trap: crash → exit 0, never non-zero without stderr ──
# Hooks must either block cleanly (exit 2 + JSON stderr) or pass (exit 0).
# An unhandled error must NOT produce a mysterious non-zero exit.
# HOOKS_FAIL_CLOSED=1 overrides: crashes become blocks instead of silent passes.

if [ "${HOOKS_FAIL_CLOSED:-}" = "1" ]; then
  trap '_fc_msg="Hook script error in $(basename "$0"). Check hook configuration (missing _hook-lib.sh? jq not installed?)."; echo "{\"suppressOutput\":true,\"systemMessage\":\"$_fc_msg\"}" >&2; exit 2' ERR
else
  trap '_hook_debug "ERR trap fired (line $LINENO, exit $?) — exiting 0 to avoid crash"; exit 0' ERR
fi

# ── Session state directory ───────────────────────────────────────
# All session temp files in one directory for clean management.
# Cleanup happens in SessionStart (session-env.sh).
# Works with both Claude Code (CLAUDE_SESSION_ID env var) and
# Codex (session_id in stdin JSON, extracted after first parse).
#
# Fallback when neither env var is set: deterministic id derived from
# the current worktree root + PID. Without this, two terminals on
# different worktrees can collide on bare $$ after PID wrap or if the
# harness launched them without an env var, causing cross-worktree
# hook state to pool into one /tmp dir.

if [ -n "${CLAUDE_SESSION_ID:-}" ]; then
  _hook_session_id="$CLAUDE_SESSION_ID"
elif [ -n "${CODEX_SESSION_ID:-}" ]; then
  _hook_session_id="$CODEX_SESSION_ID"
else
  _hook_wt_fallback=$(git rev-parse --show-toplevel 2>/dev/null || echo "/tmp")
  if command -v md5 >/dev/null 2>&1; then
    _hook_wt_hash=$(printf '%s' "$_hook_wt_fallback" | md5 2>/dev/null || echo "nohash")
  elif command -v md5sum >/dev/null 2>&1; then
    _hook_wt_hash=$(printf '%s' "$_hook_wt_fallback" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "nohash")
  else
    _hook_wt_hash="nohash"
  fi
  _hook_session_id="wt-${_hook_wt_hash}-$$"
fi
_hook_session_dir="/tmp/hook-session-${_hook_session_id}"
mkdir -p "$_hook_session_dir" 2>/dev/null || true

# Violation tracking
_hook_violations_file="$_hook_session_dir/violations"

_hook_track_violation() {
  local label="$1"
  echo "$label" >> "$_hook_violations_file" 2>/dev/null || true
}

_hook_default_rule() {
  printf '%s' "${_hook_current_check:-$(basename "$0" .sh)}"
}

_hook_collect_emit() {
  local severity="$1" rule="$2" message="$3"
  [ "${HOOK_COLLECT:-0}" = "1" ] || return 1
  [ -n "${HOOK_COLLECT_FILE:-}" ] || return 0
  message=${message//$'\n'/ }
  printf '%s|%s|%s\n' "$severity" "$rule" "$message" >> "$HOOK_COLLECT_FILE" 2>/dev/null || true
  return 0
}

_hook_skip_or_exit() {
  local collect_status="${1:-1}"
  if [ "${HOOK_COLLECT:-0}" = "1" ]; then
    return "$collect_status"
  fi
  exit 0
}

# ── Structured session log (JSONL) ──────────────────────────────
# Append one JSON line per hook decision. Used by metrics-summary-stop.sh
# and /hook-audit skill. Fails silently — never blocks a hook.
_hook_log_file="$_hook_session_dir/structured.jsonl"

_hook_log_entry() {
  local decision="$1" rule="$2" hook="${3:-${_hook_current_check:-$(basename "$0" .sh)}}" ms="${4:-}"
  local target="${file_path:-}"
  # Strip repo root for privacy — store relative path only
  if [ -n "$target" ]; then
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    target="${target#"$root"/}"
  fi
  if [ -n "$ms" ]; then
    printf '{"ts":%d,"hook":"%s","rule":"%s","decision":"%s","file":"%s","ms":%d}\n' \
      "$(date +%s)" "$hook" "$rule" "$decision" "$target" "$ms" \
      2>/dev/null >> "$_hook_log_file" || true
  else
    printf '{"ts":%d,"hook":"%s","rule":"%s","decision":"%s","file":"%s"}\n' \
      "$(date +%s)" "$hook" "$rule" "$decision" "$target" \
      2>/dev/null >> "$_hook_log_file" || true
  fi
}

# Comma-separated, explicit rule holdouts for model-release trials. A shadowed
# rule records what it would have emitted but never steers or blocks the model.
# Strict safety/permission tiers do not call this helper and cannot be shadowed.
_hook_rule_shadowed() {
  local rule="$1" configured=",${HOOK_SHADOW_RULES:-},"
  [ "$configured" != ",," ] || return 1
  case "$configured" in
    *,"$rule",*) return 0 ;;
    *) return 1 ;;
  esac
}

# ── Bash token-drain log (persistent, cross-session) ────────────
# One JSONL line per drain event: nudges fired by bash-verbose-guard
# and cap-hits recorded by llm-truncate. Used by scripts/bash-drain-report.sh
# to measure hook ROI against the 2026-04-19 baseline.
#
# Fields:
#   ts              unix seconds
#   session_id      hook session id (scrubbed)
#   drain_type      nudge-git-commit | nudge-gh-jq | nudge-repeat-cmd
#                   | nudge-find | nudge-git-log | nudge-cat-artifact
#                   | nudge-grep-root | cap_hit
#   cmd_snippet     first 120 chars of the command (ANSI-stripped)
#   bytes           cap_hit: actual bytes truncated; nudges: 0 (fire count proxy)
_hook_drain_log="${HOOK_METRICS_DIR:-${HOME}/.claude/hook-metrics}/bash-drains.jsonl"

_hook_log_bash_drain() {
  local drain_type="$1" cmd_snippet="$2" bytes="${3:-0}"
  [ "${HOOK_METRICS_DISABLED:-0}" = "1" ] && return 0
  mkdir -p "$(dirname "$_hook_drain_log")" 2>/dev/null || true
  # Trim + escape cmd_snippet for JSON. Cap length to keep log compact.
  cmd_snippet="${cmd_snippet:0:120}"
  local escaped_cmd
  if command -v jq >/dev/null 2>&1; then
    escaped_cmd=$(printf '%s' "$cmd_snippet" | jq -Rs . 2>/dev/null) || escaped_cmd='""'
  else
    escaped_cmd='"'${cmd_snippet//\"/\\\"}'"'
  fi
  printf '{"ts":%d,"session_id":"%s","drain_type":"%s","cmd_snippet":%s,"bytes":%d}\n' \
    "$(date +%s)" "$_hook_session_id" "$drain_type" "$escaped_cmd" "$bytes" \
    >> "$_hook_drain_log" 2>/dev/null || true
}

# ── Safe JSON string escape ──────────────────────────────────────
# Escapes text for embedding in JSON strings. Uses jq if available,
# falls back to sed. Never fails — returns escaped string or empty.
# Usage: escaped=$(_safe_json_escape "text with \"quotes\" and\nnewlines")

_safe_json_escape() {
  local input="$1"
  # Try jq first (produces a quoted JSON string like "foo\nbar")
  if command -v jq &>/dev/null; then
    printf '%s' "$input" | jq -Rs . 2>/dev/null && return 0
  fi
  # Fallback: manual escape with sed + awk (covers critical chars + newlines)
  # Works on macOS sed (BSD), GNU sed, and Git Bash/WSL
  local escaped
  escaped=$(printf '%s' "$input" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e $'s/\r/\\\\r/g' | awk '{if(NR>1) printf "\\n"; printf "%s",$0}')
  printf '"%s"' "$escaped"
}

# Cap a model-facing message. Codex forwards at most ~2,500 tokens of hook
# output per call (~10KB); Claude spills >10K chars to disk. 8000 chars keeps
# every emitter safely under both. Never cap machine-parsed payloads
# (updatedInput, updatedToolOutput) — only human/model prose.
_HOOK_MSG_MAX=8000
_hook_cap_msg() {
  local msg="$1"
  if [ "${#msg}" -gt "$_HOOK_MSG_MAX" ]; then
    printf '%s\n[truncated: message exceeded %d chars]' "$(printf '%s' "$msg" | cut -c1-$_HOOK_MSG_MAX)" "$_HOOK_MSG_MAX"
  else
    printf '%s' "$msg"
  fi
}

# ── Worktree detection helpers ───────────────────────────────────
# Two problems solved here:
#
# 1. Secondary-worktree detection (legacy): returns 0 if $1 lives in a
#    secondary git worktree (git-dir != git-common-dir). Used for
#    subagent isolation — subagents spawned via `Agent(isolation:
#    "worktree")` inherit the parent's CLAUDE_SESSION_ID, so their
#    PostToolUse hooks write to the parent session_dir.
#
# 2. Current-worktree drift: when N Claude Code terminals run on N
#    sibling worktrees of the same repo, `_hook_in_secondary_worktree`
#    cannot distinguish "my worktree" from "sibling worktree". The new
#    `_hook_file_outside_current_worktree` compares $1's toplevel to
#    the CURRENT terminal's cwd toplevel — catches sibling leakage too.

_hook_wt_root_cache=""
_hook_current_worktree_root() {
  if [ -z "$_hook_wt_root_cache" ]; then
    local r
    r=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
    if [ -n "$r" ]; then
      r=$(cd "$r" 2>/dev/null && pwd -P 2>/dev/null || echo "$r")
    fi
    _hook_wt_root_cache="${r:-NONE}"
  fi
  [ "$_hook_wt_root_cache" = "NONE" ] && return 1
  printf '%s' "$_hook_wt_root_cache"
}

_hook_in_secondary_worktree() {
  local f="$1" dir gd gc
  dir=$(dirname "$f" 2>/dev/null) || return 1
  [ -d "$dir" ] || return 1
  gd=$(git -C "$dir" rev-parse --git-dir 2>/dev/null) || return 1
  gc=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
  gd=$(cd "$dir" 2>/dev/null && cd "$gd" 2>/dev/null && pwd -P 2>/dev/null) || return 1
  gc=$(cd "$dir" 2>/dev/null && cd "$gc" 2>/dev/null && pwd -P 2>/dev/null) || return 1
  [ -n "$gd" ] && [ -n "$gc" ] && [ "$gd" != "$gc" ]
}

# True if $1 lives OUTSIDE the current terminal's worktree.
# Right gate for multi-terminal / multi-worktree sessions.
_hook_file_outside_current_worktree() {
  local f="$1"
  local current_root file_root dir
  current_root=$(_hook_current_worktree_root) || return 1
  dir=$(dirname "$f" 2>/dev/null) || return 1
  [ -d "$dir" ] || return 1
  file_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || return 1
  file_root=$(cd "$file_root" 2>/dev/null && pwd -P 2>/dev/null || echo "")
  [ -n "$file_root" ] && [ "$file_root" != "$current_root" ]
}

# Assert the current cwd's worktree matches the session's bound worktree.
# Exit 0 cleanly if drift — prevents cross-worktree hook firing even when
# session IDs collide (stale env inheritance, bare-$$ fallback clashes).
# Call at the top of every hook after session dir is established.
_hook_assert_bound_worktree() {
  local bound="$_hook_session_dir/bound-worktree"
  [ -f "$bound" ] || return 0  # not bound yet (first call)
  local expected current
  expected=$(cat "$bound" 2>/dev/null)
  current=$(_hook_current_worktree_root) || return 0
  [ -z "$expected" ] && return 0
  if [ "$current" != "$expected" ]; then
    _hook_debug "assert_bound_worktree: drift (cwd=$current expected=$expected) — no-op exit"
    exit 0
  fi
}

# ── Session re-point: adopt a stdin-provided session id ─────────
# Codex delivers session_id on stdin, not the environment. Re-point the
# session dir once when the env vars are absent, re-deriving every
# source-time path that captured the fallback dir.

_hook_repoint_session_dir() {
  local sid="$1"
  [ -n "$sid" ] || return 0
  if [ -n "${CLAUDE_SESSION_ID:-}" ] || [ -n "${CODEX_SESSION_ID:-}" ]; then
    return 0
  fi
  _hook_session_id="$sid"
  _hook_session_dir="/tmp/hook-session-${_hook_session_id}"
  mkdir -p "$_hook_session_dir" 2>/dev/null || true
  [ -n "${_hook_violations_file:-}" ] && _hook_violations_file="$_hook_session_dir/violations"
  [ -n "${_hook_log_file:-}" ] && _hook_log_file="$_hook_session_dir/structured.jsonl"
  [ -n "${_hook_debug_file:-}" ] && _hook_debug_file="$_hook_session_dir/debug.log"
  # The guards above return 1 when a path var is unset -- never let that
  # become the function's exit status under a caller's set -e.
  return 0
}

# For hooks that never call hook_parse_* (Stop hooks, autofixers): consume
# stdin and adopt its session_id so readers see the same dir Codex
# producers wrote to. No-op when env ids exist or stdin is a terminal.
# Safe to combine with hook_parse_* in either order: stdin is delivered
# once per hook process, so whoever reads it first stores it in
# _hook_input and the other reuses it instead of reading EOF.
hook_adopt_stdin_session() {
  if [ -n "${CLAUDE_SESSION_ID:-}" ] || [ -n "${CODEX_SESSION_ID:-}" ]; then
    return 0
  fi
  if [ -z "${_hook_input:-}" ]; then
    [ -t 0 ] && return 0
    _hook_input=$(cat 2>/dev/null || true)
  fi
  if _hook_protocol_parse; then
    _hook_repoint_session_dir "$hp_session_id"
  else
    _hook_repoint_session_dir "$(echo "$_hook_input" | jq -r '.session_id // empty' 2>/dev/null || true)"
  fi
  return 0
}

# ── PostToolUse: Parse stdin, gate on Edit|Write, extract file_path ──

hook_parse_edit_write() {
  _hook_assert_bound_worktree
  [ -n "${_hook_input:-}" ] || _hook_input=$(cat)
  # Codex session id arrives on stdin, not the environment: re-point the
  # session dir once per parse when the env vars are absent (issue #48 WS1).
  if _hook_protocol_parse; then
    _hook_tool_name="$hp_tool_name"
    _hook_repoint_session_dir "$hp_session_id"
  else
    _hook_tool_name=$(echo "$_hook_input" | jq -r '.tool_name // empty' 2>/dev/null || true)
    _hook_repoint_session_dir "$(echo "$_hook_input" | jq -r '.session_id // empty' 2>/dev/null || true)"
  fi

  if [ "$_hook_tool_name" != "Edit" ] && [ "$_hook_tool_name" != "Write" ] && [ "$_hook_tool_name" != "apply_patch" ]; then
    _hook_skip_or_exit 1
    return $?
  fi
  tool_name="$_hook_tool_name"
  tool_input=$(echo "$_hook_input" | jq -c '.tool_input // {}' 2>/dev/null || echo '{}')

  if [ "$_hook_protocol_parsed" = "OK" ]; then
    file_path="$hp_file_path"
  else
    file_path=$(echo "$_hook_input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
  fi

  # Canonical Codex apply_patch payload: the patch text arrives in
  # tool_input.command (string, or ["apply_patch", "<patch>"] array per the
  # Codex hook contract); targets live inside the patch body as
  # "*** Update File: x" / "*** Add File: x". Multi-file patches: file_path is
  # the first existing target; _hook_apply_patch_targets carries them all and
  # hook_get_added_lines returns the union of + lines so no target escapes
  # per-call checks (the batch dispatcher expands per target for attribution).
  if [ -z "$file_path" ] && [ "$_hook_tool_name" = "apply_patch" ]; then
    local _patch_body _patch_rel _root
    _patch_body=$(echo "$_hook_input" | jq -r 'if (.tool_input.command|type) == "array" then .tool_input.command[1:] | join("\n") elif (.tool_input.command|type) == "string" then .tool_input.command else (.tool_input.patch // .tool_input.input // empty) end' 2>/dev/null || true)
    _root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    _hook_apply_patch_targets=""
    while IFS= read -r _patch_rel; do
      [ -z "$_patch_rel" ] && continue
      case "$_patch_rel" in
        /*) : ;;
        *) _patch_rel="$_root/$_patch_rel" ;;
      esac
      _hook_apply_patch_targets="${_hook_apply_patch_targets}${_patch_rel}
"
      if [ -z "$file_path" ] && [ -e "$_patch_rel" ]; then
        file_path="$_patch_rel"
      fi
    done < <(printf '%s\n' "$_patch_body" | sed -nE 's/^\*\*\* (Update|Add) File: (.*)$/\2/p')
    # No existing target (pure Add before write lands): take the first named one.
    if [ -z "$file_path" ] && [ -n "$_hook_apply_patch_targets" ]; then
      file_path=$(printf '%s' "$_hook_apply_patch_targets" | head -1)
    fi
    [ -n "$_hook_apply_patch_targets" ] && _hook_apply_patch_body="$_patch_body"

    # Per-target fan-out: re-exec THIS wrapper once per target as a synthetic
    # Edit carrying the patch body. Every check then sees the right file_path
    # for its own extension/case gates and only that file's hunk -- a .ts
    # violation cannot hide behind a .md first target. Worst exit wins.
    if [ -n "$_hook_apply_patch_targets" ] && [ -z "${_HOOK_APPLY_PATCH_CHILD:-}" ] && [ -x "$0" ]; then
      local _apx_worst=0 _apx_rc _apx_t _apx_payload
      while IFS= read -r _apx_t; do
        [ -z "$_apx_t" ] && continue
        _apx_payload=$(jq -nc --arg f "$_apx_t" --arg p "$_patch_body" --arg sid "${_hook_session_id:-}" '{tool_name:"Edit",session_id:$sid,tool_input:{file_path:$f,patch:$p}}' 2>/dev/null || true)
        [ -z "$_apx_payload" ] && continue
        _apx_rc=0
        printf '%s' "$_apx_payload" | _HOOK_APPLY_PATCH_CHILD=1 "$0" || _apx_rc=$?
        [ "$_apx_rc" -gt "$_apx_worst" ] && _apx_worst=$_apx_rc
      done <<< "$_hook_apply_patch_targets"
      exit "$_apx_worst"
    fi
  fi

  if [ -z "$file_path" ] || { [ ! -f "$file_path" ] && [ "${HOOK_ALLOW_MISSING_FILE:-0}" != "1" ]; }; then
    _hook_debug "skip: file_path empty or missing ($file_path)"
    _hook_skip_or_exit 1
    return $?
  fi

  # Binary files are not source code: skip before any sed/grep touches the
  # content (BSD sed under a UTF-8 locale dies with "RE error: illegal byte
  # sequence" on invalid UTF-8 -- caught by macOS CI).
  if [ -s "$file_path" ] && ! LC_ALL=C grep -Iq . "$file_path" 2>/dev/null; then
    _hook_debug "skip: binary content ($file_path)"
    _hook_skip_or_exit 1
    return $?
  fi

  file_content=$(cat "$file_path" 2>/dev/null || true)
  _hook_debug "parse: $file_path"

  # Track which files this session touches (for session-scoped Stop hooks).
  # Gate: skip files that live outside the CURRENT terminal's worktree.
  # This catches both:
  #   (a) secondary worktrees spawned for subagents (inherits parent id)
  #   (b) sibling worktrees of a multi-session flow (same-path collisions)
  if _hook_file_outside_current_worktree "$file_path"; then
    _hook_debug "skip session-touched-files: outside current worktree ($file_path)"
  else
    echo "$file_path" >> "$_hook_session_dir/session-touched-files" 2>/dev/null || true
  fi
}

# ── Filter by file extensions (pipe-separated, e.g. "ts|tsx|js|jsx") ──

hook_filter_extensions() {
  # Non-frontend repo early exit. session-env.sh sets DISABLE_FRONTEND_HOOKS=1
  # on SessionStart if package.json lacks react/react-dom. Saves ~50ms per
  # hook on Go/Python/etc repos where frontend checks are dead weight.
  if [ "${DISABLE_FRONTEND_HOOKS:-0}" = "1" ]; then
    _hook_debug "skip: DISABLE_FRONTEND_HOOKS=1 (non-frontend repo)"
    _hook_skip_or_exit 1
    return $?
  fi
  local exts="$1"
  local match=false
  local IFS='|'
  # Multi-file apply_patch: the call passes the gate if ANY target matches --
  # file_path alone would gate every check on the first target's extension
  # and let a .ts violation hide behind a .md first file.
  if [ -n "${_hook_apply_patch_targets:-}" ]; then
    local _apt
    while IFS= read -r _apt; do
      [ -z "$_apt" ] && continue
      for ext in $exts; do
        case "$_apt" in
          *."$ext") match=true; break 2 ;;
        esac
      done
    done <<< "$_hook_apply_patch_targets"
  fi
  if [ "$match" = false ]; then
  for ext in $exts; do
    case "$file_path" in
      *."$ext") match=true; break ;;
    esac
  done
  fi
  if [ "$match" = false ]; then
    _hook_debug "skip: extension mismatch (wanted $exts, got ${file_path##*.})"
    _hook_skip_or_exit 1
    return $?
  fi
}

# ── Skip test files ──────────────────────────────────────────────

hook_skip_tests() {
  case "$file_path" in
    *.test.*|*.spec.*) _hook_debug "skip: test file"; _hook_skip_or_exit 1; return $? ;;
  esac
  if echo "$file_path" | grep -qE '/__tests__/'; then
    _hook_debug "skip: __tests__ directory"
    _hook_skip_or_exit 1
    return $?
  fi
}

# ── Skip auto-generated files ────────────────────────────────────

hook_skip_generated() {
  case "$file_path" in
    *.gen.ts|*.gen.tsx|*.gen.js) _hook_debug "skip: generated (.gen)"; _hook_skip_or_exit 1; return $? ;;
    *_pb.ts|*_pb.js) _hook_debug "skip: generated (_pb)"; _hook_skip_or_exit 1; return $? ;;
    *_connectquery.ts) _hook_debug "skip: generated (_connectquery)"; _hook_skip_or_exit 1; return $? ;;
  esac
  # Skip files with @generated marker
  if head -5 "$file_path" 2>/dev/null | grep -qE '(@generated|auto-generated|DO NOT EDIT)'; then
    _hook_debug "skip: generated (@generated marker)"
    _hook_skip_or_exit 1
    return $?
  fi
}

# ── Skip component library directories (auto-detect + UI_LIB_DIRS) ──

hook_skip_ui_dirs() {
  if [ -z "${UI_LIB_DIRS:-}" ]; then
    _ui_dirs="components/ui"
    _root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    [ -d "$_root/redpanda-ui" ] && _ui_dirs="$_ui_dirs|redpanda-ui"
    [ -d "$_root/src/components/redpanda-ui" ] && _ui_dirs="$_ui_dirs|redpanda-ui"
    [ -d "$_root/src/ui" ] && _ui_dirs="$_ui_dirs|src/ui"
    [ -d "$_root/packages/ui" ] && _ui_dirs="$_ui_dirs|packages/ui"
  else
    _ui_dirs="$UI_LIB_DIRS"
  fi
  # Registry-edit warning is owned by vendor-file-check.lib.sh (single owner);
  # this helper only skips so per-component checks don't fire on library code.
  if echo "$file_path" | grep -qE "/($_ui_dirs)/"; then
    _hook_skip_or_exit 1
    return $?
  fi
}

# ── Get added lines from tool payload (sets global: added_lines) ──
# Source of truth is the Edit/Write payload, NOT the working tree.
#
# Why: `git diff HEAD` misses untracked files (falls back to `cat`
# whole file → every pre-existing violation reported as "new" → hook
# noise). Payload diff shows ONLY what this tool call changed —
# regardless of tracking status, prior dirty state, or sibling edits.
#
#   Edit  → diff old_string vs new_string, take added lines
#   Write → diff `git show HEAD:file` vs content if tracked,
#           else treat full content as added (new file)
#
# Output lines are prefixed with `+` to match legacy callers that
# strip the prefix (e.g. `sed 's/^+//'`).

hook_get_added_lines() {
  local tool old_str new_str content head_content
  tool=$(echo "$_hook_input" | jq -r '.tool_name // empty' 2>/dev/null || true)

  if [ "$tool" = "Edit" ]; then
    # Dispatcher-synthesized apply_patch expansion: prefer this file's own hunk
    # from tool_input.patch over disk/git fallbacks (which would resurrect
    # pre-existing lines as "added" once the file matches HEAD).
    local _edit_patch
    _edit_patch=$(echo "$_hook_input" | jq -r '.tool_input.patch // empty' 2>/dev/null || true)
    if [ -n "$_edit_patch" ]; then
      added_lines=$(printf '%s\n' "$_edit_patch" | awk -v f="$file_path" '
        /^\*\*\* (Update|Add) File: / { h = substr($0, index($0, ": ") + 2); in_target = (h == f || (length(f) > length(h) && substr(f, length(f) - length(h)) == "/" h)); next }
        /^\*\*\*/ { in_target = 0; next }
        in_target && /^\+/ { print substr($0, 2) }')
      return 0
    fi
  fi

  if [ "$tool" = "apply_patch" ] && [ -n "${_hook_apply_patch_body:-}" ]; then
    # Union of +-prefixed lines across ALL targets in the patch -- a violation
    # in any file of a multi-file patch is seen even by single-file checks.
    added_lines=$(printf '%s\n' "$_hook_apply_patch_body" | grep '^+' | grep -v '^+++' | sed 's/^+//' || true)
    return 0
  fi

  if [ "$tool" = "Edit" ]; then
    # Prefer payload.old_string/new_string. If neither key is present
    # (legacy/synthetic callers), fall back to git diff vs HEAD, then
    # to full file contents. Real Edit payload always carries both.
    local has_old has_new
    has_old=$(echo "$_hook_input" | jq -r '.tool_input | has("old_string")' 2>/dev/null || echo "false")
    has_new=$(echo "$_hook_input" | jq -r '.tool_input | has("new_string")' 2>/dev/null || echo "false")
    if [ "$has_old" = "true" ] || [ "$has_new" = "true" ]; then
      old_str=$(echo "$_hook_input" | jq -r '.tool_input.old_string // ""' 2>/dev/null || true)
      new_str=$(echo "$_hook_input" | jq -r '.tool_input.new_string // ""' 2>/dev/null || true)
      added_lines=$(diff <(printf '%s\n' "$old_str") <(printf '%s\n' "$new_str") 2>/dev/null \
        | grep '^>' | sed 's/^> //' || true)
    else
      local diff_out
      diff_out=$(git diff HEAD -- "$file_path" 2>/dev/null || true)
      if [ -n "$diff_out" ]; then
        added_lines=$(echo "$diff_out" | grep '^+' | grep -v '^+++' || true)
      else
        added_lines=$(cat "$file_path" 2>/dev/null || true)
      fi
    fi
  elif [ "$tool" = "MultiEdit" ]; then
    local edits_len i old_str new_str chunk
    edits_len=$(echo "$_hook_input" | jq -r '.tool_input.edits | length // 0' 2>/dev/null || echo 0)
    added_lines=""
    i=0
    while [ "$i" -lt "${edits_len:-0}" ]; do
      old_str=$(echo "$_hook_input" | jq -r --argjson i "$i" '.tool_input.edits[$i].old_string // ""' 2>/dev/null || true)
      new_str=$(echo "$_hook_input" | jq -r --argjson i "$i" '.tool_input.edits[$i].new_string // ""' 2>/dev/null || true)
      chunk=$(diff <(printf '%s\n' "$old_str") <(printf '%s\n' "$new_str") 2>/dev/null \
        | grep '^>' | sed 's/^> //' || true)
      if [ -n "$chunk" ]; then
        added_lines="${added_lines}${added_lines:+$'\n'}$chunk"
      fi
      i=$((i + 1))
    done
  elif [ "$tool" = "Write" ]; then
    # Prefer payload.content. If absent (legacy/synthetic callers),
    # fall back to file on disk — Write creates/overwrites, so disk
    # state after the call IS the new content.
    local has_content
    has_content=$(echo "$_hook_input" | jq -r '.tool_input | has("content")' 2>/dev/null || echo "false")
    if [ "$has_content" = "true" ]; then
      content=$(echo "$_hook_input" | jq -r '.tool_input.content // ""' 2>/dev/null || true)
    else
      content=$(cat "$file_path" 2>/dev/null || true)
    fi
    # Tool paths are commonly absolute; HEAD:.//absolute/path never resolves.
    # Anchor at the target directory so retained headers are not new additions.
    head_content=$(git -C "$(dirname "$file_path")" show "HEAD:./$(basename "$file_path")" 2>/dev/null || true)
    if [ -n "$head_content" ]; then
      added_lines=$(diff <(printf '%s\n' "$head_content") <(printf '%s\n' "$content") 2>/dev/null \
        | grep '^>' | sed 's/^> //' || true)
    else
      added_lines="$content"
    fi
  else
    added_lines=""
  fi

  if [ -z "$added_lines" ]; then
    _hook_debug "skip: no added lines from payload ($tool)"
    _hook_skip_or_exit 1
    return $?
  fi
}

# ── Session-scoped changed files (for Stop hooks) ────────────────
# Returns files that: (a) are in current git diff, (b) were touched
# by this session via Edit/Write, and (c) were NOT dirty at session
# start. Delivery can include touched baseline files via the second argument.
# Falls back to full git diff if tracking data unavailable.
#
# Usage in Stop hooks:
#   source "path/to/hook-lib.sh"
#   session_changed=$(hook_session_changed_files "ts|tsx|js|jsx")
#   if hook_has_session_tracking; then ... fi

hook_session_changed_files() {
  local ext_filter="${1:-}"
  # Delivery must also resolve pre-existing files the session touched/adopted.
  # Other quality checks retain their new-changes-only scope.
  local include_touched_baseline="${2:-false}"

  # Get current tracked changes plus untracked files. Session-touch
  # intersection and the start baseline below prevent unrelated untracked
  # files from becoming this turn's responsibility.
  local current_diff
  current_diff=$(
    {
      git diff --name-only HEAD 2>/dev/null
      git ls-files --others --exclude-standard 2>/dev/null
    } | sort -u
  )

  if [ -z "$current_diff" ]; then
    return
  fi

  # Apply extension filter if provided
  if [ -n "$ext_filter" ]; then
    current_diff=$(echo "$current_diff" | grep -E "\\.(${ext_filter})$" || true)
  fi

  if [ -z "$current_diff" ]; then
    return
  fi

  local touched_file="$_hook_session_dir/session-touched-files"
  local baseline_file="$_hook_session_dir/dirty-files-baseline"

  # Mode 1: Both touched-files and baseline exist (Claude Code normal)
  # Formula: (current_diff ∩ touched) - baseline, unless delivery includes it.
  if [ -f "$touched_file" ]; then
    local repo_root
    repo_root=$(cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd -P)
    local touched_normalized
    # Resolve symlinks (macOS /var → /private/var) then strip repo root
    touched_normalized=$(while IFS= read -r f; do
      _real=$(cd "$(dirname "$f")" 2>/dev/null && echo "$(pwd -P)/$(basename "$f")" || echo "$f")
      echo "${_real#"$repo_root"/}"
    done < "$touched_file" | sort -u)

    local intersected
    intersected=$(comm -12 <(echo "$current_diff" | sort) <(echo "$touched_normalized") 2>/dev/null || true)

    if [ "$include_touched_baseline" != true ] && [ -f "$baseline_file" ] && [ -s "$baseline_file" ]; then
      intersected=$(comm -23 <(echo "$intersected" | sort) <(sort "$baseline_file") 2>/dev/null || echo "$intersected")
    fi

    echo "$intersected"
    return
  fi

  # Mode 2: Only baseline exists (Codex, or Bash-only session)
  # Formula: current_diff - baseline
  if [ -f "$baseline_file" ] && [ -s "$baseline_file" ]; then
    comm -23 <(echo "$current_diff" | sort) <(sort "$baseline_file") 2>/dev/null || echo "$current_diff"
    return
  fi

  # Mode 3: No tracking data (legacy) — return full diff
  echo "$current_diff"
}

# Check if session tracking data exists (safe to call outside subshell)
hook_has_session_tracking() {
  [ -f "$_hook_session_dir/session-touched-files" ] || [ -f "$_hook_session_dir/dirty-files-baseline" ]
}

# ── Filter error output to session-owned files ───────────────────
# For project-wide tools (tsc, tsrs, doctor) that cannot target files,
# filters error lines to only those mentioning session-owned files.

hook_filter_errors_to_session() {
  local output="$1"
  local session_files="$2"

  if [ -z "$session_files" ] || [ -z "$output" ]; then
    return
  fi

  # Build grep pattern from file list
  local pattern
  pattern=$(echo "$session_files" | sed 's/[.[\*^$()+?{|]/\\&/g' | paste -sd '|' -)

  echo "$output" | grep -E "$pattern" || true
}

# ── Escape hatch: unified // allow: rule-name ────────────────────
# Checks for both new format: // allow: rule-name [reason]
# and legacy format: // allow-rule-name: [reason]
# Usage:  hook_has_escape "useEffect" && exit 0

hook_has_escape() {
  local rule="$1"
  local target="${2:-$file_path}"
  [ -f "$target" ] || return 1
  # New unified format: // allow: rule-name
  if grep -qE "//\s*allow:\s*$rule\b" "$target" 2>/dev/null; then
    _hook_debug "escape hatch found: allow: $rule"
    return 0
  fi
  # Legacy format: // allow-rule-name:
  if grep -qE "//\s*allow-$rule:" "$target" 2>/dev/null; then
    _hook_debug "escape hatch found (legacy): allow-$rule"
    return 0
  fi
  return 1
}

# ── HOOK_VERBOSITY ────────────────────────────────────────────────
# Controls hook output level:
#   normal (default) — all blocks and warns emitted
#   terse            — blocks only, warns suppressed
#   quiet            — all output suppressed (violations still tracked)

_hook_verbosity="${HOOK_VERBOSITY:-normal}"

# ── Elapsed-ms timer (for perf_ms telemetry) ────────────────────
# Sets _hook_start_ms on library source. _hook_elapsed_ms prints
# milliseconds since source. Integer-only output (test contract).
# Uses bash 5 EPOCHREALTIME (zero subprocess); falls back to python3
# only on shells without it. macOS `date +%N` is unsupported.

_hook_now_ms() {
  if [ -n "${EPOCHREALTIME:-}" ]; then
    local s="${EPOCHREALTIME/,/.}"
    echo $(( ${s%.*} * 1000 + 10#${s#*.} / 1000 ))
  else
    python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo 0
  fi
}

_hook_start_ms=$(_hook_now_ms)

_hook_elapsed_ms() {
  local now
  now=$(_hook_now_ms)
  [ "$now" -eq 0 ] && now=$_hook_start_ms
  echo $((now - _hook_start_ms))
}

# ── Typed protocol delegation ────────────────────────────────────
# When bun and shared/hook-protocol.ts are available, emission delegates to
# the typed layer: stream/exit pairing is a lookup table and JSON comes from
# JSON.stringify -- the two live bug classes of the shell emitters (wrong
# stream, hand-rolled escaping) become impossible. HOOK_PROTOCOL=shell
# forces the pure-shell fallback (also the path when bun is absent).

_hook_protocol_entry=""
_hook_protocol_resolve() {
  if [ -n "$_hook_protocol_entry" ]; then
    [ "$_hook_protocol_entry" = "NONE" ] && return 1
    return 0
  fi
  # BASH_SOURCE keeps the symlink spelling -- skill-dir links to this lib
  # would resolve candidates relative to the link location and miss the
  # real entrypoint. Follow file symlinks before deriving the base dir.
  local src="${BASH_SOURCE[0]}" tgt
  while [ -L "$src" ]; do
    tgt=$(readlink "$src" 2>/dev/null) || break
    case "$tgt" in
      /*) src="$tgt" ;;
      *) src="$(dirname "$src")/$tgt" ;;
    esac
  done
  local dir
  dir="$(cd "$(dirname "$src")" 2>/dev/null && pwd -P)" || { _hook_protocol_entry="NONE"; return 1; }
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null || true)
  local c
  for c in "$dir/hook-protocol.ts" "$dir/../shared/hook-protocol.ts" "$dir/../../shared/hook-protocol.ts" "${root:+$root/shared/hook-protocol.ts}"; do
    [ -n "$c" ] || continue
    if [ -f "$c" ]; then
      _hook_protocol_entry="$c"
      return 0
    fi
  done
  _hook_protocol_entry="NONE"
  return 1
}

# Bounded bun invocation: a wedged bun (corrupted install that hangs
# instead of crashing) must cost one hook a few seconds, not the harness's
# full hook timeout. timeout/gtimeout when present (Linux always; macOS via
# coreutils); bare bun otherwise -- the harness timeout stays as the
# last-resort bound. A kill exits with a non-contract code (124/137), so
# callers fall back to shell exactly like any other bun failure.
_hook_protocol_run() {
  local bound="${HOOK_PROTOCOL_TIMEOUT_S:-5}"
  # A malformed bound would make timeout exit 125 on EVERY invocation --
  # silently degrading the whole session to the shell path. And GNU
  # `timeout 0` DISABLES the timeout entirely, which would un-bound the
  # hang this wrapper exists to bound. Sanitize both to the default.
  case "$bound" in
    '' | *[!0-9]*)
      _hook_debug "invalid HOOK_PROTOCOL_TIMEOUT_S='$bound' -- using 5"
      bound=5
      ;;
  esac
  [ "$bound" -eq 0 ] && bound=5
  if command -v timeout >/dev/null 2>&1; then
    timeout "$bound" bun "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$bound" bun "$@"
  else
    bun "$@"
  fi
}

# Emit via the typed layer. Returns 0 when the payload went out (bun exited
# with the tier's contract code, 0 or 2); returns 1 when the caller must use
# the shell fallback. The caller owns the final exit code either way.
# $3 (event name) is required by the context tier, ignored by the rest.
_hook_protocol_emit() {
  local tier="$1" msg="$2" event="${3:-}" rc out_f err_f
  [ "${HOOK_PROTOCOL:-}" = "shell" ] && return 1
  command -v bun >/dev/null 2>&1 || return 1
  _hook_protocol_resolve || return 1
  # Capture both streams and release ONLY the contract stream on a contract
  # exit code -- a bun crash mid-run must not leave a diagnostic on the live
  # stream next to the shell fallback's JSON (two payloads never parse).
  out_f=$(mktemp 2>/dev/null) || return 1
  err_f=$(mktemp 2>/dev/null) || { rm -f "$out_f"; return 1; }
  rc=0
  if [ -n "$event" ]; then
    _hook_protocol_run "$_hook_protocol_entry" emit "$tier" "$msg" "$event" >"$out_f" 2>"$err_f" || rc=$?
  else
    _hook_protocol_run "$_hook_protocol_entry" emit "$tier" "$msg" >"$out_f" 2>"$err_f" || rc=$?
  fi
  # Release the contract stream only when it holds a JSON object. A bun
  # shim that exits with a contract code but prints a banner (or usage
  # text) must fall back to shell, not put non-JSON on the live stream
  # while the caller skips its fallback (cross-model review P1).
  case "$rc" in
    0)
      if jq -e 'type == "object"' "$out_f" >/dev/null 2>&1; then
        cat "$out_f"; rm -f "$out_f" "$err_f"; return 0
      fi
      _hook_debug "protocol emit rc=0 without JSON payload -- shell fallback"
      rm -f "$out_f" "$err_f"
      return 1
      ;;
    2)
      # Exit 2 is a contract payload only for the stderr tiers. For the
      # stdout tiers (warn/nudge/context) bun exiting 2 is a usage error
      # -- catting it to stderr would strand the message on a stream the
      # harness drops at exit 0, and the caller would skip its fallback
      # believing the emit succeeded (cross-model review P2).
      case "$tier" in
        warn | nudge | context)
          _hook_debug "protocol emit usage error on stdout tier '$tier' -- shell fallback"
          rm -f "$out_f" "$err_f"
          return 1
          ;;
        *)
          if jq -e 'type == "object"' "$err_f" >/dev/null 2>&1; then
            cat "$err_f" >&2; rm -f "$out_f" "$err_f"; return 0
          fi
          _hook_debug "protocol emit rc=2 without JSON payload -- shell fallback"
          rm -f "$out_f" "$err_f"
          return 1
          ;;
      esac
      ;;
    *) _hook_debug "protocol emit failed (rc=$rc) -- shell fallback"; rm -f "$out_f" "$err_f"; return 1 ;;
  esac
}

# Typed parse delegation (phase 2): one bun run exports every scalar the
# shell parsers consume (hp_session_id / hp_event / hp_tool_name /
# hp_file_path / hp_filename / hp_command) as shell-safe single-quoted
# assignments.
# Costs one bun spawn in place of the 2-3 jq spawns it replaces (measured
# a wash: ~39ms vs ~43ms). Complex extraction (tool_input blob,
# apply_patch body, edits arrays) stays on jq. Returns 0 with hp_*
# populated; 1 = caller must use the jq path. Memoized: _hook_input never
# changes within a hook process, so the second caller (adopt-then-parse)
# reuses the first result instead of respawning bun.
_hook_protocol_parsed=""
_hook_protocol_parse() {
  if [ -n "$_hook_protocol_parsed" ]; then
    [ "$_hook_protocol_parsed" = "OK" ] && return 0
    return 1
  fi
  _hook_protocol_parsed="NO"
  [ "${HOOK_PROTOCOL:-}" = "shell" ] && return 1
  command -v bun >/dev/null 2>&1 || return 1
  _hook_protocol_resolve || return 1
  local out rc=0
  out=$(printf '%s' "${_hook_input:-}" | _hook_protocol_run "$_hook_protocol_entry" parse 2>/dev/null) || rc=$?
  # Empty output = stdin was not a JSON object; the jq path agrees (every
  # extraction comes back empty), so falling back is correct, just idle.
  [ "$rc" -eq 0 ] && [ -n "$out" ] || return 1
  # Trust boundary: only output that starts like the typed layer's first
  # assignment reaches eval. A bun wrapper that exits 0 with foreign
  # stdout (version banner, shim noise) must fall back to jq, not eval.
  case "$out" in
    "hp_session_id='"*) : ;;
    *)
      _hook_debug "protocol parse output shape rejected -- jq fallback"
      return 1
      ;;
  esac
  # The assignments are hp_*-namespaced, single-quoted, and NUL-free by the
  # typed layer's contract (pinned by shared/hook-protocol.test.ts) -- eval
  # here is data, not code, and stderr was already dropped above. Trust
  # boundary note: bun stdout carries the same trust as executing bun
  # itself; the guards here defend against ACCIDENTAL foreign output
  # (shims, banners, truncation), not a hostile bun -- a hostile bun is
  # already arbitrary code execution.
  if ! eval "$out" 2>/dev/null; then
    _hook_debug "protocol parse eval failed -- jq fallback"
    return 1
  fi
  # Completeness: truncated output (killed bun flushing part of a write)
  # can pass the prefix guard yet leave later fields unset -- an unbound
  # variable crash under a caller's set -u. All six or fall back.
  if [ -z "${hp_session_id+x}" ] || [ -z "${hp_event+x}" ] || [ -z "${hp_tool_name+x}" ] \
    || [ -z "${hp_file_path+x}" ] || [ -z "${hp_filename+x}" ] || [ -z "${hp_command+x}" ]; then
    _hook_debug "protocol parse output incomplete -- jq fallback"
    return 1
  fi
  _hook_protocol_parsed="OK"
  return 0
}

# ── Tier API: info / nudge / block_strict / emit_diagnostic ─────
# Added in 2.2.2 to give hooks a richer severity vocabulary than
# the original block/warn pair.
#
#   hook_info          silent. tracks violation + log entry only.
#                      use for "we saw this pattern" without user noise.
#   hook_nudge         advisory systemMessage with [nudge] prefix,
#                      exit 0. for optional improvements.
#   hook_block_strict  hard-block with [STRICT] prefix, exit 2.
#                      same exit code as hook_block; prefix distinguishes
#                      non-negotiable rules (security, correctness) from
#                      stylistic blocks.
#   hook_emit_diagnostic  structured diagnostic append; no-op if no sink.

hook_info() {
  local rule="${1:-$(_hook_default_rule)}"
  _hook_debug "INFO [$rule]"
  _hook_track_violation "$rule"
  _hook_log_entry "info" "$rule"
  exit 0
}

hook_nudge() {
  local msg
  msg=$(_hook_cap_msg "$1")
  local rule="${2:-$(_hook_default_rule)}"
  _hook_debug "NUDGE [$rule]: $msg"
  if _hook_rule_shadowed "$rule"; then
    _hook_log_entry "shadow-nudge" "$rule"
    if [ "${HOOK_COLLECT:-0}" = "1" ]; then return 0; fi
    exit 0
  fi
  _hook_track_violation "$rule"
  _hook_log_entry "nudge" "$rule"
  if [ "${HOOK_COLLECT:-0}" = "1" ]; then
    _hook_collect_emit "nudge" "$rule" "[nudge] $msg"
    return 0
  fi
  if [ "$_hook_verbosity" = "normal" ]; then
    if ! _hook_protocol_emit nudge "$msg"; then
      local escaped
      escaped=$(_safe_json_escape "[nudge] $msg")
      # Exit-0 JSON is parsed from STDOUT (stderr is dropped on exit 0).
      echo "{\"suppressOutput\":true,\"systemMessage\":$escaped}"
    fi
  fi
  exit 0
}

hook_block_strict() {
  local msg
  msg=$(_hook_cap_msg "$1")
  local rule="${2:-$(_hook_default_rule)}"
  _hook_debug "STRICT [$rule]: $msg"
  _hook_track_violation "$rule"
  _hook_log_entry "block-strict" "$rule"
  if [ "${HOOK_COLLECT:-0}" = "1" ]; then
    _hook_collect_emit "block-strict" "$rule" "[STRICT] $msg"
    return 0
  fi
  if [ "$_hook_verbosity" != "quiet" ]; then
    if ! _hook_protocol_emit block-strict "$msg"; then
      local escaped
      escaped=$(_safe_json_escape "[STRICT] $msg")
      echo "{\"suppressOutput\":true,\"systemMessage\":$escaped}" >&2
    fi
  fi
  exit 2
}

hook_emit_diagnostic() {
  local sink="$_hook_session_dir/diagnostics.jsonl"
  local hook="${2:-$(basename "$0" .sh)}"
  local payload="${1:-}"
  [ -z "$payload" ] && return 0
  printf '{"ts":%d,"hook":"%s","payload":%s}\n' \
    "$(date +%s)" "$hook" "$payload" >> "$sink" 2>/dev/null || true
}

# ── PostToolUse: Block with systemMessage (exit 2) ──────────────

hook_block() {
  local msg
  msg=$(_hook_cap_msg "$1")
  local label="${2:-$(_hook_default_rule)}"
  _hook_debug "BLOCK [$label]: $msg"
  if _hook_rule_shadowed "$label"; then
    _hook_log_entry "shadow-block" "$label"
    if [ "${HOOK_COLLECT:-0}" = "1" ]; then return 0; fi
    exit 0
  fi
  _hook_track_violation "$label"
  _hook_log_entry "block" "$label"
  if [ "${HOOK_COLLECT:-0}" = "1" ]; then
    _hook_collect_emit "block" "$label" "$msg"
    return 0
  fi
  if [ "$_hook_verbosity" != "quiet" ]; then
    if ! _hook_protocol_emit block "$msg"; then
      local escaped
      escaped=$(_safe_json_escape "$msg")
      echo "{\"suppressOutput\":true,\"systemMessage\":$escaped}" >&2
    fi
  fi
  exit 2
}

# ── PostToolUse: Warn with systemMessage (exit 0) ───────────────

hook_warn() {
  local msg
  msg=$(_hook_cap_msg "$1")
  local label="${2:-$(_hook_default_rule)}"
  _hook_debug "WARN [$label]: $msg"
  if _hook_rule_shadowed "$label"; then
    _hook_log_entry "shadow-warn" "$label"
    if [ "${HOOK_COLLECT:-0}" = "1" ]; then return 0; fi
    exit 0
  fi
  _hook_track_violation "$label"
  _hook_log_entry "warn" "$label"
  if [ "${HOOK_COLLECT:-0}" = "1" ]; then
    _hook_collect_emit "warn" "$label" "$msg"
    return 0
  fi
  if [ "$_hook_verbosity" = "normal" ]; then
    if ! _hook_protocol_emit warn "$msg"; then
      local escaped
      escaped=$(_safe_json_escape "$msg")
      # Exit-0 JSON is parsed from STDOUT (stderr is dropped on exit 0).
      echo "{\"suppressOutput\":true,\"systemMessage\":$escaped}"
    fi
  fi
  exit 0
}

# ── PreToolUse (Bash): Parse stdin, extract command ──────────────

hook_parse_bash() {
  _hook_assert_bound_worktree
  [ -n "${_hook_input:-}" ] || _hook_input=$(cat)
  if _hook_protocol_parse; then
    _hook_tool_name="$hp_tool_name"
    _hook_repoint_session_dir "$hp_session_id"
  else
    _hook_tool_name=$(echo "$_hook_input" | jq -r '.tool_name // empty' 2>/dev/null || true)
    _hook_repoint_session_dir "$(echo "$_hook_input" | jq -r '.session_id // empty' 2>/dev/null || true)"
  fi

  if [ "$_hook_tool_name" != "Bash" ]; then
    exit 0
  fi

  if [ "$_hook_protocol_parsed" = "OK" ]; then
    command="$hp_command"
  else
    command=$(echo "$_hook_input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
  fi

  if [ -z "$command" ]; then
    exit 0
  fi
}

# ── PreToolUse: Deny with permissionDecision (exit 2) ────────────

hook_deny() {
  local msg="$1"
  local label="${2:-$(_hook_default_rule)}"
  _hook_debug "DENY [$label]: $msg"
  _hook_track_violation "$label"
  _hook_log_entry "deny" "$label"
  if ! _hook_protocol_emit deny "$msg"; then
    local escaped
    escaped=$(_safe_json_escape "$msg")
    echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\"},\"systemMessage\":$escaped}" >&2
  fi
  exit 2
}

# ── Stop hook: Block with decision (exit 2) ──────────────────────
# Claude Code force-continues at most CLAUDE_CODE_STOP_HOOK_BLOCK_CAP (8)
# consecutive Stop blocks, then treats further blocks as errors. Stay two
# under the harness cap: track consecutive blocked Stop events in session
# state (reset on UserPromptSubmit — a new prompt ends the streak) and
# downgrade to a visible systemMessage once the budget is spent, so the
# final findings reach the user instead of burning the cap.

_hook_stop_read_digits() {
  [ -r "$1" ] || return 0
  tr -dc '0-9' < "$1" 2>/dev/null || true
}

_hook_stop_block_budget_spent() {
  # Escape hatch for eval harnesses: fixtures share one session dir across
  # many synthetic Stop events, so consecutive-block accounting is
  # meaningless there. HOOK_STOP_BLOCK_CAP_GUARD=0 disables check+increment.
  [ "${HOOK_STOP_BLOCK_CAP_GUARD:-1}" = "0" ] && return 1
  local cap="${CLAUDE_CODE_STOP_HOOK_BLOCK_CAP:-8}"
  local n
  n=$(_hook_stop_read_digits "$_hook_session_dir/stop-block-count")
  [ "${n:-0}" -ge $((cap > 2 ? cap - 2 : 1)) ]
}

_hook_stop_note_block() {
  [ "${HOOK_STOP_BLOCK_CAP_GUARD:-1}" = "0" ] && return 0
  # Parallel Stop hooks blocking the same event must count as ONE
  # consecutive block. Blocks within 5s share the event (continuation
  # turns take far longer); collisions undercount, which is safe.
  local now last n
  now=$(date +%s)
  last=$(_hook_stop_read_digits "$_hook_session_dir/stop-block-marker")
  [ $((now - ${last:-0})) -le 5 ] && return 0
  n=$(_hook_stop_read_digits "$_hook_session_dir/stop-block-count")
  echo $((${n:-0} + 1)) > "$_hook_session_dir/stop-block-count" 2>/dev/null || true
  echo "$now" > "$_hook_session_dir/stop-block-marker" 2>/dev/null || true
}

hook_stop_block() {
  local msg
  msg=$(_hook_cap_msg "$1")
  if _hook_stop_block_budget_spent; then
    _hook_log_entry "block-downgraded" "stop-block-cap" "$(basename "$0" .sh)"
    echo "{\"suppressOutput\":true,\"systemMessage\":$(_safe_json_escape "[stop-block cap] Not blocking again (harness caps consecutive Stop blocks). Unresolved: $msg")}"
    exit 0
  fi
  _hook_stop_note_block
  if ! _hook_protocol_emit stop-block "$msg"; then
    local reason
    reason=$(_safe_json_escape "$msg")
    echo "{\"decision\":\"block\",\"reason\":$reason}" >&2
  fi
  exit 2
}

# ── Stop hook: Feedback that keeps the turn alive (exit 0) ───────
# Since v2.1.16x Stop/SubagentStop hooks may return
# hookSpecificOutput.additionalContext: Claude receives the text as context
# and CONTINUES the turn — softer than decision:block (no error framing),
# stronger than systemMessage (which ends the turn). Use for "worth fixing
# now, but phrase it as guidance" findings.

hook_stop_context() {
  local msg="$1"
  local rule="${2:-$(_hook_default_rule)}"
  msg=$(_hook_cap_msg "$msg")
  _hook_track_violation "$rule"
  _hook_log_entry "stop-context" "$rule"
  local escaped
  escaped=$(_safe_json_escape "$msg")
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"Stop\",\"additionalContext\":$escaped},\"suppressOutput\":true}"
  exit 0
}

# ── UserPromptSubmit/SessionStart/PostCompact: inject context ────
# additionalContext payloads carry hookEventName per the harness contract,
# so the event name is a required argument. The standalone context hooks
# (user-prompt-context.sh, post-compact-context.sh) stay lib-free by
# design -- every-prompt latency -- and keep their own jq -Rs emission;
# this emitter is for lib-sourcing hooks that inject context.
hook_context() {
  local msg="$1" event="${2:-}"
  # An empty event name is a caller bug: the payload would be
  # contract-invalid on every path. Skip identically on both paths
  # instead of emitting broken JSON (shell) or losing the message to a
  # usage error (typed).
  if [ -z "$event" ]; then
    _hook_debug "hook_context called without an event name -- skipping"
    exit 0
  fi
  if ! _hook_protocol_emit context "$msg" "$event"; then
    local escaped eescaped
    escaped=$(_safe_json_escape "$msg")
    eescaped=$(_safe_json_escape "$event")
    echo "{\"hookSpecificOutput\":{\"hookEventName\":$eescaped,\"additionalContext\":$escaped}}"
  fi
  exit 0
}

# ── Stop hook: Append finding to shared file (no block) ──────────
# Quality-gate pattern: each Stop hook records findings, then enforces its OWN
# findings directly via hook_stop_enforce at its exit points. The stop-findings
# file remains as a best-effort sweep for crashed writers -- Stop hooks run
# concurrently, so a late writer racing the quality-gate aggregator would
# otherwise be silently lost (issue #48 WS1).

hook_stop_finding() {
  local msg="$1"
  # Delimiter separates findings so quality-gate-stop.sh can count issues (not lines)
  printf '%s\n---\n' "$msg" >> "$_hook_session_dir/stop-findings" 2>/dev/null || true
  _hook_stop_local="${_hook_stop_local:-}${msg}
"
}

# Call at every exit point of an enforcing Stop hook: blocks with this
# script'"'"'s accumulated findings (exit 2), or exits 0 when none.
hook_stop_enforce() {
  if [ -n "${_hook_stop_local:-}" ]; then
    rm -f "$_hook_session_dir/stop-findings" 2>/dev/null || true
    hook_stop_block "$(printf 'Fix before stopping:\n%s' "$_hook_stop_local")"
  fi
  exit 0
}

# ── Stop hook: Save test results for sharing across hooks ────────
# typecheck-stop.sh saves test-runner output here so orchestration-stop
# and test-perf-stop can read it instead of re-running tests.

# Select one project runner from its scripts/config before inspecting installed
# binaries. This avoids choosing a transitive runner dependency by accident.
hook_select_test_runner() {
  local repo_root="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
  local test_script="" all_scripts=""

  if [ -f "$repo_root/package.json" ] && command -v jq >/dev/null 2>&1; then
    test_script=$(jq -r '.scripts.test // empty' "$repo_root/package.json" 2>/dev/null || true)
    all_scripts=$(jq -r '.scripts // {} | values[]' "$repo_root/package.json" 2>/dev/null || true)
  fi

  case "$test_script" in
    *rstest*) echo "rstest"; return 0 ;;
    *vitest*) echo "vitest"; return 0 ;;
    *jest*) echo "jest"; return 0 ;;
    *"bun test"*) echo "bun"; return 0 ;;
  esac

  for runner in vitest rstest jest; do
    if printf '%s\n' "$all_scripts" | grep -qw "$runner"; then
      echo "$runner"
      return 0
    fi
    for config in "$repo_root/$runner.config."*; do
      if [ -f "$config" ]; then
        echo "$runner"
        return 0
      fi
    done
  done

  for runner in vitest rstest jest; do
    if [ -x "$repo_root/node_modules/.bin/$runner" ] || command -v "$runner" >/dev/null 2>&1; then
      echo "$runner"
      return 0
    fi
  done
  return 0
}

hook_run_related_tests() {
  local repo_root="$1"
  local changed_files="$2"
  local runner bin="" abs_changed="" test_files=""

  [ -n "$changed_files" ] || return 0
  runner=$(hook_select_test_runner "$repo_root")
  for file in $changed_files; do
    case "$file" in
      /*) abs_changed="$abs_changed $file" ;;
      *) abs_changed="$abs_changed $repo_root/$file" ;;
    esac
  done

  if [ -n "$runner" ]; then
    bin="$repo_root/node_modules/.bin/$runner"
    [ -x "$bin" ] || bin=$(command -v "$runner" 2>/dev/null || true)
    if [ -z "$bin" ]; then
      echo "Configured test runner '$runner' not found. Install dependencies before finishing." >&2
      return 127
    fi
  fi

  case "$runner" in
    bun)
      "$bin" run --cwd "$repo_root" test
      return $?
      ;;
    rstest)
      "$bin" run --related $abs_changed
      return $?
      ;;
    vitest)
      "$bin" related --run --passWithNoTests $abs_changed
      return $?
      ;;
    jest)
      "$bin" --findRelatedTests $abs_changed --passWithNoTests
      return $?
      ;;
  esac

  for file in $changed_files; do
    local base="${file%.*}" ext="${file##*.}" suffix candidate
    for suffix in test spec; do
      candidate="$repo_root/${base}.${suffix}.${ext}"
      [ -f "$candidate" ] && test_files="$test_files $candidate"
    done
  done
  if [ -n "$test_files" ]; then
    bun test $test_files
    return $?
  fi
  return 0
}

hook_stop_save_test_results() {
  local status="$1"  # PASS or FAIL
  local output="$2"  # full test-runner output (optional)
  echo "$status" > "$_hook_session_dir/shared-test-status" 2>/dev/null || true
  if [ -n "$output" ]; then
    echo "$output" > "$_hook_session_dir/shared-test-output" 2>/dev/null || true
  fi
}

hook_stop_get_test_status() {
  cat "$_hook_session_dir/shared-test-status" 2>/dev/null || echo ""
}
