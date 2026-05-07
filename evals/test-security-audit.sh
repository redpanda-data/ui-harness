# Evals for security-audit-check.sh + file-changed-deps audit extension.
# OWASP Top 10 subset + STRIDE-I + LLM-trust + snyk/bun audit trigger.

HOOK="$REPO_ROOT/.claude/hooks/security-audit-check.sh"
DEPS_HOOK="$REPO_ROOT/.claude/hooks/file-changed-deps.sh"

run_file_eval "$HOOK" "security-audit-check.sh exists"
run_executable_eval "$HOOK" "security-audit-check.sh executable"
run_content_eval "$REPO_ROOT/skill-manifest.json" "security-audit-check.sh" \
  "manifest registers security-audit-check"

# Principle cross-reference
run_content_eval "$HOOK" "\\[ETHOS:" "security-audit-check cross-refs ETHOS"

# deps audit extension
run_content_eval "$DEPS_HOOK" "snyk test" "deps hook invokes snyk test"
run_content_eval "$DEPS_HOOK" "bun audit" "deps hook falls back to bun audit"
if grep -qE "npm audit" "$DEPS_HOOK"; then
  echo "  FAIL  deps hook uses npm audit (toolchain discipline violation)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: npm audit in deps hook"
else
  echo "  PASS  deps hook does not use npm audit"
  PASS=$((PASS + 1))
fi

_tmp=$(mktemp -d)
trap "find '$_tmp' -type f -exec rm -f {} + 2>/dev/null; rmdir '$_tmp' 2>/dev/null" EXIT
git init -q "$_tmp" 2>/dev/null || true

_run() {
  local content="$1" file="$2"
  printf '%s\n' "$content" > "$_tmp/$file"
  git -C "$_tmp" add -N "$file" 2>/dev/null || true
  local err; err=$(mktemp); local ec=0
  export CLAUDE_SESSION_ID="eval-sec-$$"
  echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_tmp/$file\"}}" \
    | bash "$HOOK" 2>"$err" >/dev/null || ec=$?
  _last_stderr=$(cat "$err"); _last_exit=$ec
  rm -f "$err"; rm -rf "/tmp/hook-session-eval-sec-$$" 2>/dev/null || true
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

# A03 SQL injection
_run 'const r = await db.query(`SELECT * FROM u WHERE id=${uid}`);' "sql.ts"
_ok "blocks SQL template concat" 2 "A03"

_run 'const r = await db.query("SELECT * FROM u WHERE id = ?", [uid]);' "sqlok.ts"
_ok "allows parameterized SQL" 0

# A02 hardcoded secret
_run 'const apiKey = "sk_live_abc123XYZ456def789";' "sec1.ts"
_ok "blocks hardcoded API key" 2 "A02"

_run 'const apiKey = process.env.API_KEY;' "sec2.ts"
_ok "allows env.API_KEY" 0

_run 'const token = "short";' "sec3.ts"
_ok "allows short string (not secret-shaped)" 0

# A02 weak hash on password
_run 'const h = crypto.createHash("md5").update(password).digest("hex");' "weak1.ts"
_ok "blocks MD5 on password" 2 "A02"

_run 'const h = crypto.createHash("sha256").update(etag).digest("hex");' "weak2.ts"
_ok "allows SHA256 on non-password" 0

# A05 eval / new Function / innerHTML
_run 'const r = eval(userInput);' "ev.ts"
_ok "blocks eval() with var" 2 "A05"

_run 'const fn = new Function("x", "return x+1");' "nf.ts"
_ok "blocks new Function()" 2 "A05"

_run 'el.innerHTML = userInput;' "ih.ts"
_ok "blocks innerHTML = var without DOMPurify" 2 "A05"

_run 'el.innerHTML = DOMPurify.sanitize(userInput);' "ihok.ts"
_ok "allows DOMPurify.sanitize" 0

_run '<div dangerouslySetInnerHTML={{__html: DOMPurify.sanitize(x)}} />' "dsi.tsx"
_ok "allows dangerouslySetInnerHTML with DOMPurify" 0

_run '<div dangerouslySetInnerHTML={{__html: userHtml}} />' "dsi2.tsx"
_ok "blocks dangerouslySetInnerHTML without DOMPurify" 2 "A05"

# A08 unsafe YAML
_run 'const cfg = YAML.load(raw);' "yaml.ts"
_ok "blocks unsafe YAML.load" 2 "A08"

# STRIDE-I
_run 'res.json({ error: err.stack });' "stack.ts"
_ok "blocks err.stack in response" 2 "STRIDE-I"

# Escape hatch
_run '// allow: security-audit intentional
const apiKey = "sk_live_abc123XYZ456def789";' "esc.ts"
_ok "// allow: security-audit bypasses" 0

_run '// allow: secret-literal test fixture
const apiKey = "sk_live_abc123XYZ456def789";' "esc2.ts"
_ok "// allow: secret-literal bypasses A02" 0

_run '// allow: innerHTML legacy migration
el.innerHTML = x;' "esc3.ts"
_ok "// allow: innerHTML bypasses A05" 0

# Tests skipped
_run 'const apiKey = "sk_live_abc123XYZ456def789";' "x.test.ts"
_ok "test file skipped" 0
