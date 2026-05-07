#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/_hook-lib.sh"

hook_parse_edit_write
hook_skip_generated
hook_filter_extensions "ts|tsx"
hook_get_added_lines

# Escape hatch: // allow: ux-copy [reason]
if hook_has_escape "ux-copy"; then
  exit 0
fi

# ── Check 1: Ban exclamation points at end of string literals ─────

if echo "$added_lines" | grep -qE "!['\"]|!\\\\n|!\s*['\"]"; then
  if ! echo "$added_lines" | grep -E '!["\x27]' | grep -qE '!==|!=|!important|http'; then
    hook_block "No ! in UI text. Remove it."
  fi
fi

# ── Check 2: Ban "successfully" in UI text ────────────────────────

if echo "$added_lines" | grep -qiE "(['\"])[^'\"]*successfully[^'\"]*\1"; then
  hook_block "Drop 'successfully'. Past-tense verb: 'Topic created' not 'Topic successfully created'."
fi

# ── Check 3: Ban "click here" / bare "here" link text ────────────

case "$file_path" in
  *.tsx)
    if echo "$added_lines" | grep -qiE '>[[:space:]]*(click here|here)[[:space:]]*<'; then
      hook_block "No 'click here' link text. Descriptive destination text instead."
    fi
    ;;
esac

# ── Check 4: Ban blame language ───────────────────────────────────

if echo "$added_lines" | grep -qiE "(['\"])[^'\"]*\b(oops|uh oh|oh no|whoops)\b[^'\"]*\1"; then
  hook_block "No casual error language. State problem + solution clearly."
fi

# ── Check 5: Warn on possessive pronouns in titles/nav ────────────

if echo "$added_lines" | grep -qE "(['\"])(My |Your )[A-Z]"; then
  hook_warn "No possessives in titles/nav. 'Settings' not 'My Settings'."
fi

# ── Check 6: Ban "Yes"/"No" button labels ─────────────────────────

case "$file_path" in
  *.tsx)
    if echo "$added_lines" | grep -qE '<Button[^>]*>[[:space:]]*(Yes|No)[[:space:]]*</Button>'; then
      hook_block "No Yes/No button labels. Action verbs: 'Delete cluster'/'Keep cluster'."
    fi
    ;;
esac

# ── Check 7: Warn on formatting in string literals ────────────────

if echo "$added_lines" | grep -qE '(\*\*[^*]+\*\*|__[^_]+__)'; then
  hook_warn "No bold/italic in UI text. Use component library formatting props."
fi

# ── Check 8: Warn on ALL CAPS for emphasis ────────────────────────

if echo "$added_lines" | grep -qE "(['\"])[^'\"]*\b[A-Z]{3,}\s+[A-Z]{3,}\b[^'\"]*\1"; then
  _caps_line=$(echo "$added_lines" | grep -E "(['\"])[^'\"]*\b[A-Z]{3,}\s+[A-Z]{3,}\b" | head -1)
  if ! echo "$_caps_line" | grep -qE '\b(HTTP|HTTPS|API|TLS|MTLS|OIDC|SASL|BYOC|VPC|CIDR|PSC|ACL|RBAC|AWS|GCP|DNS|URL|URI|SSH|SSL|IAM|ARN|EKS|GKE|CLI)\b'; then
    hook_warn "No ALL CAPS for emphasis. Sentence case. Exception: acronyms."
  fi
fi

# ── Check 9: Redpanda term capitalization (REDPANDA_KIT=1) ───────

if [ "${REDPANDA_KIT:-}" = "1" ]; then
  if echo "$added_lines" | grep -qiE "(['\"])[^'\"]*\b(admin api|schema registry|http proxy|redpanda console)\b[^'\"]*\1" && \
     ! echo "$added_lines" | grep -qE "(Admin API|Schema Registry|HTTP Proxy|Redpanda Console)"; then
    hook_block "Capitalize Redpanda product names: Admin API, Schema Registry, HTTP Proxy, Redpanda Console."
  fi

  if echo "$added_lines" | grep -qiE "(['\"])[^'\"]*\bthe console\b[^'\"]*\1"; then
    hook_warn "Use 'Redpanda Console' not 'the console'."
  fi
