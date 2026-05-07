# Evals for hooks created from PR audit analysis (2025-2026)

HOOKS_DIR="$REPO_ROOT/.claude/hooks"

# ══════════════════════════════════════════════════════════════════
# legacy-import-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/legacy-import-check.sh" "legacy-import-check.sh exists"
run_executable_eval "$HOOKS_DIR/legacy-import-check.sh" "legacy-import-check.sh is executable"

run_content_eval "$HOOKS_DIR/legacy-import-check.sh" "@redpanda-data/ui" "legacy-import catches @redpanda-data/ui"
run_content_eval "$HOOKS_DIR/legacy-import-check.sh" "lucide-react" "legacy-import catches lucide-react"
run_content_eval "$HOOKS_DIR/legacy-import-check.sh" "<button" "legacy-import catches raw <button>"
run_content_eval "$HOOKS_DIR/legacy-import-check.sh" "<input" "legacy-import catches raw <input>"
run_content_eval "$HOOKS_DIR/legacy-import-check.sh" "<a.*href" "legacy-import catches raw <a href>"
run_content_eval "$HOOKS_DIR/legacy-import-check.sh" "hook_has_escape" "legacy-import respects escape hatch"

# ── Warn: @redpanda-data/ui import ───────────────────────────────

_li_tmpdir=$(mktemp -d /tmp/legacy-import-evals-XXXXXX)
tmpfile="$_li_tmpdir/component.tsx"
printf "import { Button } from '@redpanda-data/ui'\n" > "$tmpfile"
(cd "$_li_tmpdir" && git init -q && git commit -q --allow-empty -m "init") 2>/dev/null

run_hook_eval "$HOOKS_DIR/legacy-import-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: @redpanda-data/ui import" "legacy"

# ── Warn: raw <button> in tsx ────────────────────────────────────

tmpfile="$_li_tmpdir/page.tsx"
printf "export default function Page() {\n  return <button onClick={fn}>Click</button>\n}\n" > "$tmpfile"

run_hook_eval "$HOOKS_DIR/legacy-import-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: raw <button> in tsx" "button"

# ── Allow: .ts file (no JSX check) ──────────────────────────────

tmpfile="$_li_tmpdir/util.ts"
printf "const x = 1\n" > "$tmpfile"

run_hook_eval "$HOOKS_DIR/legacy-import-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: clean .ts file"

# ── Skip: test file ─────────────────────────────────────────────

tmpfile="$_li_tmpdir/page.test.tsx"
printf "import { Button } from '@redpanda-data/ui'\n" > "$tmpfile"

run_hook_eval "$HOOKS_DIR/legacy-import-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "skip: test file"

(cd /tmp && rm -r "$_li_tmpdir" 2>/dev/null) || true

# ══════════════════════════════════════════════════════════════════
# test-convention-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/test-convention-check.sh" "test-convention-check.sh exists"
run_executable_eval "$HOOKS_DIR/test-convention-check.sh" "test-convention-check.sh is executable"

run_content_eval "$HOOKS_DIR/test-convention-check.sh" "it.*.'" "test-convention detects it() pattern"
run_content_eval "$HOOKS_DIR/test-convention-check.sh" "jest" "test-convention detects jest.fn"
run_content_eval "$HOOKS_DIR/test-convention-check.sh" "toBeInTheDocument" "test-convention detects toBeInTheDocument"
run_content_eval "$HOOKS_DIR/test-convention-check.sh" "waitForTimeout" "test-convention detects waitForTimeout"
run_content_eval "$HOOKS_DIR/test-convention-check.sh" "test.skip" "test-convention detects test.skip"
run_content_eval "$HOOKS_DIR/test-convention-check.sh" "test-magic-timeout" "test-convention detects { timeout: <n> } magic number"
run_content_eval "$HOOKS_DIR/test-convention-check.sh" "test-unawaited" "test-convention detects unawaited findBy/waitFor"

