#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

# Hard-block TypeScript escape hatches that erase type safety.
# Complements as-cast-check.sh (focused on `as` casts) and Biome's
# noExplicitAny (lint-time only). This runs at Edit/Write time so
# the AI cannot keep shipping escape hatches across the codebase.
#
# Blocks:
#   - bare `: any`, `any[]`, `Array<any>`, `Promise<any>`, `ReadonlyArray<any>`
#   - `Record<string, any>`, `Record<string, unknown>`, `Record<any, ...>`
#   - type aliases to escape types: `type X = any | unknown | never | {}`
#   - `<any>` as a generic argument (angle-bracket form)
#   - `as unknown as T` double-cast chain
#   - `!.` non-null assertions when bang is added in this diff (warn — common but lossy)
#
# Escape hatch: `// allow: ts-escape [reason]` on the same line.

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

if hook_has_escape "ts-escape"; then
  exit 0
fi

# Normalize: strip leading + from diff lines for regex clarity.
_lines=$(printf '%s' "$added_lines" | sed 's/^+//')

# Skip if the only `any` mentions are in strings/comments — heuristic:
# drop lines that are obvious string literals or line-starting comments.
_scan=$(printf '%s\n' "$_lines" | grep -vE '^\s*(//|\*|/\*)' || true)

# ── 1. Bare `: any` type annotations ─────────────────────────────
if printf '%s' "$_scan" | grep -qE ':\s*any\b'; then
  hook_block "TypeScript escape hatch: ': any' annotation. Use a concrete type, a generic parameter, or 'unknown' with a type guard. No 'any' in production code." "ts-escape-any"
fi
if printf '%s' "$_scan" | grep -qE '\bany\[\]'; then
  hook_block "TypeScript escape hatch: 'any[]'. Use a concrete element type or a generic parameter." "ts-escape-any-array"
fi
if printf '%s' "$_scan" | grep -qE '\b(Array|Promise|ReadonlyArray|Set|Map)<\s*any\b'; then
  hook_block "TypeScript escape hatch: generic '<any>'. Specify the element/resolved type." "ts-escape-generic-any"
fi

# ── 2. Record<string, any | unknown> in declarations ─────────────
if printf '%s' "$_scan" | grep -qE '\bRecord<\s*[A-Za-z_]+\s*,\s*(any|unknown)\s*>'; then
  hook_block "Record<…, any/unknown> is any with extra steps. Define a concrete shape (interface / union) or use 'Record<K, Schema>' with zod." "ts-escape-record"
fi
if printf '%s' "$_scan" | grep -qE '\bRecord<\s*any\s*,'; then
  hook_block "Record<any, …> loses key typing. Use 'Record<string, T>' or a concrete union of keys." "ts-escape-record-keys"
fi

# ── 3. Type alias to escape type ─────────────────────────────────
if printf '%s' "$_scan" | grep -qE '\btype\s+[A-Z][A-Za-z0-9_]*\s*=\s*(any|unknown|never|\{\s*\})\s*[;|$]'; then
  hook_block "Type alias to 'any/unknown/never/{}' is a rename for an escape hatch. Define the actual shape." "ts-escape-alias"
fi

# ── 4. `as unknown as T` double-cast ─────────────────────────────
if printf '%s' "$_scan" | grep -qE '\bas\s+unknown\s+as\s+'; then
  hook_block "Double cast 'as unknown as T' hides a type error. Fix the underlying mismatch (type guard, schema, generic)." "ts-escape-double-cast"
fi

# ── 5. Non-null assertion added on a property access ─────────────
# Warn, not block — sometimes legitimate after a runtime guard.
_bang=$(printf '%s' "$_scan" | grep -cE '[A-Za-z0-9_)\]]!\.' || true)
_bang=${_bang:-0}
if [ "$_bang" -gt 0 ]; then
  if ! hook_has_escape "ts-nonnull"; then
    hook_warn "${_bang} non-null assertion(s) '!.'. Prefer a guard that narrows the type. Escape: // allow: ts-nonnull [reason]" "ts-escape-nonnull"
  fi
fi

exit 0
