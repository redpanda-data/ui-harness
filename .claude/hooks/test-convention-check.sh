#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_get_added_lines

# ── Gate: only test files ────────────────────────────────────────
case "$file_path" in
  *.test.*|*.spec.*|*.integration.*) ;;
  */__tests__/*) ;;
  *) exit 0 ;;
esac

# ── Check 1: it() should be test() ──────────────────────────────

if echo "$added_lines" | grep -qE '^\+?\s*it\(\s*['\''"]'; then
  if ! hook_has_escape "test-convention"; then
    hook_warn "Use test() not it() for consistency. Project standard is test('description', ...)." "test-convention-it"
  fi
fi

# ── Check 2: jest.fn() should be vi.fn() ────────────────────────

if echo "$added_lines" | grep -qE 'jest\.(fn|mock|spyOn|clearAllMocks|restoreAllMocks)\b'; then
  hook_warn "Use vi.fn()/vi.mock()/vi.spyOn() — project uses Vitest not Jest." "test-convention-jest"
fi

# ── Check 3: .toBeInTheDocument() → .toBeVisible() ──────────────
# toBeVisible is stricter — also checks element isn't hidden/obstructed.

if echo "$added_lines" | grep -qE '\.toBeInTheDocument\(\)'; then
  if ! hook_has_escape "to-be-in-document"; then
    hook_warn "Prefer .toBeVisible() over .toBeInTheDocument() — verifies element is actually visible, not just in DOM. Escape: // allow: to-be-in-document [reason]" "test-convention-visible"
  fi
fi

# ── Check 4: waitForTimeout in test files ────────────────────────
# Flaky pattern — use waitFor/waitForURL/proper assertions instead.

if echo "$added_lines" | grep -qE 'waitForTimeout|page\.waitForTimeout|setTimeout.*[0-9]{3,}'; then
  hook_warn "Avoid waitForTimeout in tests — flaky. Use waitFor(() => expect(...)), waitForURL(), or waitForSelector() instead." "test-convention-timeout"
fi

# ── Check 5: test.skip in E2E files ─────────────────────────────
# E2E tests should hard fail, not skip. Missing env = CI config issue.

case "$file_path" in
  *.spec.*|*e2e*|*playwright*)
    if echo "$added_lines" | grep -qE '\b(test|it)\.skip\b'; then
      hook_warn "No test.skip in E2E tests. If env/credentials missing, fail loudly so CI catches it. Use test.fixme() with linked GitHub issue for known bugs." "test-convention-skip"
    fi
    ;;
esac

# ── Check 7: literal timeout: in test option objects ────────────
# Hardcoded `{ timeout: <ms> }` in waitFor/findBy/expect.poll/page.*
# is a magic number — brittle if the operation gets slower over time.
# Prefer condition-based assertion or framework default timeout.

if echo "$added_lines" | grep -qE '\btimeout:\s*[0-9]+'; then
  if ! hook_has_escape "test-magic-timeout"; then
    hook_warn "Hardcoded { timeout: <ms> } in test — magic number, brittle as code slows. Prefer condition-based waitFor/expect.poll with default timeout. Escape: // allow: test-magic-timeout [reason]" "test-convention-magic-timeout"
  fi
fi

# ── Check 8: findBy*/waitFor without await ──────────────────────
# Both return Promises. Missing await leads to flaky tests, unhandled
# rejections, and assertions that pass before the DOM settles.

unawaited=$(echo "$added_lines" | grep -E '(findBy[A-Z][A-Za-z]*|\bwaitFor)\(' | grep -vE '\b(await|return)\b' | grep -vE '^\+?\s*(//|\*)' || true)
if [ -n "$unawaited" ]; then
  if ! hook_has_escape "test-unawaited"; then
    sample=$(echo "$unawaited" | head -2 | sed 's/^+//' | tr '\n' ' ')
    hook_warn "findBy*/waitFor returns Promise — missing await is flaky. Found: $sample Escape: // allow: test-unawaited [reason]" "test-convention-unawaited"
  fi
fi

# ── Check 6: data-testid reminder for interactive elements ───────
# Advisory only — remind when creating new interactive components.

case "$file_path" in
  *.test.tsx|*.spec.tsx|*.integration.tsx)
    if echo "$added_lines" | grep -qE 'getByRole\('; then
      # Count getByRole usage in added lines
      _role_count=$(echo "$added_lines" | grep -c 'getByRole\(' || echo "0")
      _role_count=$(echo "$_role_count" | tr -d '[:space:]')
      if [ "${_role_count:-0}" -gt 5 ]; then
        # Session-scoped: only warn once
        _marker="$_hook_session_dir/testid-reminded"
        if [ ! -f "$_marker" ]; then
          touch "$_marker"
          hook_warn "Heavy getByRole usage (${_role_count}x). Consider adding data-testid for faster, more stable selectors." "test-convention-testid"
        fi
      fi
    fi
    ;;
esac

exit 0
