#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

file_content=$(cat "$file_path")

# Allow escape hatch: // allow: form-mode [reason]
# (covers all checks in this hook)

# ── Check 1: Ban mode: 'onBlur' / 'onSubmit' in form options ────
# Forms must use onChange for immediate validation feedback.

if echo "$added_lines" | grep -qE "mode:\s*['\"]on(Blur|Submit)['\"]"; then
  if ! hook_has_escape "form-mode"; then
    hook_warn "Form mode should be 'onChange' for immediate validation feedback. Avoid 'onBlur'/'onSubmit'. Escape: // allow: form-mode [reason]"
  fi
fi

# ── Check 2: Forms without field validation ──────────────────────
# Forms should use validate/required/pattern rules on register(),
# OR a schema resolver (zodResolver, yupResolver, etc.).
# Skip if no useForm/useFormContext in file.

_is_form_file=false
if echo "$file_content" | grep -qE 'useForm\s*[(<]|useFormContext\s*\('; then
  _is_form_file=true
fi

if [ "$_is_form_file" = true ]; then
  # Skip if using a resolver (validation at schema level)
  _has_resolver=false
  if echo "$file_content" | grep -qE 'resolver\s*:|zodResolver|yupResolver|joiResolver|superstructResolver|valibotResolver'; then
    _has_resolver=true
  fi

  if [ "$_has_resolver" = false ]; then
    # Check if any register call uses validation options
    _has_field_validation=false
    if echo "$file_content" | grep -qE 'validate\s*:|required\s*:|pattern\s*:|minLength\s*:|maxLength\s*:|min\s*:|max\s*:'; then
      _has_field_validation=true
    fi

    if [ "$_has_field_validation" = false ]; then
      if ! hook_has_escape "form-validate"; then
        hook_warn "Form has no field validation. Add validate/required/pattern to register() or use a resolver (zodResolver). Escape: // allow: form-validate [reason]" "form-mode-validate"
      fi
    fi
  fi

  # ── Check 3: Forms without inline error display ──────────────────
  # Errors must surface next to fields — not just in toasts or hidden.
  # Look for: FormMessage, FieldError, FormDescription with error,
  # errors.fieldName?.message, or Field component (wraps error display).

  _has_error_display=false
  if echo "$file_content" | grep -qE 'FormMessage|FieldError|FormErrorDescription|ErrorDescription|FormDescription.*error|errors\.\w+\??\.\s*message|formState\.errors|<Field[\s>]|FieldInfo'; then
    _has_error_display=true
  fi

  if [ "$_has_error_display" = false ]; then
    if ! hook_has_escape "form-errors"; then
      hook_warn "Form lacks inline error display next to fields. Surface errors via FormMessage/FieldError/Field component with error descriptions. Escape: // allow: form-errors [reason]" "form-mode-errors"
    fi
  fi
fi

exit 0
