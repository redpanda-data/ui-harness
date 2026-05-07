# Evals for coverage gap hooks: biome-ignore, route-visual-test, hook-location,
# mutation-side-effect, field-mask, connect-error — hooks that lacked eval coverage.

HOOKS_DIR="$REPO_ROOT/.claude/hooks"

# ══════════════════════════════════════════════════════════════════
# biome-ignore-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/biome-ignore-check.sh" "biome-ignore-check.sh exists"
run_executable_eval "$HOOKS_DIR/biome-ignore-check.sh" "biome-ignore-check.sh is executable"

# ── Script content ──────────────────────────────────────────────

run_content_eval "$HOOKS_DIR/biome-ignore-check.sh" "noExplicitAny" "biome-ignore blocks noExplicitAny"
run_content_eval "$HOOKS_DIR/biome-ignore-check.sh" "hook_block" "biome-ignore uses hook_block for noExplicitAny"
run_content_eval "$HOOKS_DIR/biome-ignore-check.sh" "ts-ignore|ts-expect-error" "biome-ignore catches @ts-ignore/@ts-expect-error"
run_content_eval "$HOOKS_DIR/biome-ignore-check.sh" "hook_has_escape" "biome-ignore respects escape hatch"
run_content_eval "$HOOKS_DIR/biome-ignore-check.sh" "LLMs" "biome-ignore mentions LLM copy risk"

# ── Block: biome-ignore noExplicitAny ────────────────────────────

