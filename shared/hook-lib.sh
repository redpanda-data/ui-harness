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

# ── Structured session log (JSONL) ──────────────────────────────
# Append one JSON line per hook decision. Used by metrics-summary-stop.sh
# and /hook-audit skill. Fails silently — never blocks a hook.
_hook_log_file="$_hook_session_dir/structured.jsonl"

_hook_log_entry() {
  local decision="$1" rule="$2" hook="${3:-$(basename "$0" .sh)}"
  local target="${file_path:-}"
  # Strip repo root for privacy — store relative path only
  if [ -n "$target" ]; then
    local root
    root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    target="${target#"$root"/}"
  fi
  printf '{"ts":%d,"hook":"%s","rule":"%s","decision":"%s","file":"%s"}\n' \
    "$(date +%s)" "$hook" "$rule" "$decision" "$target" \
    >> "$_hook_log_file" 2>/dev/null || true
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
_hook_drain_log="${HOME}/.claude/hook-metrics/bash-drains.jsonl"

_hook_log_bash_drain() {
  local drain_type="$1" cmd_snippet="$2" bytes="${3:-0}"
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

# ── PostToolUse: Parse stdin, gate on Edit|Write, extract file_path ──

hook_parse_edit_write() {
  _hook_assert_bound_worktree
  _hook_input=$(cat)
  _hook_tool_name=$(echo "$_hook_input" | jq -r '.tool_name // empty' 2>/dev/null || true)

  if [ "$_hook_tool_name" != "Edit" ] && [ "$_hook_tool_name" != "Write" ]; then
    exit 0
  fi

  file_path=$(echo "$_hook_input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)

  if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
    _hook_debug "skip: file_path empty or missing ($file_path)"
    exit 0
  fi

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
    exit 0
  fi
  local exts="$1"
  local match=false
  local IFS='|'
  for ext in $exts; do
    case "$file_path" in
      *."$ext") match=true; break ;;
    esac
  done
  if [ "$match" = false ]; then
    _hook_debug "skip: extension mismatch (wanted $exts, got ${file_path##*.})"
    exit 0
  fi
}

# ── Skip test files ──────────────────────────────────────────────

hook_skip_tests() {
  case "$file_path" in
    *.test.*|*.spec.*) _hook_debug "skip: test file"; exit 0 ;;
  esac
  if echo "$file_path" | grep -qE '/__tests__/'; then
    _hook_debug "skip: __tests__ directory"
    exit 0
  fi
}

# ── Skip auto-generated files ────────────────────────────────────

hook_skip_generated() {
  case "$file_path" in
    *.gen.ts|*.gen.tsx|*.gen.js) _hook_debug "skip: generated (.gen)"; exit 0 ;;
    *_pb.ts|*_pb.js) _hook_debug "skip: generated (_pb)"; exit 0 ;;
    *_connectquery.ts) _hook_debug "skip: generated (_connectquery)"; exit 0 ;;
  esac
  # Skip files with @generated marker
  if head -5 "$file_path" 2>/dev/null | grep -qE '(@generated|auto-generated|DO NOT EDIT)'; then
    _hook_debug "skip: generated (@generated marker)"
    exit 0
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
  if echo "$file_path" | grep -qE "/($_ui_dirs)/"; then
    _repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    if [ -f "$_repo_root/registry.json" ]; then
      # Registry repo — remind to rebuild registry
      echo '{"suppressOutput":true,"systemMessage":"You are editing a UI registry component. Remember to rebuild registry.json and update CHANGELOG.md when done."}' >&2
    elif [ -f "$_repo_root/components.json" ] || [ -f "$_repo_root/cli.json" ]; then
      # Consumer repo — warn that this is a registry-sourced component
      _component=$(basename "$file_path")
      echo "{\"suppressOutput\":true,\"systemMessage\":\"WARNING: You are modifying '$_component' which comes from the UI registry. Local changes will be overwritten on next registry pull. If this change is intentional, submit a PR upstream to the UI registry repo instead.\"}" >&2
    fi
    exit 0
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
    head_content=$(git show "HEAD:./$file_path" 2>/dev/null || true)
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
    exit 0
  fi
}

# ── Session-scoped changed files (for Stop hooks) ────────────────
# Returns files that: (a) are in current git diff, (b) were touched
# by this session via Edit/Write, and (c) were NOT dirty at session
# start. Falls back to full git diff if tracking data unavailable.
#
# Usage in Stop hooks:
#   source "path/to/hook-lib.sh"
#   session_changed=$(hook_session_changed_files "ts|tsx|js|jsx")
#   if hook_has_session_tracking; then ... fi

