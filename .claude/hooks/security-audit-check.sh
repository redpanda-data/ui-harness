#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

# PostToolUse Edit|Write: OWASP + STRIDE subset + LLM trust patterns.
# Complements llm-failure-mode-check (SSRF, shapes), ts-no-escape
# (types), unhappy-path (silent fallbacks). Covers the gaps.

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

hook_has_escape "security-audit" && exit 0
scan=$(printf '%s' "$added_lines" | sed 's/^+//')

# A03 Injection: SQL/template concat into query()
if printf '%s' "$scan" | grep -qE '\b(query|execute|raw)\(\s*`[^`]*\$\{'; then
  hook_block "A03 Injection: template concat into query(). Use parameterized queries. [ETHOS: No Type Escape Hatches]" "security-a03-sql"
fi

# A02 Crypto: hardcoded secret-shaped literals
if printf '%s' "$scan" | grep -qE '(api[_-]?key|secret|password|token|private[_-]?key)\s*[:=]\s*["'\''][A-Za-z0-9+/=_-]{16,}["'\'']' -i; then
  if ! printf '%s' "$scan" | grep -qE '(process\.env|import\.meta\.env|@/env|// allow: secret-literal)'; then
    hook_block "A02 Crypto: hardcoded secret-shaped literal. Use env.ts / process.env. [ETHOS: User Sovereignty]" "security-a02-secret"
  fi
fi

# A02 Crypto: MD5 / SHA1 for passwords
if printf '%s' "$scan" | grep -qE '\b(createHash|crypto\.createHash)\(\s*["'\''](md5|sha1)["'\'']'; then
  if printf '%s' "$scan" | grep -qiE '(password|passwd|pwd|credential)'; then
    hook_block "A02 Crypto: MD5/SHA1 on password-shaped data. Use bcrypt/scrypt/argon2." "security-a02-weakhash"
  fi
fi

# A05 Misconfig: eval / new Function / innerHTML with variable
if printf '%s' "$scan" | grep -qE '\beval\(\s*[A-Za-z_]'; then
  hook_block "A05 Misconfig: eval() with variable arg. Do not evaluate user data." "security-a05-eval"
fi
if printf '%s' "$scan" | grep -qE '\bnew\s+Function\('; then
  hook_block "A05 Misconfig: new Function() is eval in disguise." "security-a05-newfunc"
fi
if printf '%s' "$scan" | grep -qE '\.innerHTML\s*=\s*[A-Za-z_][A-Za-z0-9_.]*\b'; then
  if ! printf '%s' "$scan" | grep -qE '(DOMPurify|sanitize|// allow: innerHTML)'; then
    hook_block "A05 Misconfig: innerHTML = var without DOMPurify. Use textContent, setHTML, or sanitize." "security-a05-innerhtml"
  fi
fi
if printf '%s' "$scan" | grep -qE 'dangerouslySetInnerHTML'; then
  if ! printf '%s' "$scan" | grep -qE '(DOMPurify|sanitize|// allow: dangerouslyset)'; then
    hook_block "A05 Misconfig: dangerouslySetInnerHTML without DOMPurify wrapper." "security-a05-dangerously"
  fi
fi

# A08 Deserialization: unsafe YAML
if printf '%s' "$scan" | grep -qE '\bYAML\.load\(|\byaml\.load\('; then
  hook_block "A08 Deserialization: unsafe YAML.load. Use yaml.safeLoad / js-yaml safe parser." "security-a08-yaml"
fi

# STRIDE-I (Info disclosure): err.stack in response body
if printf '%s' "$scan" | grep -qE '\.(json|send)\(.*\berr(\.stack|or\.stack)'; then
  hook_block "STRIDE-I: error stack in response. Return generic message, log detail server-side." "security-stride-info"
fi

# LLM Trust Boundary: LLM response used as URL fetch target
# (already covered by llm-failure-mode-check ssrf path -- skip)

exit 0
