#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Check: useState for pagination/sort/filter → suggest URL state ─
# These values should typically persist in URL for shareability.
# Pattern: useState with naming that suggests pagination, sort, or filter.

if echo "$file_path" | grep -qE '/routes/'; then
  url_state_candidates=$(echo "$added_lines" | grep -E '\b(page|pageIndex|pageSize|sort|sortBy|sortOrder|filter|search|tab|activeTab|selectedTab|query)\b' | grep -E 'useState' || true)

  if [ -n "$url_state_candidates" ]; then
    sample=$(echo "$url_state_candidates" | head -2 | sed 's/^+//' | tr '\n' ' ')
    if ! hook_has_escape "url-state"; then
      hook_warn "useState for pagination/sort/filter in route file. Consider persisting in URL via useSearch/validateSearch for shareable links. Found: $sample. Escape: // allow: url-state [reason]" "url-state-suggest"
    fi
  fi
fi

exit 0
