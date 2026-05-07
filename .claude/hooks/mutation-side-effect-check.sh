#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Check 1: Side-effect fetch calls should use useMutation ──────
# fetch() with method: DELETE/POST/PUT/PATCH outside mutationFn
# should be wrapped in useMutation for proper loading/error state.
# Only fire in React component/route/hook files, not utility/lib files.

# Gate: only check files that are React components or hooks
file_content=$(cat "$file_path")
is_react_file=false
if echo "$file_path" | grep -qE '/(routes|components|hooks|pages|features)/'; then
  is_react_file=true
elif echo "$file_content" | grep -qE "from\s+['\"]react['\"]|from\s+['\"]@tanstack/"; then
  is_react_file=true
fi

if [ "$is_react_file" = true ]; then
  # Check added lines for side-effect fetch calls
  side_effect_fetches=$(echo "$added_lines" | grep -E "method:\s*['\"]?(DELETE|POST|PUT|PATCH)['\"]?" || true)

  if [ -n "$side_effect_fetches" ]; then
    # Count side-effect methods in new code vs mutationFn wrappers in new code.
    # File-level useMutation check is too broad — a file can have one mutation
    # but add new raw fetches that bypass it.
    new_fetch_count=$(echo "$side_effect_fetches" | wc -l | tr -d '[:space:]')
    new_mutation_count=$(echo "$added_lines" | grep -cE 'mutationFn|useMutation' 2>/dev/null || true)
    new_mutation_count=${new_mutation_count:-0}
    new_mutation_count=$(echo "$new_mutation_count" | tr -d '[:space:]')

    if [ "$new_fetch_count" -gt "$new_mutation_count" ]; then
      if ! hook_has_escape "inline-mutation"; then
        hook_warn "Side-effect fetch (DELETE/POST/PUT/PATCH) without useMutation. ${new_fetch_count} fetch(es) but only ${new_mutation_count} mutation wrapper(s) in new code. Wrap in useMutation hook. Escape: // allow: inline-mutation [reason]"
      fi
    fi
  fi
fi

exit 0
