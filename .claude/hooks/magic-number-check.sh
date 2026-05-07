#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Check 1: Inline staleTime/gcTime numbers ────────────────────
# Should use named constants: SHORT_STALE_TIME, LONG_STALE_TIME, etc.

if echo "$added_lines" | grep -qE '(staleTime|gcTime|cacheTime)\s*:\s*[0-9]'; then
  if ! hook_has_escape "stale-time"; then
    hook_warn "Inline staleTime/gcTime number. Use named constants (SHORT_STALE_TIME, etc.) from query client config. Escape: // allow: stale-time [reason]" "magic-number-stale"
  fi
fi

# ── Check 2: Numeric comparisons in proto-adjacent files ─────────
# Flag === N or !== N or > N patterns where N > 2 in files that import proto.

file_content=$(cat "$file_path")

_has_proto=false
if echo "$file_content" | grep -qE "from\s+['\"]@buf/|from\s+['\"].*_pb['\"]|from\s+['\"].*proto"; then
  _has_proto=true
fi

if [ "$_has_proto" = true ]; then
  # Find numeric comparisons with literals > 2 (skip 0, 1, 2 as common)
  magic_nums=$(echo "$added_lines" | grep -E '(===|!==|>=|<=|>|<)\s*[3-9][0-9]*\b' | grep -vE '\.length|index|page|limit|offset|count|size|max|min|timeout|interval|port' || true)

  if [ -n "$magic_nums" ]; then
    sample=$(echo "$magic_nums" | head -2 | sed 's/^+//' | tr '\n' ' ')
    if ! hook_has_escape "magic-number"; then
      hook_warn "Numeric literal in proto file comparison. Use enum constant from proto layer. Found: $sample. Escape: // allow: magic-number [reason]" "magic-number-proto"
    fi
  fi
fi

exit 0
