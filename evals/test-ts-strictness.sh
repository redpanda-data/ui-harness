# Evals for TypeScript strictness hooks:
#   ts-no-escape-hatches-check.sh — blocks any/Record<T,any>/type=any/double-cast
#   tsconfig-strict-check.sh       — blocks tsconfig strictness weakening
#
# Edge cases covered:
#   - clean types pass
#   - bare `: any`, `any[]`, `Array<any>` → block
#   - `Record<string, any>` and `Record<string, unknown>` → block
#   - `Record<any, T>` (key any) → block
#   - `type X = any|unknown|never|{}` → block
#   - `as unknown as T` double-cast → block
#   - comments that mention `any` → pass (not a declaration)
#   - escape hatch `// allow: ts-escape` → pass
#   - tsconfig with strict:true → pass
#   - tsconfig with strict:false → block
#   - tsconfig with any strict sub-flag disabled → block
#   - tsconfig with only `extends` → pass (base inherits)
#   - tsconfig with `// allow: tsconfig-strict` → pass

ESCAPE_HOOK="$REPO_ROOT/.claude/hooks/ts-no-escape-hatches-check.sh"
TSCONFIG_HOOK="$REPO_ROOT/.claude/hooks/tsconfig-strict-check.sh"

run_file_eval "$ESCAPE_HOOK" "ts-no-escape-hatches-check.sh exists"
run_executable_eval "$ESCAPE_HOOK" "ts-no-escape-hatches-check.sh is executable"
run_file_eval "$TSCONFIG_HOOK" "tsconfig-strict-check.sh exists"
run_executable_eval "$TSCONFIG_HOOK" "tsconfig-strict-check.sh is executable"

# Hooks registered in manifest + both generated configs
run_content_eval "$REPO_ROOT/skill-manifest.json" "ts-no-escape-hatches-check.sh" \
  "manifest registers ts-no-escape-hatches-check"
run_content_eval "$REPO_ROOT/skill-manifest.json" "tsconfig-strict-check.sh" \
  "manifest registers tsconfig-strict-check"
run_content_eval "$REPO_ROOT/.claude/settings.json" "ts-no-escape-hatches-check.sh" \
  "settings.json registers ts-no-escape-hatches-check"
run_content_eval "$REPO_ROOT/hooks/hooks.json" "ts-no-escape-hatches-check.sh" \
  "hooks.json registers ts-no-escape-hatches-check"
run_content_eval "$REPO_ROOT/.claude/settings.json" "tsconfig-strict-check.sh" \
  "settings.json registers tsconfig-strict-check"
run_content_eval "$REPO_ROOT/hooks/hooks.json" "tsconfig-strict-check.sh" \
  "hooks.json registers tsconfig-strict-check"

# ── Integration: actually run the hooks on temp files ────────────

_tmp=$(mktemp -d)
trap "rm -rf '$_tmp'" EXIT
git init -q "$_tmp" 2>/dev/null || true

_run_on_file() {
  local hook="$1" content="$2" filename="$3"
  local path="$_tmp/$filename"
  printf '%s\n' "$content" > "$path"
  git -C "$_tmp" add -N "$filename" 2>/dev/null || true
  local stderr_file; stderr_file=$(mktemp)
  local exit_code=0
  export CLAUDE_SESSION_ID="eval-ts-$$"
  echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$path\"}}" \
    | bash "$hook" 2> "$stderr_file" > /dev/null || exit_code=$?
  _last_stderr=$(cat "$stderr_file")
  _last_exit=$exit_code
  rm -f "$stderr_file"
  rm -rf "/tmp/hook-session-eval-ts-$$" 2>/dev/null || true
}

_assert_ts() {
  local desc="$1" expected="$2" pattern="${3:-}"
  local ok=true
  [ "$_last_exit" -ne "$expected" ] && ok=false
  if [ -n "$pattern" ] && ! echo "$_last_stderr" | grep -qF -- "$pattern"; then
    ok=false
  fi
  if [ "$ok" = true ]; then
    echo "  PASS  $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $desc (exit=$_last_exit expected=$expected)"
    [ -n "$pattern" ] && echo "        missing: $pattern"
    [ -n "$_last_stderr" ] && echo "        stderr: ${_last_stderr:0:200}"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $desc"
  fi
}

# ── ts-no-escape-hatches ─────────────────────────────────────────

# Clean
_run_on_file "$ESCAPE_HOOK" 'export function f(n: number): string { return String(n); }' "clean.ts"
_assert_ts "clean .ts passes" 0

# `: any`
_run_on_file "$ESCAPE_HOOK" 'export function f(x: any) { return x; }' "any1.ts"
_assert_ts "blocks bare : any" 2 ": any"

# `any[]` — first rule (`: any`) fires, still blocks
_run_on_file "$ESCAPE_HOOK" 'export const arr: any[] = [];' "any2.ts"
_assert_ts "blocks any[]" 2 "any"

