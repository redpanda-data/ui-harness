#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/_hook-lib.sh"

hook_parse_edit_write
hook_filter_extensions "tsx"
hook_get_added_lines

# Read full file for context
file_content=$(cat "$file_path")

# Allow escape hatch: // allow: a11y-skip [reason]
if hook_has_escape "a11y-skip"; then
  exit 0
fi

# ── Check 1: Ban <img> without alt ──────────────────────────────────

if echo "$added_lines" | grep -qE '<img\b' && ! echo "$added_lines" | grep -qE '<img\b[^>]*\balt\s*='; then
  hook_block "<img> needs alt. Descriptive string or alt=\\\"\\\" for decorative. WCAG 1.1.1."
fi

# ── Check 2: Ban clickable div/span without keyboard support ────────

if echo "$added_lines" | grep -qE '<(div|span)\b[^>]*\bonClick\b'; then
  has_keyboard=false
  has_role=false
  has_tabindex=false

  if echo "$added_lines" | grep -qE '<(div|span)\b[^>]*\bon(KeyDown|KeyUp|KeyPress)\b'; then
    has_keyboard=true
  fi
  if echo "$added_lines" | grep -qE '<(div|span)\b[^>]*\brole\s*='; then
    has_role=true
  fi
  if echo "$added_lines" | grep -qE '<(div|span)\b[^>]*\btabIndex\b'; then
    has_tabindex=true
  fi

  if [ "$has_keyboard" = false ] || [ "$has_role" = false ] || [ "$has_tabindex" = false ]; then
    hook_block "Clickable <div>/<span> needs role+tabIndex+onKeyDown. Or use <button>. WCAG 2.1.1."
  fi
fi

# ── Check 3: Ban role="combobox" without required ARIA ────────────

if echo "$added_lines" | grep -qE 'role\s*=\s*["{]combobox'; then
  missing=""
  if ! echo "$file_content" | grep -qE 'aria-expanded\s*='; then
    missing="aria-expanded"
  fi
  if ! echo "$file_content" | grep -qE 'aria-controls\s*='; then
    missing="$missing${missing:+, }aria-controls"
  fi
  if [ -n "$missing" ]; then
    hook_block "role=\\\"combobox\\\" missing: $missing."
  fi
fi

# ── Check 4: Ban role="tablist" without role="tab" children ─────────

if echo "$added_lines" | grep -qE 'role\s*=\s*["{]tablist'; then
  if ! echo "$file_content" | grep -qE 'role\s*=\s*["{]tab[^l]'; then
    hook_block "role=\\\"tablist\\\" needs children with role=\\\"tab\\\" + role=\\\"tabpanel\\\"."
  fi
fi

# ── Check 5: Ban role="dialog" without aria-label/aria-labelledby ──

if echo "$added_lines" | grep -qE 'role\s*=\s*["{]dialog'; then
  if ! echo "$added_lines" | grep -qE 'aria-label(ledby)?\s*=' && ! echo "$file_content" | grep -qE 'role=.*dialog.*aria-label|aria-label.*role=.*dialog'; then
    hook_block "role=\\\"dialog\\\" needs aria-label or aria-labelledby."
  fi
fi

# ── Check: aria-invalid without aria-describedby ─────────────────

if echo "$added_lines" | grep -qE 'aria-invalid'; then
  if ! echo "$file_content" | grep -qE 'aria-describedby'; then
    hook_warn "aria-invalid without aria-describedby. Add error description reference for screen readers." "a11y-describedby"
  fi
fi

# ── Check: data-invalid without aria-invalid ─────────────────────
# data-invalid is a styling hook, not an ARIA attribute.
# Screen readers need aria-invalid to announce error state.

if echo "$added_lines" | grep -qE 'data-invalid'; then
  if ! echo "$file_content" | grep -qE 'aria-invalid'; then
    hook_warn "data-invalid used without aria-invalid. data-invalid is CSS-only — add aria-invalid for screen reader support. WCAG 3.3.1." "a11y-data-invalid"
  fi
fi

# ── Check: nested interactive elements ───────────────────────────
# Button inside TooltipTrigger, Link inside Button, etc.

if echo "$added_lines" | grep -qE '<(Button|button)[^>]*>.*<(Button|button|a |Link )'; then
  hook_warn "Possible nested interactive elements. Buttons/links inside buttons break a11y." "a11y-nested-interactive"
fi

exit 0
