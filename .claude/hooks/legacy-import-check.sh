#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

# ── Gate: only fire in React/component files ─────────────────────
# Skip config files, scripts, etc.
case "$file_path" in
  *.config.*|*.setup.*|*eslint*|*biome*) exit 0 ;;
esac

# ── Check 1: Ban @redpanda-data/ui imports in new code ───────────
# Legacy Chakra-based library. New features must use redpanda-ui registry.

if echo "$added_lines" | grep -qE "from\s+['\"]@redpanda-data/ui"; then
  # Allow if file is in a known legacy directory
  if echo "$file_path" | grep -qE '/(legacy|deprecated|chakra)/'; then
    : # skip legacy directories
  elif ! hook_has_escape "legacy-import"; then
    hook_warn "Import from @redpanda-data/ui (legacy Chakra). Use redpanda-ui registry components instead. Escape: // allow: legacy-import [reason]" "legacy-import-chakra"
  fi
fi

# ── Check 2: Ban direct lucide-react imports ─────────────────────
# Icons should come from components/icons barrel for consistency.

if echo "$added_lines" | grep -qE "from\s+['\"]lucide-react['\"]"; then
  # Only fire if a components/icons barrel exists in the project
  _has_barrel=false
  _dir=$(dirname "$file_path")
  while [ "$_dir" != "/" ]; do
    if [ -d "$_dir/components/icons" ] || [ -f "$_dir/components/icons.tsx" ] || [ -f "$_dir/components/icons/index.ts" ] || [ -f "$_dir/components/icons/index.tsx" ]; then
      _has_barrel=true
      break
    fi
    # Check src/ subdirectory too
    if [ -d "$_dir/src/components/icons" ] || [ -f "$_dir/src/components/icons.tsx" ]; then
      _has_barrel=true
      break
    fi
    _dir=$(dirname "$_dir")
  done

  if [ "$_has_barrel" = true ]; then
    if ! hook_has_escape "lucide-direct"; then
      hook_warn "Direct lucide-react import. Use components/icons barrel for consistent icon usage. Escape: // allow: lucide-direct [reason]" "legacy-import-lucide"
    fi
  fi
fi

# ── Check 3: Flag raw HTML elements that have registry equivalents ─
# Only in .tsx files (JSX context)

case "$file_path" in
  *.tsx)
    # Detect raw <button (not <Button) in JSX — but skip HTML in strings/comments
    raw_button=$(echo "$added_lines" | grep -E '<button(\s|>|$)' | grep -vE '//.*<button|/\*.*<button|".*<button|`.*<button' || true)
    if [ -n "$raw_button" ]; then
      if ! hook_has_escape "raw-html"; then
        hook_warn "Raw <button> in JSX. Use <Button> from UI registry (@/components/ui/button). Escape: // allow: raw-html [reason]" "legacy-import-raw-button"
      fi
    fi

    # Detect raw <input (not <Input)
    raw_input=$(echo "$added_lines" | grep -E '<input(\s|>|$)' | grep -vE '//.*<input|".*<input|`.*<input|type="hidden"' || true)
    if [ -n "$raw_input" ]; then
      if ! hook_has_escape "raw-html"; then
        hook_warn "Raw <input> in JSX. Use <Input> from UI registry (@/components/ui/input). Escape: // allow: raw-html [reason]" "legacy-import-raw-input"
      fi
    fi

    # Detect raw <a href (not <Link)
    raw_link=$(echo "$added_lines" | grep -E '<a\s+href' | grep -vE '//.*<a|".*<a|`.*<a' || true)
    if [ -n "$raw_link" ]; then
      if ! hook_has_escape "raw-html"; then
        hook_warn "Raw <a href> in JSX. Use <Link> from TanStack Router or UI registry. Escape: // allow: raw-html [reason]" "legacy-import-raw-link"
      fi
    fi

    # Detect raw headings <h1>-<h6> (should use Typography/Heading)
    raw_heading=$(echo "$added_lines" | grep -E '<h[1-6](\s|>)' | grep -vE '//.*<h[1-6]|".*<h[1-6]' || true)
    if [ -n "$raw_heading" ]; then
      if ! hook_has_escape "raw-html"; then
        hook_warn "Raw <h1>-<h6> in JSX. Use Heading/Text from Typography components. Escape: // allow: raw-html [reason]" "legacy-import-raw-heading"
      fi
    fi

    # Detect raw <p> (should use Text component)
    raw_p=$(echo "$added_lines" | grep -E '<p(\s|>)' | grep -vE '//.*<p|".*<p|`.*<p|<pre|<param|<path|<pattern|<progress' || true)
    if [ -n "$raw_p" ]; then
      if ! hook_has_escape "raw-html"; then
        hook_warn "Raw <p> in JSX. Use Text from Typography components. Escape: // allow: raw-html [reason]" "legacy-import-raw-p"
      fi
    fi

    # Detect raw <select> (should use Select from registry)
    raw_select=$(echo "$added_lines" | grep -E '<select(\s|>)' | grep -vE '//.*<select|".*<select' || true)
    if [ -n "$raw_select" ]; then
      if ! hook_has_escape "raw-html"; then
        hook_warn "Raw <select> in JSX. Use <Select> from UI registry. Escape: // allow: raw-html [reason]" "legacy-import-raw-select"
      fi
    fi
    ;;
esac

exit 0
