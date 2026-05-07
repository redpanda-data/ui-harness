#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests

# ── TDD session-level reminder (fires once per session) ─────────
# When creating new source files in testable directories, remind
# about TDD once per session. Not per-file — tests are per-feature,
# not per-file. The Stop hook enforces the actual gate.

# Only fire on files that are new (not in HEAD)
if git show HEAD:"$file_path" &>/dev/null; then
  exit 0  # File already existed, not a new creation
fi

# Only for testable directories
if ! echo "$file_path" | grep -qE '/(routes|components|hooks|features|modules)/'; then
  exit 0
fi

# One reminder per session — touch marker on first new source file
_tdd_marker="$_hook_session_dir/tdd-reminded"
if [ -f "$_tdd_marker" ]; then
  exit 0  # Already reminded this session
fi
touch "$_tdd_marker"

hook_warn "New source file created. Remember: run /tdd to write tests for this feature before finishing. Tests are per-feature, not per-file. Stop hook will enforce."

exit 0