hook_session_changed_files() {
  local ext_filter="${1:-}"

  # Get current git diff
  local current_diff
  current_diff=$(git diff --name-only HEAD 2>/dev/null || true)

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
  # Formula: (current_diff ∩ touched) - baseline
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

    if [ -f "$baseline_file" ] && [ -s "$baseline_file" ]; then
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
# For project-wide tools (tsgo, doctor) that cannot target files,
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
# Cross-platform: uses python3 since macOS `date +%N` is unsupported.

_hook_start_ms=$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo 0)

_hook_elapsed_ms() {
  local now
  now=$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo "$_hook_start_ms")
  echo $((now - _hook_start_ms))
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
  local rule="${1:-$(basename "$0" .sh)}"
  _hook_debug "INFO [$rule]"
  _hook_track_violation "$rule"
  _hook_log_entry "info" "$rule"
  exit 0
}

hook_nudge() {
  local msg="$1"
  local rule="${2:-$(basename "$0" .sh)}"
  _hook_debug "NUDGE [$rule]: $msg"
  _hook_track_violation "$rule"
  _hook_log_entry "nudge" "$rule"
  if [ "$_hook_verbosity" = "normal" ]; then
    echo "{\"suppressOutput\":true,\"systemMessage\":\"[nudge] $msg\"}" >&2
  fi
  exit 0
}

hook_block_strict() {
  local msg="$1"
  local rule="${2:-$(basename "$0" .sh)}"
  _hook_debug "STRICT [$rule]: $msg"
  _hook_track_violation "$rule"
  _hook_log_entry "block-strict" "$rule"
  if [ "$_hook_verbosity" != "quiet" ]; then
    echo "{\"suppressOutput\":true,\"systemMessage\":\"[STRICT] $msg\"}" >&2
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
  local msg="$1"
  local label="${2:-$(basename "$0" .sh)}"
  _hook_debug "BLOCK [$label]: $msg"
  _hook_track_violation "$label"
  _hook_log_entry "block" "$label"
  if [ "$_hook_verbosity" != "quiet" ]; then
    echo "{\"suppressOutput\":true,\"systemMessage\":\"$msg\"}" >&2
  fi
  exit 2
}

# ── PostToolUse: Warn with systemMessage (exit 0) ───────────────

hook_warn() {
  local msg="$1"
  local label="${2:-$(basename "$0" .sh)}"
  _hook_debug "WARN [$label]: $msg"
  _hook_track_violation "$label"
  _hook_log_entry "warn" "$label"
  if [ "$_hook_verbosity" = "normal" ]; then
    echo "{\"suppressOutput\":true,\"systemMessage\":\"$msg\"}" >&2
  fi
  exit 0
}

# ── PreToolUse (Bash): Parse stdin, extract command ──────────────

hook_parse_bash() {
  _hook_assert_bound_worktree
  _hook_input=$(cat)
  _hook_tool_name=$(echo "$_hook_input" | jq -r '.tool_name // empty' 2>/dev/null || true)

  if [ "$_hook_tool_name" != "Bash" ]; then
    exit 0
  fi

  command=$(echo "$_hook_input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

  if [ -z "$command" ]; then
    exit 0
  fi
}

# ── PreToolUse: Deny with permissionDecision (exit 2) ────────────

hook_deny() {
  local msg="$1"
  local label="${2:-$(basename "$0" .sh)}"
  _hook_debug "DENY [$label]: $msg"
  _hook_track_violation "$label"
  _hook_log_entry "deny" "$label"
  echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\"},\"systemMessage\":\"$msg\"}" >&2
  exit 2
}

# ── Stop hook: Block with decision (exit 2) ──────────────────────

hook_stop_block() {
  local msg="$1"
  local reason
  reason=$(_safe_json_escape "$msg")
  echo "{\"decision\":\"block\",\"reason\":$reason}" >&2
  exit 2
}

# ── Stop hook: Append finding to shared file (no block) ──────────
# Quality-gate pattern: each Stop hook reports findings, then
# quality-gate-stop.sh aggregates and blocks ONCE with all issues.
# This avoids serial blocking where each hook blocks independently.

hook_stop_finding() {
  local msg="$1"
  # Delimiter separates findings so quality-gate-stop.sh can count issues (not lines)
  printf '%s\n---\n' "$msg" >> "$_hook_session_dir/stop-findings" 2>/dev/null || true
}

# ── Stop hook: Save test results for sharing across hooks ────────
# typecheck-stop.sh saves vitest output here so orchestration-stop
# and test-perf-stop can read it instead of re-running vitest.

hook_stop_save_test_results() {
  local status="$1"  # PASS or FAIL
  local output="$2"  # full vitest output (optional)
  echo "$status" > "$_hook_session_dir/shared-test-status" 2>/dev/null || true
  if [ -n "$output" ]; then
    echo "$output" > "$_hook_session_dir/shared-test-output" 2>/dev/null || true
  fi
}

hook_stop_get_test_status() {
  cat "$_hook_session_dir/shared-test-status" 2>/dev/null || echo ""
}