fi

# ── Check 10: Title Case detection in strings ─────────────────────

if echo "$added_lines" | grep -qE "(['\"])[A-Z][a-z]+\s+[A-Z][a-z]+\s+[A-Z][a-z]+" ; then
  _title_line=$(echo "$added_lines" | grep -E "(['\"])[A-Z][a-z]+\s+[A-Z][a-z]+\s+[A-Z][a-z]+" | head -1)
  if ! echo "$_title_line" | grep -qE '(Admin API|Schema Registry|HTTP Proxy|Redpanda Console|Dedicated Cloud|Bring Your Own Cloud|Private Service Connect|Virtual Private Cloud)'; then
    hook_warn "Possible Title Case. Use sentence case. Exception: product names."
  fi
fi

# ── Check 11: Spelled-out numbers (one through nine) ──────────────

if echo "$added_lines" | grep -qE "(['\"])[^'\"]*\b(one|two|three|four|five|six|seven|eight|nine)\b[^'\"]*\1"; then
  _num_line=$(echo "$added_lines" | grep -E "(['\"])[^'\"]*\b(one|two|three|four|five|six|seven|eight|nine)\b" | head -1)
  if ! echo "$_num_line" | grep -qiE '(one of|one or|one-time|one-way|two-factor|two-way|day one)'; then
    hook_warn "Use numerals (1-9) not spelled-out numbers in UI text."
  fi
fi

# ── Check 12: Ban "and/or" ────────────────────────────────────────

if echo "$added_lines" | grep -qE "(['\"])[^'\"]*\band/or\b[^'\"]*\1"; then
  hook_warn "No 'and/or'. Use 'and', 'or', or 'A, B, or both'."
fi

# ── Check 13: Ban "etc." in UI text ──────────────────────────────

if echo "$added_lines" | grep -qE "(['\"])[^'\"]*\betc\.[^'\"]*\1"; then
  hook_warn "No 'etc.' in UI. List specifics or use 'such as'."
fi

# ── Check 14: Ban "e.g." / "i.e." — suggest plain English ────────

if echo "$added_lines" | grep -qE "(['\"])[^'\"]*\b(e\.g\.|i\.e\.)[^'\"]*\1"; then
  hook_warn "No Latin abbrevs in UI. 'for example'/'that is' not 'e.g.'/'i.e.'."
fi

# ── Check 15: Ban "Please ..." imperative pattern in UI strings ───

if echo "$added_lines" | grep -qE "(['\"])Please [^'\"]*\1"; then
  hook_warn "No 'Please' prefix. Direct: 'Enter your email' not 'Please enter...'."
fi

# ── Check 16: Ban non-inclusive terminology ───────────────────────

if echo "$added_lines" | grep -qiE '\b(whitelist|blacklist|master|slave)\b'; then
  hook_block "Inclusive terms: allowlist/denylist, leader/follower, primary/secondary."
fi

# ── Check 17: Warn on "There is" / "There are" starters ─────────

if echo "$added_lines" | grep -qE "(['\"])(There is |There are )[^'\"]*\1"; then
  hook_warn "No 'There is/are' starters. Subject first."
fi

# ── Check 18: Warn on "via" in UI text ───────────────────────────

if echo "$added_lines" | grep -qE "(['\"])[^'\"]*\bvia\b[^'\"]*\1"; then
  hook_warn "No 'via' in UI. Use 'through'/'using'/'with'."
fi

# ── Check 19: Redundant phrasing in UI strings ───────────────────

if echo "$added_lines" | grep -qE "(['\"])[^'\"]*configuration and settings[^'\"]*\1"; then
  hook_warn "Redundant: 'configuration and settings'. Pick one term."
fi

if echo "$added_lines" | grep -qE "(['\"])[^'\"]*manage and configure[^'\"]*\1"; then
  hook_warn "Redundant: 'manage and configure'. Pick one verb."
fi

# ── Check 20: Inconsistent terminology (glossary) ────────────────

if echo "$added_lines" | grep -qE "(['\"])[^'\"]*routing rules[^'\"]*\1"; then
  hook_warn "Use 'routing policies' not 'routing rules' (matches docs)." "ux-copy-glossary"
fi

exit 0
