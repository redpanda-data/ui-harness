# Evals for llm-failure-mode-check.sh — 7 Karpathy patterns.
# 5 block-enforced, 2 warn-only; types + silent-fallbacks delegated
# to existing hooks (ts-no-escape-hatches, unhappy-path-check).

HOOK="$REPO_ROOT/.claude/hooks/llm-failure-mode-check.sh"

run_file_eval "$HOOK" "llm-failure-mode-check.sh exists"
run_executable_eval "$HOOK" "llm-failure-mode-check.sh executable"
run_content_eval "$REPO_ROOT/skill-manifest.json" "llm-failure-mode-check.sh" \
  "manifest registers llm-failure-mode-check"
run_content_eval "$REPO_ROOT/hooks/hooks.json" "llm-failure-mode-check.sh" \
  "hooks.json registers llm-failure-mode-check"

# Principle labels reference ETHOS/Karpathy in error messages
run_content_eval "$HOOK" "ETHOS/Karpathy" \
  "hook error messages cross-reference ETHOS/Karpathy"

_tmp=$(mktemp -d)
trap "find '$_tmp' -type f -exec rm -f {} + 2>/dev/null; rmdir '$_tmp' 2>/dev/null" EXIT

# Need a package.json so the halluc check runs
cat > "$_tmp/package.json" <<'EOF'
{ "name": "t", "dependencies": { "zod": "^3.0.0", "react": "^19.0.0" } }
EOF
git init -q "$_tmp" 2>/dev/null || true

_run() {
  local content="$1" file="$2"
  printf '%s\n' "$content" > "$_tmp/$file"
  git -C "$_tmp" add -N "$file" 2>/dev/null || true
  local err; err=$(mktemp); local ec=0
  export CLAUDE_SESSION_ID="eval-lf-$$"
  echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_tmp/$file\"}}" \
    | bash "$HOOK" 2>"$err" >/dev/null || ec=$?
  _last_stderr=$(cat "$err"); _last_exit=$ec
  rm -f "$err"; rm -rf "/tmp/hook-session-eval-lf-$$" 2>/dev/null || true
}

_ok() {
  local desc="$1" expected="$2" pat="${3:-}"
  local ok=true
  [ "$_last_exit" -ne "$expected" ] && ok=false
  [ -n "$pat" ] && ! echo "$_last_stderr" | grep -qF -- "$pat" && ok=false
  if [ "$ok" = true ]; then
    echo "  PASS  $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $desc (exit=$_last_exit expected=$expected)"
    [ -n "$pat" ] && echo "        missing: $pat"
    [ -n "$_last_stderr" ] && echo "        stderr: ${_last_stderr:0:200}"
    FAIL=$((FAIL + 1)); ERRORS="$ERRORS\n  FAIL: $desc"
  fi
}

# 1. Hallucinated API (warn)
_run 'import { z } from "zod";' "ok1.ts"
_ok "allows import in package.json" 0

_run 'import { thing } from "not-a-real-package-xyz";' "ha1.ts"
_ok "warns hallucinated import" 0 "Hallucinated APIs"

_run 'import { fs } from "node:fs";' "ok2.ts"
_ok "allows node: builtin" 0

_run 'import { readFile } from "fs";' "ok3.ts"
_ok "allows bare fs builtin" 0

_run 'import { z } from "@scope/pkg";' "ha2.ts"
_ok "scoped package not in deps warns" 0 "Hallucinated"

# 3. Unvalidated LLM Shapes (block)
_run 'const x = JSON.parse(raw);' "uv1.ts"
_ok "blocks JSON.parse without schema" 2 "Unvalidated shape"

_run 'const x = UserSchema.parse(JSON.parse(raw));' "uv2.ts"
_ok "allows JSON.parse with schema" 0

_run 'const x = z.object({}).parse(JSON.parse(raw));' "uv3.ts"
_ok "allows JSON.parse with z.object.parse" 0

_run '// allow: json-raw diagnostic
const x = JSON.parse(raw);' "uv4.ts"
_ok "allow comment bypasses JSON.parse block" 0

# 4. SSRF (block)
_run 'const r = await fetch(userUrl);' "ss1.ts"
_ok "blocks fetch with variable URL" 2 "SSRF"

_run 'const r = await fetch("https://api.example.com/v1");' "ss2.ts"
_ok "allows fetch with literal URL" 0

_run 'const r = await fetch(userUrl);
// allow: ssrf dev-only localhost' "ss3.ts"
_ok "allow comment bypasses SSRF" 0

_run 'if (isAllowedHost(userUrl)) {
  const r = await fetch(userUrl);
}' "ss4.ts"
_ok "allowlist pattern bypasses SSRF" 0

# 6. Stale memory (warn)
_run 'import { thing } from "./not-real-file-xyz.ts";' "sm1.ts"
# Relative import — skipped by halluc check. Stale-memory check is for string literals
_ok "relative import not flagged as halluc" 0

_run '// See src/components/nonexistent-xyz.tsx for reference
export const x = 1;' "sm2.ts"
_ok "warns cited nonexistent path" 0 "Stale Memory"

# Escape hatch
_run '// allow: llm-failure override
const x = JSON.parse(raw);' "esc.ts"
_ok "// allow: llm-failure bypasses all checks" 0

# Tests skipped
_run 'const x = JSON.parse(raw);' "t.test.ts"
_ok "test file skipped" 0
