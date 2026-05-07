#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/_hook-lib.sh"

hook_parse_edit_write
hook_skip_generated
hook_filter_extensions "md|mdx|markdown"
hook_get_added_lines

# Escape hatches (any of these in the file skips all checks):
#   <!-- allow: prose-style [reason] -->
#   // allow: prose-style [reason]
if grep -qE '<!--[[:space:]]*allow:[[:space:]]*prose-style\b' "$file_path" 2>/dev/null; then
  exit 0
fi
if hook_has_escape "prose-style"; then
  exit 0
fi

# Pre-filter: drop fenced/indented code lines, strip inline code spans + URLs.
# awk tracks fence state across the changed-line stream so content inside a
# fenced block is skipped. Lines added incrementally into a pre-existing fenced
# block can still false-positive (no full-file context); escape hatch handles
# those rare cases.
prose_lines=$(printf '%s\n' "$added_lines" \
  | awk '
    BEGIN { in_fence = 0 }
    /^\+?[[:space:]]*```/ { in_fence = !in_fence; next }
    in_fence == 0 { print }
  ' \
  | grep -vE '^\+?[[:space:]]{4,}' \
  | sed -E 's/`[^`]*`//g' \
  | sed -E 's#https?://[^[:space:])]+##g')

if [ -z "$prose_lines" ]; then
  exit 0
fi

# ── Check 1: Em dashes (U+2014) ─────────────────────────────────
if printf '%s' "$prose_lines" | grep -q '—'; then
  hook_block "No em dashes (—) in prose. Use commas, periods, or parentheses."
fi

# ── Check 2: Canned AI openers ──────────────────────────────────
if printf '%s' "$prose_lines" | grep -qiE "(Let'?s dive in|Here'?s why\b|In conclusion\b|In today'?s (digital|fast-paced) (landscape|world))"; then
  hook_block "Drop canned opener (Let's dive in / Here's why / In conclusion / In today's digital landscape). Open with the point."
fi

# ── Check 3: AI-tell words (hard list — rarely legitimate) ──────
if printf '%s' "$prose_lines" | grep -qiE '\b(delv(e|ing|es|ed)|tapestry|realm|pivotal|underscor(e|es|ed|ing))\b'; then
  hook_block "AI-tell word (delve/tapestry/realm/pivotal/underscore). Plain English instead."
fi

# ── Check 4: AI-tell words (soft list — warn, common in tech) ───
if printf '%s' "$prose_lines" | grep -qiE '\b(leverag(e|es|ed|ing)|foster(s|ed|ing)?|intricate|nuanced|robust|comprehensive|significantly|showcas(e|es|ed|ing))\b'; then
  hook_warn "Possible AI-tell (leverage|foster|intricate|nuanced|robust|comprehensive|significantly|showcase). Consider plainer alternative."
fi

# ── Check 5: "not just X, but/it's Y" contrast framing ──────────
if printf '%s' "$prose_lines" | grep -qiE "\bnot just\b[^.]{1,80}\b(but|it'?s|they'?re|it is|they are)\b"; then
  hook_warn "Drop 'not just X, but Y' framing. State the point directly."
fi

# ── Check 6: Heavy transitions ──────────────────────────────────
if printf '%s' "$prose_lines" | grep -qE '(^|[[:space:]])(Moreover|Furthermore|Additionally|Nevertheless),?[[:space:]]'; then
  hook_warn "Use 'but', 'also', or 'so' instead of Moreover/Furthermore/Additionally/Nevertheless."
fi

# ── Check 7: Latin abbrevs (matches CLAUDE.md UX Copy rule) ─────
if printf '%s' "$prose_lines" | grep -qE '\b(e\.g\.|i\.e\.|etc\.)'; then
  hook_warn "Use 'for example' / 'that is' / 'and so on' instead of e.g. / i.e. / etc."
fi

# ── Check 8: Rule-of-three praise lists (warn — high false-positive) ──
# Only flag when three positive adjectives chain with comma + 'and'.
rot_words='(fast|efficient|reliable|scalable|powerful|flexible|simple|elegant|secure|seamless|intuitive)'
if printf '%s' "$prose_lines" | grep -qiE ",[[:space:]]*$rot_words[[:space:]]*,[[:space:]]*and[[:space:]]+$rot_words\b"; then
  hook_warn "Possible rule-of-three (fast, efficient, and reliable). Pick the one that matters."
fi

exit 0