# ── Warn: it() in test file ─────────────────────────────────────

_tc_tmpdir=$(mktemp -d /tmp/test-conv-evals-XXXXXX)
tmpfile="$_tc_tmpdir/page.test.tsx"
printf "it('should render', () => {})\n" > "$tmpfile"
(cd "$_tc_tmpdir" && git init -q && git commit -q --allow-empty -m "init") 2>/dev/null

run_hook_eval "$HOOKS_DIR/test-convention-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: it() in test file" "test()"

# ── Warn: jest.fn() ─────────────────────────────────────────────

tmpfile="$_tc_tmpdir/mock.test.ts"
printf "const fn = jest.fn()\n" > "$tmpfile"

run_hook_eval "$HOOKS_DIR/test-convention-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: jest.fn() in test file" "Vitest"

# ── Skip: non-test file ─────────────────────────────────────────

tmpfile="$_tc_tmpdir/component.tsx"
printf "const x = 1\n" > "$tmpfile"

run_hook_eval "$HOOKS_DIR/test-convention-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "skip: non-test file"

# ── Warn: test.skip in E2E ──────────────────────────────────────

tmpfile="$_tc_tmpdir/login.spec.ts"
printf "test.skip('broken test', () => {})\n" > "$tmpfile"

run_hook_eval "$HOOKS_DIR/test-convention-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: test.skip in E2E file" "skip"

# ── Warn: { timeout: <n> } magic number ────────────────────────

tmpfile="$_tc_tmpdir/wait.test.tsx"
printf "await waitFor(() => expect(x).toBe(1), { timeout: 5000 })\n" > "$tmpfile"

run_hook_eval "$HOOKS_DIR/test-convention-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: { timeout: 5000 } magic number" "magic number"

# ── Warn: unawaited findByRole ─────────────────────────────────

tmpfile="$_tc_tmpdir/find.test.tsx"
printf "screen.findByRole('button')\n" > "$tmpfile"

run_hook_eval "$HOOKS_DIR/test-convention-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: unawaited findByRole" "missing await"

# ── Allow: awaited findByRole ──────────────────────────────────

tmpfile="$_tc_tmpdir/find-ok.test.tsx"
printf "const el = await screen.findByRole('button')\n" > "$tmpfile"

run_hook_eval "$HOOKS_DIR/test-convention-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: awaited findByRole"

(cd /tmp && rm -r "$_tc_tmpdir" 2>/dev/null) || true

# ══════════════════════════════════════════════════════════════════
# connect-error-format-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/connect-error-format-check.sh" "connect-error-format-check.sh exists"
run_executable_eval "$HOOKS_DIR/connect-error-format-check.sh" "connect-error-format-check.sh is executable"

run_content_eval "$HOOKS_DIR/connect-error-format-check.sh" "ConnectError.from" "connect-error-format prescribes ConnectError.from"
run_content_eval "$HOOKS_DIR/connect-error-format-check.sh" "formatToastErrorMessageGRPC" "connect-error-format prescribes formatToastErrorMessageGRPC"
run_content_eval "$HOOKS_DIR/connect-error-format-check.sh" "onError" "connect-error-format checks for onError"

# console-log-check.sh REMOVED — covered by Biome noConsole rule

# ══════════════════════════════════════════════════════════════════
# form-watch-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/form-watch-check.sh" "form-watch-check.sh exists"
run_executable_eval "$HOOKS_DIR/form-watch-check.sh" "form-watch-check.sh is executable"

run_content_eval "$HOOKS_DIR/form-watch-check.sh" "useWatch" "form-watch suggests useWatch"
run_content_eval "$HOOKS_DIR/form-watch-check.sh" "React Compiler" "form-watch mentions React Compiler"

# ══════════════════════════════════════════════════════════════════
# as-cast-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/as-cast-check.sh" "as-cast-check.sh exists"
run_executable_eval "$HOOKS_DIR/as-cast-check.sh" "as-cast-check.sh is executable"

