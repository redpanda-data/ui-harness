#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

file_content=$(cat "$file_path")

# Allow escape hatch: // allow: unhappy-path [reason]
if hook_has_escape "unhappy-path"; then
  exit 0
fi

# ── Check 1: Silent catch blocks ────────────────────────────────
# Catch blocks that swallow errors without setting state, re-throwing,
# or calling an error handler. Common anti-pattern: catch { fallback }
# which hides broken state from the user.

if echo "$added_lines" | grep -qE 'catch\s*(\([^)]*\))?\s*\{'; then
  # Look for catch blocks in added lines that don't set error state,
  # re-throw, or call error handlers
  _catch_context=$(echo "$added_lines" | grep -EA5 'catch\s*(\([^)]*\))?\s*\{' || true)

  if [ -n "$_catch_context" ]; then
    # Check if catch block has error handling
    _has_error_handling=false
    if echo "$_catch_context" | grep -qE 'setError|setState.*error|throw\b|onError|toast\.(error|warning)|console\.error|showError|formatToastError|ConnectError\.from'; then
      _has_error_handling=true
    fi

    if [ "$_has_error_handling" = false ]; then
      # Check for silent fallback pattern: catch { doSomethingElse }
      if echo "$_catch_context" | grep -qE 'catch.*\{[^}]*onChange|catch.*\{[^}]*setValue|catch.*\{[^}]*return\s+null|catch.*\{\s*\}|catch.*\{\s*//'; then
        if ! hook_has_escape "silent-catch"; then
          hook_warn "Catch block appears to swallow error silently. Set error state, show toast, or re-throw — don't hide failures from user. Escape: // allow: silent-catch [reason]" "unhappy-path-silent-catch"
        fi
      fi
    fi
  fi
fi

# ── Check 2: Error alert + form rendering without guard ─────────
# When deserialization or fetch fails, show error UI OR form, not both.
# Pattern: <Alert with error> then <form> below = user sees broken state.

_is_form_file=false
if echo "$file_content" | grep -qE '<form\b|useForm\(|handleSubmit'; then
  _is_form_file=true
fi

if [ "$_is_form_file" = true ]; then
  # Check for error Alert/Banner followed by form without early return
  if echo "$file_content" | grep -qE '(isError|parseError|deserializeError|error\s*&&).*<(Alert|Banner)'; then
    # Check if there's a guard (early return before form)
    if ! echo "$file_content" | grep -qE 'if\s*\((isError|parseError|deserializeError|error)\)\s*(return|throw)'; then
      if ! hook_has_escape "error-guard"; then
        hook_warn "Error state renders Alert but form still shows below. Add early return: if (error) return <ErrorState />. Escape: // allow: error-guard [reason]" "unhappy-path-error-guard"
      fi
    fi
  fi
fi

# ── Check 3: Async validation without cancellation ──────────────
# onChange mode + async validator without AbortController = race condition.
# Rapid edits fire multiple validations; stale results overwrite fresh ones.

if echo "$file_content" | grep -qE "mode:\s*['\"]onChange['\"]"; then
  if echo "$file_content" | grep -qE 'async.*validat|validat.*async'; then
    if ! echo "$file_content" | grep -qE 'AbortController|abort|cancel|debounce|useDebouncedCallback'; then
      if ! hook_has_escape "async-validation"; then
        hook_warn "Async validation with onChange mode but no cancellation/debounce. Rapid edits cause race conditions — add AbortController or debounce. Escape: // allow: async-validation [reason]" "unhappy-path-async-validation"
      fi
    fi
  fi
fi

# ── Check 4: Single error display (toast/alert shows only first) ─
# errors[0] or errors.at(0) — user only sees first of N errors.

if echo "$added_lines" | grep -qE 'errors?\[0\]|errors?\.at\(0\)|errors?\.find\('; then
  if ! echo "$file_content" | grep -qE 'errors?\.map\(|errors?\.forEach\(|errors?\.join\(|\.length\s*>\s*1'; then
    if ! hook_has_escape "single-error"; then
      hook_warn "Only first validation error shown. Display all errors: errors.map() or errors.join(). Escape: // allow: single-error [reason]" "unhappy-path-single-error"
    fi
  fi
fi

# ── Check 5: URL-named fields without type="url" ────────────────
# Inputs for URL fields should use type="url" for browser validation hints.
# Detect via: register/name with url/endpoint/callback/redirect/webhook/origin
# keywords, OR placeholder containing http:// / https://.

if echo "$added_lines" | grep -qE '<Input\b|<input\b'; then
  _is_url_field=false

  # Signal 1: register() or name= with URL-related keywords
  if echo "$added_lines" | grep -qiE "register\(['\"][^'\"]*([Uu]rl|[Ee]ndpoint|[Cc]allback|[Rr]edirect|[Ww]ebhook|[Oo]rigin)[^'\"]*['\"]|name\s*=\s*['\"][^'\"]*([Uu]rl|[Ee]ndpoint|[Cc]allback|[Rr]edirect|[Ww]ebhook|[Oo]rigin)[^'\"]*['\"]"; then
    _is_url_field=true
  fi

  # Signal 2: placeholder containing a URL
  if echo "$added_lines" | grep -qE 'placeholder.*https?://|https?://.*placeholder'; then
    _is_url_field=true
  fi

  if [ "$_is_url_field" = true ]; then
    if ! echo "$added_lines" | grep -qE 'type\s*=\s*["\x27]url["\x27]'; then
      if ! hook_has_escape "input-type-url"; then
        hook_warn "URL field without type=\"url\". Add type=\"url\" for browser-level validation hints. Escape: // allow: input-type-url [reason]" "unhappy-path-input-type"
      fi
    fi
  fi
fi

exit 0
