#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/_hook-lib.sh"

hook_parse_edit_write
hook_filter_extensions "css|scss|sass|less|tsx"
hook_get_added_lines

# ── Ban !important ─────────────────────────────────────────────────

if echo "$added_lines" | grep -qE '!important'; then
  hook_block "No !important — breaks Tailwind cascade. Fix specificity."
fi

# ── Ban raw hex/rgb in CSS files ──────────────────────────────────

case "$file_path" in
  *.css|*.scss|*.sass|*.less)
    if echo "$added_lines" | grep -qE '#[0-9a-fA-F]{3,8}\b' && \
       ! echo "$added_lines" | grep -qE '@(apply|theme|layer)'; then
      hook_block "No raw hex colors. Use design tokens: var(--destructive)."
    fi
    ;;
esac

# ── Ban 100vh (use 100dvh for mobile) ────────────────────────────

case "$file_path" in
  *.css|*.scss|*.sass|*.less)
    if echo "$added_lines" | grep -qE '\b100vh\b'; then
      hook_warn "Use 100dvh not 100vh. 100vh ignores mobile address bar."
    fi
    ;;
esac

# ── Ban width: 100vw (causes horizontal scrollbar) ───────────────

case "$file_path" in
  *.css|*.scss|*.sass|*.less)
    if echo "$added_lines" | grep -qE 'width:\s*100vw'; then
      hook_warn "Use width:100% not 100vw. 100vw includes scrollbar, causes overflow."
    fi
    ;;
esac

# ── Ban user-scalable=no (WCAG zoom violation) ──────────────────

if echo "$added_lines" | grep -qE 'user-scalable\s*=\s*no'; then
  hook_block "user-scalable=no is WCAG 1.4.4 violation. Users must zoom."
fi

exit 0