run_content_eval "$HOOKS_DIR/as-cast-check.sh" "as\s*never" "as-cast blocks as never"
run_content_eval "$HOOKS_DIR/as-cast-check.sh" "as\s*any" "as-cast blocks as any"
run_content_eval "$HOOKS_DIR/as-cast-check.sh" "hook_block" "as-cast uses hook_block for hard blocks"
run_content_eval "$HOOKS_DIR/as-cast-check.sh" "type guard" "as-cast suggests type guards"

# ── Block: as never ──────────────────────────────────────────────

_ac_tmpdir=$(mktemp -d /tmp/as-cast-evals-XXXXXX)
tmpfile="$_ac_tmpdir/route.tsx"
printf "const x = foo as never\n" > "$tmpfile"
(cd "$_ac_tmpdir" && git init -q && git commit -q --allow-empty -m "init") 2>/dev/null

run_hook_eval "$HOOKS_DIR/as-cast-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: as never" "never"

# ── Block: as any ────────────────────────────────────────────────

tmpfile="$_ac_tmpdir/route2.tsx"
printf "const x = foo as any\n" > "$tmpfile"

run_hook_eval "$HOOKS_DIR/as-cast-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: as any" "any"

# ── Allow: as const ──────────────────────────────────────────────

tmpfile="$_ac_tmpdir/config.ts"
printf "const routes = ['/a', '/b'] as const\n" > "$tmpfile"

run_hook_eval "$HOOKS_DIR/as-cast-check.sh" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: as const"

(cd /tmp && rm -r "$_ac_tmpdir" 2>/dev/null) || true

# ══════════════════════════════════════════════════════════════════
# mutation-naming-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/mutation-naming-check.sh" "mutation-naming-check.sh exists"
run_executable_eval "$HOOKS_DIR/mutation-naming-check.sh" "mutation-naming-check.sh is executable"

run_content_eval "$HOOKS_DIR/mutation-naming-check.sh" "Mutation" "mutation-naming enforces *Mutation suffix"
run_content_eval "$HOOKS_DIR/mutation-naming-check.sh" "useMutation" "mutation-naming detects useMutation"

# ══════════════════════════════════════════════════════════════════
# magic-number-check.sh
# ══════════════════════════════════════════════════════════════════

run_file_eval "$HOOKS_DIR/magic-number-check.sh" "magic-number-check.sh exists"
run_executable_eval "$HOOKS_DIR/magic-number-check.sh" "magic-number-check.sh is executable"

run_content_eval "$HOOKS_DIR/magic-number-check.sh" "staleTime" "magic-number catches inline staleTime"
run_content_eval "$HOOKS_DIR/magic-number-check.sh" "proto" "magic-number checks proto files"

# ══════════════════════════════════════════════════════════════════
# hooks.json wiring
# ══════════════════════════════════════════════════════════════════

run_content_eval "$REPO_ROOT/hooks/hooks.json" "legacy-import-check" "hooks.json has legacy-import-check"
run_content_eval "$REPO_ROOT/hooks/hooks.json" "test-convention-check" "hooks.json has test-convention-check"
run_content_eval "$REPO_ROOT/hooks/hooks.json" "connect-error-format-check" "hooks.json has connect-error-format-check"
# console-log-check removed — Biome noConsole handles it
run_content_eval "$REPO_ROOT/hooks/hooks.json" "form-watch-check" "hooks.json has form-watch-check"
run_content_eval "$REPO_ROOT/hooks/hooks.json" "as-cast-check" "hooks.json has as-cast-check"
run_content_eval "$REPO_ROOT/hooks/hooks.json" "mutation-naming-check" "hooks.json has mutation-naming-check"
run_content_eval "$REPO_ROOT/hooks/hooks.json" "magic-number-check" "hooks.json has magic-number-check"
