#!/bin/bash
# SessionStart: nudge once per session if rtk is missing. rtk is the
# output-compression proxy wired at PreToolUse Bash via rtk-rewrite.sh.
# Without it the hook is a no-op — correctness is unaffected, only
# token savings are missed.

set -eo pipefail
trap 'exit 0' ERR

if command -v rtk >/dev/null 2>&1; then
  exit 0
fi

# Emit once per CLAUDE_SESSION_ID to avoid repeating across SessionStart
# sub-events (resume, /clear). Fall back to pid-based marker if no session id.
_marker_dir="/tmp/claude-rtk-check"
mkdir -p "$_marker_dir" 2>/dev/null || true
_sid="${CLAUDE_SESSION_ID:-pid-$$}"
_marker="$_marker_dir/$_sid"
if [ -f "$_marker" ]; then
  exit 0
fi
touch "$_marker" 2>/dev/null || true

msg="rtk not installed — output-compression proxy missing (~60-90% token savings on git/cargo/test/gh). Install: brew install rtk  (or curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh). Harness fails open — no action required, just reduced efficiency."

# Escape for JSON.
esc=$(printf '%s' "$msg" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null) || esc="\"$msg\""
printf '{"hookSpecificOutput":{"additionalContext":%s}}\n' "$esc" >&2
exit 0
