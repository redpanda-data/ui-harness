# Evals for setup-env-validation skill

SCRIPT="$REPO_ROOT/setup-env-validation/scripts/env-validation-check.sh"
SKILL_DIR="$REPO_ROOT/setup-env-validation"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "REFERENCE.md exists"
run_executable_eval "$SCRIPT" "env-validation-check.sh is executable"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-env-validation" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "t3-env" "SKILL.md mentions t3-env"
run_content_eval "$SKILL_DIR/SKILL.md" "process.env" "SKILL.md mentions process.env ban"

# ── Hook: skip non-Edit/Write ──────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"echo"}}' \
  0 "skip: Bash tool"

# ── Hook: skip env files ────────────────────────────────────────

_ev_tmpdir=$(mktemp -d /tmp/env-val-evals-XXXXXX)

tmpfile="$_ev_tmpdir/env.ts"
echo 'const x = process.env.DATABASE_URL' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "skip: env.ts file"

tmpfile="$_ev_tmpdir/env.mts"
echo 'const x = process.env.DATABASE_URL' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "skip: env.mts file"

# ── Hook: skip test files ───────────────────────────────────────

tmpfile="$_ev_tmpdir/api.test.ts"
echo 'const url = process.env.TEST_URL' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "skip: test file"

tmpfile="$_ev_tmpdir/api.spec.ts"
echo 'const url = process.env.TEST_URL' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "skip: spec file"

# ── Hook: block process.env in regular files ─────────────────────

tmpfile="$_ev_tmpdir/config.ts"
echo 'const url = process.env.API_URL' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: process.env in regular .ts file" "env"

tmpfile="$_ev_tmpdir/app.tsx"
echo 'const url = process.env.PUBLIC_API_URL' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: process.env in .tsx file"

# ── Hook: allow clean code ───────────────────────────────────────

tmpfile="$_ev_tmpdir/utils.ts"
echo 'import { env } from "@/env"; const url = env.API_URL' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: validated env import"

# ── Hook: skip non-JS/TS ────────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.go"}}' \
  0 "skip: .go file"

# ── Script content ──────────────────────────────────────────────

run_content_eval "$SCRIPT" "process" "hook checks for process.env"
run_content_eval "$SCRIPT" "env.ts" "hook skips env.ts"
run_content_eval "$SCRIPT" "hook_skip_tests" "hook uses shared test skip"

rm -rf "$_ev_tmpdir"
