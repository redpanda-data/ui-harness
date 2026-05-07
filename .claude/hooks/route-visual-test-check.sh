#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests

# ── Only fire on route files ─────────────────────────────────────
if ! echo "$file_path" | grep -qE '/routes/'; then
  exit 0
fi

# Only fire on files new to git (not existing edits)
if git show HEAD:"$file_path" &>/dev/null 2>&1; then
  exit 0
fi

# Skip layout/root routes — visual tests target leaf routes
case "$(basename "$file_path")" in
  __root.*|_*.*) exit 0 ;;
esac

# ── Gate: only fire if browser test pattern exists in project ────
# Check for existing *.browser.test.* files OR @vitest/browser dep.
# If neither exists, project hasn't adopted visual regression testing.

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

_has_browser_tests=false

# Fast check: any browser test files in the repo?
if git ls-files '*.browser.test.ts' '*.browser.test.tsx' 2>/dev/null | head -1 | grep -q .; then
  _has_browser_tests=true
fi

# Fallback: check package.json for @vitest/browser
if [ "$_has_browser_tests" = false ]; then
  # Walk up from file to find nearest package.json
  _dir=$(dirname "$file_path")
  while [ "$_dir" != "/" ]; do
    if [ -f "$_dir/package.json" ] && grep -q '@vitest/browser' "$_dir/package.json" 2>/dev/null; then
      _has_browser_tests=true
      break
    fi
    _dir=$(dirname "$_dir")
  done
fi

if [ "$_has_browser_tests" = false ]; then
  exit 0
fi

# ── Check: does a sibling browser test exist? ────────────────────
base=$(basename "$file_path" | sed 's/\.[^.]*$//')
dir=$(dirname "$file_path")

_found_test=false
for ext in browser.test.ts browser.test.tsx; do
  if [ -f "$dir/$base.$ext" ]; then
    _found_test=true
    break
  fi
done

if [ "$_found_test" = false ]; then
  # One reminder per session
  _marker="$_hook_session_dir/visual-test-reminded"
  if [ -f "$_marker" ]; then
    exit 0
  fi
  touch "$_marker"

  hook_warn "New route '$base' has no visual regression test. Project uses browser tests — add '$base.browser.test.tsx' (vitest+playwright pattern)." "route-visual-test"
fi

exit 0
