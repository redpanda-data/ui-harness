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

# Plain code cannot contain interface copy. Skip unless the edit has a string, visible
# JSX, interpolation, or a comment-level term this hook checks.
case "$added_lines" in
  *\"*|*"'"*|*'`'*|*'>'*'<'*|*'${'*|*[Mm][Aa][Kk][Ee]*[Pp][Oo][Pp]*) ;;
  *[Ww][Hh][Ii][Tt][Ee][Ll][Ii][Ss][Tt]*|*[Bb][Ll][Aa][Cc][Kk][Ll][Ii][Ss][Tt]*|*[Mm][Aa][Ss][Tt][Ee][Rr]*|*[Ss][Ll][Aa][Vv][Ee]*) ;;
  *) exit 0 ;;
esac

# UI-ish added lines only: TS/TSX string literals or visible JSX text.
# Some slop directives are useful to catch in comments too; those checks
# intentionally use all added lines and still honor the escape hatch above.
_ux_ui_lines=$(printf '%s\n' "$added_lines" | grep -E "([\"'][^\"']+[\"']|>[^<>{}][^<>{}]*<)" || true)

# ── Check 1: Ban exclamation points at end of string literals ─────

if echo "$added_lines" | grep -qE "!['\"]|!\\\\n|!\s*['\"]"; then
  if ! echo "$added_lines" | grep -E '!["\x27]' | grep -qE '!==|!=|!important|http'; then
    hook_warn "No ! in UI text. Remove it."
  fi
fi

# ── Check 2: Ban "successfully" in UI text ────────────────────────

if echo "$added_lines" | grep -qiE "(['\"])[^'\"]*successfully[^'\"]*\1"; then
  hook_warn "Drop 'successfully'. Past-tense verb: 'Topic created' not 'Topic successfully created'."
fi

if [ -n "$_ux_ui_lines" ] && printf '%s\n' "$_ux_ui_lines" | grep -qiE '\b(has|have)[[:space:]]+been[[:space:]]+(created|updated|deleted|saved|added|removed|completed|configured|enabled|disabled)\b'; then
  hook_warn "Use subject + past tense for completion copy: 'Topic created', not 'Topic has been created'."
fi

# ── Check 3: Ban "click here" / bare "here" link text ────────────

case "$file_path" in
  *.tsx)
    if echo "$added_lines" | grep -qiE '>[[:space:]]*(click here|here)[[:space:]]*<'; then
      hook_warn "No 'click here' link text. Descriptive destination text instead."
    fi
    ;;
esac

# ── Check 4: Ban blame language ───────────────────────────────────

if echo "$added_lines" | grep -qiE "(['\"])[^'\"]*\b(oops|uh oh|oh no|whoops)\b[^'\"]*\1"; then
  hook_warn "No casual error language. State problem + solution clearly."
fi

# ── Check 5: Warn on possessive pronouns in titles/nav ────────────

if echo "$added_lines" | grep -qE "(['\"])(My |Your )[A-Z]"; then
  hook_warn "No possessives in titles/nav. 'Settings' not 'My Settings'."
fi

# ── Check 6: Ban "Yes"/"No" button labels ─────────────────────────

case "$file_path" in
  *.tsx)
    if echo "$added_lines" | grep -qE '<Button[^>]*>[[:space:]]*(Yes|No)[[:space:]]*</Button>'; then
      hook_warn "No Yes/No button labels. Action verbs: 'Delete cluster'/'Keep cluster'."
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
    hook_warn "Capitalize Redpanda product names: Admin API, Schema Registry, HTTP Proxy, Redpanda Console."
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

# ── Check 15: Courtesy words ─────────────────────────────────────

if echo "$added_lines" | grep -qE "(['\"])Please [^'\"]*\1"; then
  hook_warn "Use 'Please' sparingly, only for real inconvenience. Otherwise write the action directly."
fi

if [ -n "$_ux_ui_lines" ] && printf '%s\n' "$_ux_ui_lines" | grep -qiE '\b(sorry|thank you)\b'; then
  hook_warn "Use 'sorry' and 'thank you' sparingly, only for real inconvenience."
fi

if [ -n "$_ux_ui_lines" ] && printf '%s\n' "$_ux_ui_lines" | grep -qiE '\b(behaviour|colour|organisation|licence)\b'; then
  hook_warn "Use American English: behavior, color, organization, license."
fi

# ── Check 16: Ban non-inclusive terminology ───────────────────────

if echo "$added_lines" | grep -qiE '\b(whitelist|blacklist|master|slave)\b'; then
  hook_warn "Inclusive terms: allowlist/denylist, leader/follower, primary/secondary."
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

# ── Check 21: Ban em dashes in UI copy ───────────────────────────

if [ -n "$_ux_ui_lines" ] && printf '%s\n' "$_ux_ui_lines" | grep -q "—"; then
  hook_warn "No em dashes in UI text. Use a period, colon, or parentheses."
fi

# ── Check 22: Warn on marketing buzzwords in UI copy ─────────────

if [ -n "$_ux_ui_lines" ] && printf '%s\n' "$_ux_ui_lines" | grep -qiE '\b(seamless|effortless|frictionless|game-changing|game changing|best-in-class|world-class|cutting-edge|next-generation|revolutionary|innovative|intuitive|robust|powerful|comprehensive|unlock|unleash|elevate|supercharge|delight|delightful)\b'; then
  hook_warn "Marketing buzzword in UI text. Say the concrete user benefit."
fi

# ── Check 23: Ban "not just X, it is Y" AI contrast frame ────────

if [ -n "$_ux_ui_lines" ] && printf '%s\n' "$_ux_ui_lines" | grep -qiE "\bnot[[:space:]]+just[[:space:]][^,.;!?]{2,80}[,;]?[[:space:]]+(it'?s|it[[:space:]]+is|this[[:space:]]+is|we'?re|we[[:space:]]+are|they'?re|they[[:space:]]+are)[[:space:]]+"; then
  hook_warn "No 'not just X, it is Y' framing. State the value directly."
fi

# ── Check 24: Warn on "X theater" slop phrasing ─────────────────

if [ -n "$_ux_ui_lines" ] && printf '%s\n' "$_ux_ui_lines" | grep -qiE '\b(security|compliance|innovation|process|performance|productivity|collaboration|automation|observability|governance|workflow|agile|testing|design|ai)[ -]+theater\b'; then
  hook_warn "No 'X theater' phrasing in UI text. Name the actual risk or behavior."
fi

# ── Check 25: Warn on aphoristic cadence ────────────────────────

if [ -n "$_ux_ui_lines" ] && printf '%s\n' "$_ux_ui_lines" | grep -qiE "\b(less|more)[[:space:]][^,.;:!?]{2,80},[[:space:]]*(more|less)[[:space:]][^\"']{2,80}|\b(isn'?t|is[[:space:]]+not|not)[[:space:]]+about[[:space:]][^,.;:!?]{2,80},?[[:space:]]+(it'?s|it[[:space:]]+is)[[:space:]]+about\b|[^.!?]{2,80}\.[[:space:]]+(no|not)[[:space:]][^.!?]{2,80}\.[[:space:]]+just[[:space:]][^.!?]{2,80}\."; then
  hook_warn "Aphoristic cadence in UI text. Use direct product copy."
fi

# ── Check 26: Warn on repeated section kickers ──────────────────

_repeated_kicker=$(printf '%s\n' "$_ux_ui_lines" \
  | grep -oiE '\b(Built for|Designed for|Made for|Created for|Use it to|Whether you|For teams that|When you need|From [^"<]{2,40} to)\b' \
  | sed -E 's/[Ff]rom .+ to/from x to/g' \
  | tr '[:upper:]' '[:lower:]' \
  | sort \
  | uniq -d \
  | head -1 || true)

if [ -n "$_repeated_kicker" ]; then
  hook_warn "Repeated section kicker ('$_repeated_kicker'). Vary structure or cut the repeated lead-in."
fi

# ── Check 27: Ban "make it pop" directives ──────────────────────

if printf '%s\n' "$added_lines" | grep -qiE '\bmake[[:space:]]+(it|this|that|the[[:space:]]+[[:alpha:]-]+)[[:space:]]+pop\b'; then
  hook_warn "No 'make it pop' direction. Specify the visual or copy change."
fi

# ── Check 28: Warn on generic CTA labels ────────────────────────

case "$file_path" in
  *.tsx)
    if printf '%s\n' "$added_lines" | grep -qiE '<(Button|button)\b[^>]*>[[:space:]]*(submit|ok|done)[[:space:]]*</(Button|button)>'; then
      hook_warn "generic CTA: name the action. Use 'Save changes' or 'Create topic', not 'Submit', 'OK', or 'Done'." "ux-copy-generic-cta"
    fi

    if printf '%s\n' "$added_lines" | grep -qiE "placeholder[[:space:]]*=[[:space:]]*['\"][^'\"]*(example[[:space:]]*:|e\.g\.)"; then
      hook_warn "Input placeholder: show the format directly; omit 'Example' and 'e.g.'."
    fi

    if printf '%s\n' "$added_lines" | grep -qiE ">[^<]*learn more[.!?:;][[:space:]]*<|['\"][^'\"]*learn more[.!?:;][^'\"]*['\"]"; then
      hook_warn "Learn more links use sentence case with no trailing punctuation."
    fi
    ;;
esac

# ── Check 29: Warn on vague error messages ──────────────────────

if [ -n "$_ux_ui_lines" ] && printf '%s\n' "$_ux_ui_lines" | grep -qiE '\b(invalid input|something went wrong|an error occurred|error occurred|unknown error)\b'; then
  hook_warn "specific error: say what went wrong and how to fix it. 'Invalid input' names nothing." "ux-copy-specific-error"
fi

# ── Check 30: Warn on dead-end empty states ─────────────────────

if [ -n "$_ux_ui_lines" ] && printf '%s\n' "$_ux_ui_lines" | grep -qiE '\b(no data|no items found|nothing here|no results found)\b'; then
  hook_warn "empty state: explain why it is empty and offer the next action. Dead-end copy stalls the task." "ux-copy-empty-state"
fi

exit 0
