#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/../../shared/hook-lib.sh"

hook_parse_edit_write
hook_skip_ui_dirs
hook_skip_generated
hook_skip_tests
hook_filter_extensions "ts|tsx"
hook_get_added_lines

# ── Check 1: useState + useEffect sync pattern (derive don't sync) ──

case "$file_path" in
  *.tsx|*.jsx)
    if echo "$added_lines" | grep -qE '\buseState\b' && \
       echo "$added_lines" | grep -qE '\buseEffect\b'; then
      # Detect: useState setter called inside useEffect
      _setters=$(echo "$added_lines" | grep -oE '\bset[A-Z][a-zA-Z]*\(' || true)
      if [ -n "$_setters" ]; then
        # Check if any setter appears after useEffect
        if echo "$added_lines" | grep -qE 'useEffect\(.*set[A-Z]|useEffect\([^)]*\).*set[A-Z]'; then
          if ! hook_has_escape "derive-state"; then
            hook_warn "useState+useEffect sync detected. Derive with useMemo instead. Escape: // allow: derive-state [reason]"
          fi
        fi
      fi
    fi
    ;;
esac

# ── Check 2: Direct array mutation ────────────────────────────────

if echo "$added_lines" | grep -qE '\.(push|splice|unshift|pop|shift|reverse|sort)\(' && \
   echo "$added_lines" | grep -qE '(state|items|list|data|rows|entries|values)\.(push|splice|unshift|pop|shift|reverse|sort)\('; then
  if ! hook_has_escape "mutation"; then
    hook_warn "Possible array mutation. Use spread/filter/map for immutable updates. Escape: // allow: mutation [reason]"
  fi
fi

# ── Check 3: Direct object mutation via delete ────────────────────

if echo "$added_lines" | grep -qE '\bdelete\s+(state|props|data|config|options)\['; then
  if ! hook_has_escape "mutation"; then
    hook_warn "Object mutation via delete. Use destructuring or spread. Escape: // allow: mutation [reason]"
  fi
fi

# ── Check 4: Side effect in render body (localStorage/sessionStorage) ──

case "$file_path" in
  *.tsx|*.jsx)
    if echo "$added_lines" | grep -qE '\b(localStorage|sessionStorage)\.(setItem|removeItem|clear)\b'; then
      # Check it's not inside a useEffect or event handler
      if ! echo "$added_lines" | grep -qE '(useEffect|useCallback|onClick|onSubmit|onChange|handleClick|handleSubmit)'; then
        if ! hook_has_escape "side-effect"; then
          hook_warn "Storage write may be in render body. Move to useEffect or event handler. Escape: // allow: side-effect [reason]"
        fi
      fi
    fi
    ;;
esac

exit 0