# `Array<any>`
_run_on_file "$ESCAPE_HOOK" 'export const arr: Array<any> = [];' "any3.ts"
_assert_ts "blocks Array<any>" 2 "generic '<any>'"

# `Promise<any>`
_run_on_file "$ESCAPE_HOOK" 'export async function f(): Promise<any> { return null; }' "any4.ts"
_assert_ts "blocks Promise<any>" 2 "generic '<any>'"

# `Record<string, any>`
_run_on_file "$ESCAPE_HOOK" 'export const c: Record<string, any> = {};' "rec1.ts"
_assert_ts "blocks Record<string, any>" 2 "any with extra steps"

# `Record<string, unknown>`
_run_on_file "$ESCAPE_HOOK" 'export const c: Record<string, unknown> = {};' "rec2.ts"
_assert_ts "blocks Record<string, unknown>" 2 "any with extra steps"

# `Record<any, ...>`
_run_on_file "$ESCAPE_HOOK" 'export const c: Record<any, string> = {};' "rec3.ts"
_assert_ts "blocks Record<any, ...>" 2 "loses key typing"

# `type X = any`
_run_on_file "$ESCAPE_HOOK" 'export type Foo = any;' "alias1.ts"
_assert_ts "blocks type Foo = any;" 2 "rename for an escape"

# `type X = unknown`
_run_on_file "$ESCAPE_HOOK" 'export type Foo = unknown;' "alias2.ts"
_assert_ts "blocks type Foo = unknown;" 2 "rename for an escape"

# `type X = never`
_run_on_file "$ESCAPE_HOOK" 'export type Foo = never;' "alias3.ts"
_assert_ts "blocks type Foo = never;" 2 "rename for an escape"

# `as unknown as T`
_run_on_file "$ESCAPE_HOOK" 'const x = raw as unknown as Schema;' "dbl.ts"
_assert_ts "blocks as unknown as T double-cast" 2 "Double cast"

# Comment-only `any` reference → pass
_run_on_file "$ESCAPE_HOOK" '// avoid any in this module' "cmt.ts"
_assert_ts "comment mentioning any passes" 0

# Escape hatch
_run_on_file "$ESCAPE_HOOK" '// allow: ts-escape 3p lib has no types
export const legacy: any = null;' "esc.ts"
_assert_ts "// allow: ts-escape passes" 0

# .d.ts files with `any` for 3p types - treated same; should block without escape
_run_on_file "$ESCAPE_HOOK" 'declare module "foo" { export function bar(): any; }' "types.d.ts"
_assert_ts "blocks any in .d.ts (use escape)" 2

# Tests skipped
_run_on_file "$ESCAPE_HOOK" 'const x: any = 1;' "mod.test.ts"
_assert_ts "test file skipped (ts-escape)" 0

# ── tsconfig-strict-check ────────────────────────────────────────

# Clean strict
_run_on_file "$TSCONFIG_HOOK" '{"compilerOptions":{"strict":true,"noUncheckedIndexedAccess":true}}' "tsconfig.json"
_assert_ts "tsconfig strict:true passes" 0

# strict:false
_run_on_file "$TSCONFIG_HOOK" '{"compilerOptions":{"strict":false}}' "tsconfig.json"
_assert_ts "tsconfig strict:false blocks" 2 "tsconfig-strict"

# strict:true but noImplicitAny:false
_run_on_file "$TSCONFIG_HOOK" '{"compilerOptions":{"strict":true,"noImplicitAny":false}}' "tsconfig.json"
_assert_ts "tsconfig noImplicitAny:false blocks" 2 "noImplicitAny"

# extends only → passes (base inherits)
_run_on_file "$TSCONFIG_HOOK" '{"extends":"./base.json","compilerOptions":{"outDir":"dist"}}' "tsconfig.json"
_assert_ts "tsconfig with extends passes" 0

# Missing strict, no extends → blocks
_run_on_file "$TSCONFIG_HOOK" '{"compilerOptions":{"target":"ES2020"}}' "tsconfig.json"
_assert_ts "tsconfig missing strict blocks" 2 "strict"

# Escape hatch
_run_on_file "$TSCONFIG_HOOK" '{"compilerOptions":{"strict":false}} // allow: tsconfig-strict legacy migration' "tsconfig.json"
_assert_ts "// allow: tsconfig-strict passes" 0

# Non-tsconfig file skipped
_run_on_file "$TSCONFIG_HOOK" '{"compilerOptions":{"strict":false}}' "package.json"
_assert_ts "non-tsconfig file skipped" 0

# tsconfig with JSONC comments + strict:true
_run_on_file "$TSCONFIG_HOOK" '{
  // tsconfig
  "compilerOptions": {
    "strict": true /* good */
  }
}' "tsconfig.json"
_assert_ts "tsconfig with comments + strict:true passes" 0