_bi_tmpdir=$(mktemp -d /tmp/biome-ignore-evals-XXXXXX)
tmpfile="$_bi_tmpdir/test.tsx"
printf '// biome-ignore lint/suspicious/noExplicitAny: complex type\nconst x: any = {}\n' > "$tmpfile"
(cd "$_bi_tmpdir" && git init -q && git add . && git commit -q -m "init" && \
  printf '+// biome-ignore lint/suspicious/noExplicitAny: complex type\n+const x: any = {}\n' > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/biome-ignore-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: biome-ignore noExplicitAny" "noExplicitAny"

# ── Warn: other biome-ignore ─────────────────────────────────────

tmpfile="$_bi_tmpdir/test2.tsx"
printf '// biome-ignore lint/a11y/noAriaUnsupported: legacy\n' > "$tmpfile"
(cd "$_bi_tmpdir" && git add . && git commit -q -m "init2" && \
  printf '+// biome-ignore lint/a11y/noAriaUnsupported: legacy\n' > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/biome-ignore-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: other biome-ignore (exit 0, not block)" "lint suppression"

# Note: @ts-ignore/@ts-expect-error handling moved to as-cast-check.sh (block, exit 2)
# in 2.2.x. See evals/test-setup-react-rules.sh for the block test. biome-ignore-check.sh
# intentionally skips @ts-ignore to avoid duplicate enforcement.

# ── Allow: clean code ────────────────────────────────────────────

tmpfile="$_bi_tmpdir/clean.tsx"
printf 'const x: string = "hello"\n' > "$tmpfile"
(cd "$_bi_tmpdir" && git add . && git commit -q -m "init4" && \
  printf '+const x: string = "hello"\n' > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/biome-ignore-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: clean code with no ignores"

# ── Allow: escape hatch ──────────────────────────────────────────

tmpfile="$_bi_tmpdir/escaped.tsx"
printf '// allow: lint-ignore third-party types are untyped\n// biome-ignore lint/correctness/noUndeclaredVariables: untyped lib\n' > "$tmpfile"
(cd "$_bi_tmpdir" && git add . && git commit -q -m "init5" && \
  printf '+// allow: lint-ignore third-party types are untyped\n+// biome-ignore lint/correctness/noUndeclaredVariables: untyped lib\n' > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/biome-ignore-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: biome-ignore with escape hatch"

# ── Skip: non-JS/TS files ───────────────────────────────────────

run_hook_eval "$HOOKS_DIR/biome-ignore-check.sh" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/test.md"}}' \
  0 "skip: non-JS/TS file"

rm -rf "$_bi_tmpdir"

# ══════════════════════════════════════════════════════════════════
# route-visual-test-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/route-visual-test-check.sh" "route-visual-test-check.sh exists"
run_executable_eval "$HOOKS_DIR/route-visual-test-check.sh" "route-visual-test-check.sh is executable"

# ── Script content ──────────────────────────────────────────────

run_content_eval "$HOOKS_DIR/route-visual-test-check.sh" "browser.test" "route-visual checks for browser.test files"
run_content_eval "$HOOKS_DIR/route-visual-test-check.sh" "@vitest/browser" "route-visual checks for @vitest/browser dep"
run_content_eval "$HOOKS_DIR/route-visual-test-check.sh" "/routes/" "route-visual gates on route files"
run_content_eval "$HOOKS_DIR/route-visual-test-check.sh" "visual-test-reminded" "route-visual uses session marker (once per session)"
run_content_eval "$HOOKS_DIR/route-visual-test-check.sh" "_has_browser_tests" "route-visual gates on browser test existence"

# ── Skip: non-route file ────────────────────────────────────────

_rvt_tmpdir=$(mktemp -d /tmp/route-visual-evals-XXXXXX)
tmpfile="$_rvt_tmpdir/component.tsx"
printf 'export function Button() { return <button /> }\n' > "$tmpfile"

run_hook_eval "$HOOKS_DIR/route-visual-test-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "skip: non-route file"

# ── Skip: test file in routes ────────────────────────────────────

mkdir -p "$_rvt_tmpdir/routes"
tmpfile="$_rvt_tmpdir/routes/index.test.tsx"
printf 'test("renders", () => {})\n' > "$tmpfile"

run_hook_eval "$HOOKS_DIR/route-visual-test-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "skip: test file in routes dir"

# ── Skip: layout/root route ──────────────────────────────────────

tmpfile="$_rvt_tmpdir/routes/__root.tsx"
printf 'export const Route = createRootRoute({})\n' > "$tmpfile"

run_hook_eval "$HOOKS_DIR/route-visual-test-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "skip: __root route file"

rm -rf "$_rvt_tmpdir"

# ══════════════════════════════════════════════════════════════════
# hook-location-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/hook-location-check.sh" "hook-location-check.sh exists"
run_executable_eval "$HOOKS_DIR/hook-location-check.sh" "hook-location-check.sh is executable"

# ── Script content ──────────────────────────────────────────────

run_content_eval "$HOOKS_DIR/hook-location-check.sh" "function.*use.A-Z" "hook-location detects function useX pattern"
run_content_eval "$HOOKS_DIR/hook-location-check.sh" "const.*use.A-Z" "hook-location detects const useX arrow pattern"
run_content_eval "$HOOKS_DIR/hook-location-check.sh" "hook_warn" "hook-location uses hook_warn (advisory)"
run_content_eval "$HOOKS_DIR/hook-location-check.sh" "/hooks/" "hook-location prescribes /hooks/ directory"

# ── Warn: function hook in route file ────────────────────────────

_hl_tmpdir=$(mktemp -d /tmp/hook-loc-evals-XXXXXX)
mkdir -p "$_hl_tmpdir/routes"
tmpfile="$_hl_tmpdir/routes/users.tsx"
printf 'function useUserData() { return {} }\n' > "$tmpfile"
(cd "$_hl_tmpdir" && git init -q && git add . && git commit -q -m "init" && \
  printf '+function useUserData() { return {} }\n' > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/hook-location-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: function hook in route file" "hooks"

# ── Warn: arrow function hook in route file ──────────────────────

tmpfile="$_hl_tmpdir/routes/users2.tsx"
printf 'const useUserData = () => { return {} }\n' > "$tmpfile"
(cd "$_hl_tmpdir" && git add . && git commit -q -m "init2" && \
  printf '+const useUserData = () => { return {} }\n' > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/hook-location-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: arrow function hook in route file" "hooks"

# ── Allow: hook in hooks directory ───────────────────────────────

mkdir -p "$_hl_tmpdir/hooks"
tmpfile="$_hl_tmpdir/hooks/use-user-data.ts"
printf 'export function useUserData() { return {} }\n' > "$tmpfile"
(cd "$_hl_tmpdir" && git add . && git commit -q -m "init3" && \
  printf '+export function useUserData() { return {} }\n' > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/hook-location-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: hook in hooks directory"

# ── Allow: non-hook function in route file ───────────────────────

tmpfile="$_hl_tmpdir/routes/users3.tsx"
printf 'function formatDate(d: Date) { return d.toISOString() }\n' > "$tmpfile"
(cd "$_hl_tmpdir" && git add . && git commit -q -m "init4" && \
  printf '+function formatDate(d: Date) { return d.toISOString() }\n' > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/hook-location-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: non-hook function in route file"

rm -rf "$_hl_tmpdir"

# ══════════════════════════════════════════════════════════════════
# mutation-side-effect-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/mutation-side-effect-check.sh" "mutation-side-effect-check.sh exists"
run_executable_eval "$HOOKS_DIR/mutation-side-effect-check.sh" "mutation-side-effect-check.sh is executable"

run_content_eval "$HOOKS_DIR/mutation-side-effect-check.sh" "useMutation" "mutation-check detects useMutation"
run_content_eval "$HOOKS_DIR/mutation-side-effect-check.sh" "DELETE.*POST.*PUT.*PATCH" "mutation-check catches side-effect methods"
run_content_eval "$HOOKS_DIR/mutation-side-effect-check.sh" "new_fetch_count" "mutation-check uses per-fetch counting (not file-level)"

# ── Warn: raw fetch DELETE in route file ─────────────────────────

_ms_tmpdir=$(mktemp -d /tmp/mutation-evals-XXXXXX)
mkdir -p "$_ms_tmpdir/routes"
tmpfile="$_ms_tmpdir/routes/connections.tsx"
printf "import React from 'react'\nconst disconnect = () => fetch('/api/disconnect', { method: 'DELETE' })\n" > "$tmpfile"
(cd "$_ms_tmpdir" && git init -q && git add . && git commit -q -m "init" && \
  printf "+const disconnect = () => fetch('/api/disconnect', { method: 'DELETE' })\n" > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/mutation-side-effect-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: raw fetch DELETE without useMutation" "useMutation"

# ── Allow: fetch wrapped in useMutation ──────────────────────────

tmpfile="$_ms_tmpdir/routes/connections2.tsx"
printf "import React from 'react'\nimport { useMutation } from '@tanstack/react-query'\nconst { mutate } = useMutation({ mutationFn: () => fetch('/api/x', { method: 'DELETE' }) })\n" > "$tmpfile"
(cd "$_ms_tmpdir" && git add . && git commit -q -m "init2" && \
  printf "+import { useMutation } from '@tanstack/react-query'\n+const { mutate } = useMutation({ mutationFn: () => fetch('/api/x', { method: 'DELETE' }) })\n" > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/mutation-side-effect-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: fetch DELETE wrapped in useMutation"

# ── Skip: non-React file ─────────────────────────────────────────

tmpfile="$_ms_tmpdir/utils.ts"
printf "export const apiDelete = () => fetch('/api/x', { method: 'DELETE' })\n" > "$tmpfile"
(cd "$_ms_tmpdir" && git add . && git commit -q -m "init3" && \
  printf "+export const apiDelete = () => fetch('/api/x', { method: 'DELETE' })\n" > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/mutation-side-effect-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "skip: non-React utility file"

rm -rf "$_ms_tmpdir"

# ══════════════════════════════════════════════════════════════════
# field-mask-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/field-mask-check.sh" "field-mask-check.sh exists"
run_executable_eval "$HOOKS_DIR/field-mask-check.sh" "field-mask-check.sh is executable"

run_content_eval "$HOOKS_DIR/field-mask-check.sh" "FieldMask|updateMask|update_mask" "field-mask detects multiple FieldMask patterns"
run_content_eval "$HOOKS_DIR/field-mask-check.sh" "dirtyFields" "field-mask suggests dynamic computation"
run_content_eval "$HOOKS_DIR/field-mask-check.sh" "hook_has_escape" "field-mask respects escape hatch"

# ── Warn: >2 hardcoded paths ─────────────────────────────────────

_fm_tmpdir=$(mktemp -d /tmp/field-mask-evals-XXXXXX)
# Must init git with empty commit, then add the file so git diff HEAD shows it
(cd "$_fm_tmpdir" && git init -q && git commit -q --allow-empty -m "init") 2>/dev/null
tmpfile="$_fm_tmpdir/edit.tsx"
cat > "$tmpfile" << 'FEOF'
import { FieldMask } from '@bufbuild/protobuf'
const mask = { paths: ['name', 'description', 'scopes'] }
FEOF

run_hook_eval "$HOOKS_DIR/field-mask-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: FieldMask with 3+ hardcoded paths" "dirty"

# ── Allow: <=2 hardcoded paths ───────────────────────────────────

tmpfile="$_fm_tmpdir/edit2.tsx"
cat > "$tmpfile" << 'FEOF'
import { FieldMask } from '@bufbuild/protobuf'
const mask = { paths: ['name', 'description'] }
FEOF

run_hook_eval "$HOOKS_DIR/field-mask-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: FieldMask with <=2 hardcoded paths"

# cleanup
(cd /tmp && rm -r "$_fm_tmpdir" 2>/dev/null) || true

# ══════════════════════════════════════════════════════════════════
# connect-error-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/connect-error-check.sh" "connect-error-check.sh exists"
run_executable_eval "$HOOKS_DIR/connect-error-check.sh" "connect-error-check.sh is executable"

run_content_eval "$HOOKS_DIR/connect-error-check.sh" "ConnectError.from" "connect-error prescribes ConnectError.from()"
run_content_eval "$HOOKS_DIR/connect-error-check.sh" "package.json.*@connectrpc" "connect-error checks project-level connectrpc dep"
run_content_eval "$HOOKS_DIR/connect-error-check.sh" "hook_has_escape" "connect-error respects escape hatch"

# ── Warn: throw new Error in connectrpc file ─────────────────────

_ce_tmpdir=$(mktemp -d /tmp/connect-error-evals-XXXXXX)
mkdir -p "$_ce_tmpdir/routes"
tmpfile="$_ce_tmpdir/routes/api.tsx"
# File must import @connectrpc AND have loader/queryFn context AND throw new Error
printf "import { createClient } from '@connectrpc/connect'\nexport const loader = async () => { throw new Error('fail') }\n" > "$tmpfile"
(cd "$_ce_tmpdir" && git init -q && git add . && git commit -q -m "init" && \
  printf "+import { createClient } from '@connectrpc/connect'\n+export const loader = async () => { throw new Error('fail') }\n" > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/connect-error-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: throw new Error in connectrpc file" "ConnectError"

# ── Allow: no throw new Error ────────────────────────────────────

tmpfile="$_ce_tmpdir/routes/api2.tsx"
printf "import { createClient } from '@connectrpc/connect'\nconst loader = async () => { return data }\n" > "$tmpfile"
(cd "$_ce_tmpdir" && git add . && git commit -q -m "init2" && \
  printf "+const loader = async () => { return data }\n" > "$tmpfile") 2>/dev/null

run_hook_eval "$HOOKS_DIR/connect-error-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: no throw new Error in connectrpc file"

rm -rf "$_ce_tmpdir"

# ══════════════════════════════════════════════════════════════════
# hooks.json wiring: new hooks registered
# ══════════════════════════════════════════════════════════════════

run_content_eval "$REPO_ROOT/hooks/hooks.json" "biome-ignore-check" "hooks.json has biome-ignore-check"
run_content_eval "$REPO_ROOT/hooks/hooks.json" "route-visual-test-check" "hooks.json has route-visual-test-check"

# ══════════════════════════════════════════════════════════════════
# Proto-form hooks: files, executable bits, registration in BOTH
# hooks.json (plugin manifest) and .claude/settings.json (local dev)
# ══════════════════════════════════════════════════════════════════

for h in connect-error-fieldmap-check proto-form-parallel-state-check form-setvalue-options-check form-error-summary-check; do
  run_file_eval       "$HOOKS_DIR/${h}.sh" "${h}.sh exists"
  run_executable_eval "$HOOKS_DIR/${h}.sh" "${h}.sh is executable"
  run_content_eval    "$HOOKS_DIR/${h}.sh" "hook_has_escape" "${h} respects escape hatch"
  run_content_eval    "$REPO_ROOT/hooks/hooks.json"       "${h}" "hooks.json has ${h}"
  run_content_eval    "$REPO_ROOT/.claude/settings.json"  "${h}" "settings.json has ${h}"
done
