# Evals for setup-toolchain skill
# Tests hook scripts, file structure, and SKILL.md correctness

SCRIPT="$REPO_ROOT/setup-toolchain/scripts/enforce-toolchain.sh"
SESSION_SCRIPT="$REPO_ROOT/setup-toolchain/scripts/session-env.sh"
LEGACY_LINTER="$REPO_ROOT/.claude/hooks/legacy-linter-check.sh"
SKILL_DIR="$REPO_ROOT/setup-toolchain"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "REFERENCE.md exists"
run_executable_eval "$SCRIPT" "enforce-toolchain.sh is executable"
run_executable_eval "$SESSION_SCRIPT" "session-env.sh is executable"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-toolchain" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "^description:" "SKILL.md has description"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md description has trigger phrase"

# ── npm blocked ─────────────────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"npm install lodash"}}' \
  2 "block: npm install" "npm banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"npm run build"}}' \
  2 "block: npm run" "npm banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"npm test"}}' \
  2 "block: npm test" "npm banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"npm ci"}}' \
  2 "block: npm ci" "npm banned"

# ── npx blocked ─────────────────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"npx create-react-app myapp"}}' \
  2 "block: npx" "npx banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"npx tsc --noEmit"}}' \
  2 "block: npx tsc --noEmit" "npx banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"npx tsc --noEmit 2>&1; echo \"TSC EXIT: $?\""}}' \
  2 "block: npx tsc with redirection" "npx banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"npx vitest run"}}' \
  2 "block: npx vitest" "npx banned"

# ── tsc blocked ─────────────────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"tsc"}}' \
  2 "block: tsc (bare)" "tsc banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"tsc --noEmit"}}' \
  2 "block: tsc --noEmit" "tsc banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"tsc --watch"}}' \
  2 "block: tsc --watch" "tsc banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"tsc -p tsconfig.json"}}' \
  2 "block: tsc -p tsconfig.json" "tsc banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bunx tsc --noEmit"}}' \
  2 "block: bunx tsc --noEmit" "tsc banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun run tsc"}}' \
  2 "block: bun run tsc" "tsc banned"

# ── tsgo allowed ────────────────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"tsgo --noEmit"}}' \
  0 "allow: tsgo --noEmit"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"tsgo"}}' \
  0 "allow: tsgo (bare)"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bunx tsgo --noEmit"}}' \
  0 "allow: bunx tsgo --noEmit"

# ── global install blocked ──────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun add -g typescript"}}' \
  2 "block: bun add -g" "Global installs banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun install --global prettier"}}' \
  2 "block: bun install --global" "Global installs banned"

# ── bun install/add (--yarn no longer required) ─────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun install"}}' \
  0 "allow: bun install (no --yarn required)"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun add lodash"}}' \
  0 "allow: bun add (no --yarn required)"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun install --yarn"}}' \
  0 "allow: bun install --yarn (still works)"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun add --yarn lodash"}}' \
  0 "allow: bun add --yarn (still works)"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun add lodash --yarn"}}' \
  0 "allow: bun add <pkg> --yarn (still works)"

# ── bunx for scripted tools blocked ─────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bunx biome check ."}}' \
  2 "block: bunx biome" "via bunx banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bunx ultracite fix"}}' \
  2 "block: bunx ultracite" "via bunx banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bunx react-doctor ."}}' \
  2 "block: bunx react-doctor" "via bunx banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bunx tsr generate"}}' \
  2 "block: bunx tsr" "via bunx banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bunx @tanstack/router-cli generate"}}' \
  2 "block: bunx @tanstack/router-cli" "via bunx banned"

# ── eslint/prettier blocked ──────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"eslint ."}}' \
  2 "block: eslint" "eslint banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"eslint --fix src/"}}' \
  2 "block: eslint --fix" "eslint banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"prettier --write ."}}' \
  2 "block: prettier" "prettier banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bunx eslint ."}}' \
  2 "block: bunx eslint" "eslint banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bunx prettier --write ."}}' \
  2 "block: bunx prettier" "prettier banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun add eslint --yarn"}}' \
  2 "block: bun add eslint" "eslint/prettier banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun add prettier --yarn"}}' \
  2 "block: bun add prettier" "eslint/prettier banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun add -D eslint prettier --yarn"}}' \
  2 "block: bun add eslint+prettier" "eslint/prettier banned"

# ── allowed commands ────────────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun run build"}}' \
  0 "allow: bun run build"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"vitest run"}}' \
  0 "allow: vitest run"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun run lint"}}' \
  0 "allow: bun run lint"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bun run quality:gate"}}' \
  0 "allow: bun run quality:gate"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"echo hello"}}' \
  0 "allow: unrelated command"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git status"}}' \
  0 "allow: git commands"

# ── chained commands ────────────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"echo hello && npm run test"}}' \
  2 "block: npm in chained command" "npm banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"ls; npx something"}}' \
  2 "block: npx after semicolon" "npx banned"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"cat file || tsc --noEmit"}}' \
  2 "block: tsc after ||" "tsc banned"

# ── edge cases ──────────────────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":""}}' \
  0 "allow: empty command"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{}}' \
  0 "allow: no command field"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"bunx some-other-tool"}}' \
  0 "allow: bunx for non-scripted tools"

# ── rm -rf guards ─────────────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"rm -rf /var/data"}}' \
  2 "block: rm -rf /var/data" "rm -r blocked"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"rm -r src/"}}' \
  2 "block: rm -r src/"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"rm -rf node_modules"}}' \
  0 "allow: rm -rf node_modules"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"rm -rf dist .next"}}' \
  0 "allow: rm -rf dist .next"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"rm -rf node_modules/.cache"}}' \
  0 "allow: rm -rf node_modules/.cache"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"rm -rf .claude/skills"}}' \
  0 "allow: rm -rf .claude/skills (skill infrastructure)"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"rm -rf .claude/hooks"}}' \
  0 "allow: rm -rf .claude/hooks (skill infrastructure)"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"rm -rf .claude/skills .claude/hooks"}}' \
  0 "allow: rm -rf both skill dirs"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"rm -r skills-lock.json"}}' \
  0 "allow: rm -r skills-lock.json"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"rm -rf frontend/.claude/skills frontend/.claude/hooks"}}' \
  0 "allow: rm -rf nested skill dirs"

# ── git rm (version-controlled, always allowed) ──────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git rm -r .claude/skills/"}}' \
  0 "allow: git rm -r (version-controlled)"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git rm -r frontend/.claude/hooks/ .claude/skills/ skills-lock.json"}}' \
  0 "allow: git rm -r multiple paths"

# ── git push --force ──────────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git push --force"}}' \
  2 "block: git push --force" "force"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git push origin main -f"}}' \
  2 "block: git push origin main -f"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git push --force-with-lease"}}' \
  0 "allow: git push --force-with-lease"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git push origin main"}}' \
  0 "allow: git push origin main"

# ── git reset --hard ──────────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git reset --hard"}}' \
  2 "block: git reset --hard" "reset"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git reset --soft HEAD~1"}}' \
  0 "allow: git reset --soft HEAD~1"

# ── git checkout . / git restore . ────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git checkout ."}}' \
  2 "block: git checkout ." "checkout"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git restore ."}}' \
  2 "block: git restore ."

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git checkout -- src/file.tsx"}}' \
  0 "allow: git checkout -- src/file.tsx"

run_hook_eval "$SCRIPT" \
  '{"tool_input":{"command":"git restore src/file.tsx"}}' \
  0 "allow: git restore src/file.tsx"

# ── destructive command content checks ────────────────────────

run_content_eval "$SCRIPT" "rm.*recursive" "hook blocks rm -rf"
run_content_eval "$SCRIPT" "git push.*force" "hook blocks git push --force"
run_content_eval "$SCRIPT" "git reset.*hard" "hook blocks git reset --hard"
run_content_eval "$SCRIPT" "git.*checkout.*restore" "hook blocks git checkout/restore ."

# ══════════════════════════════════════════════════════════════════
# legacy-linter-check.sh (PostToolUse: Edit|Write)
# ══════════════════════════════════════════════════════════════════

run_executable_eval "$LEGACY_LINTER" "legacy-linter-check.sh is executable"

# ── Skip non-Edit/Write ──────────────────────────────────────────

run_hook_eval "$LEGACY_LINTER" \
  '{"tool_name":"Bash","tool_input":{"command":"echo"}}' \
  0 "legacy-linter: skip Bash tool"

run_hook_eval "$LEGACY_LINTER" \
  '{"tool_name":"Read","tool_input":{"file_path":"foo.ts"}}' \
  0 "legacy-linter: skip Read tool"

# ── Skip non-matching extensions ────────────────────────────────

run_hook_eval "$LEGACY_LINTER" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.go"}}' \
  0 "legacy-linter: skip .go file"

# ── Block eslint-disable comments ────────────────────────────────

_ll_tmpdir=$(mktemp -d /tmp/legacy-linter-evals-XXXXXX)

printf '// eslint-disable-next-line @typescript-eslint/no-explicit-any\ntype AnyProtoForm = any;\n' > "$_ll_tmpdir/test1.ts"
run_hook_eval "$LEGACY_LINTER" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ll_tmpdir/test1.ts\"}}" \
  2 "block: eslint-disable-next-line comment" "Biome"

printf '/* eslint-disable no-console */\nconsole.log("hi");\n' > "$_ll_tmpdir/test2.ts"
run_hook_eval "$LEGACY_LINTER" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ll_tmpdir/test2.ts\"}}" \
  2 "block: eslint-disable block comment" "Biome"

printf '// eslint-disable no-unused-vars\nconst x = 1;\n' > "$_ll_tmpdir/test3.ts"
run_hook_eval "$LEGACY_LINTER" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ll_tmpdir/test3.ts\"}}" \
  2 "block: eslint-disable line comment" "Biome"

# ── Block eslint-enable comments ─────────────────────────────────

printf '/* eslint-enable */\nconst x = 1;\n' > "$_ll_tmpdir/test4.ts"
run_hook_eval "$LEGACY_LINTER" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ll_tmpdir/test4.ts\"}}" \
  2 "block: eslint-enable comment" "Biome"

# ── Block prettier-ignore comments ───────────────────────────────

printf '// prettier-ignore\nconst x = {a:1, b:2};\n' > "$_ll_tmpdir/test5.ts"
run_hook_eval "$LEGACY_LINTER" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ll_tmpdir/test5.ts\"}}" \
  2 "block: prettier-ignore comment" "Biome"

printf '/* prettier-ignore */\nconst x = 1;\n' > "$_ll_tmpdir/test6.tsx"
run_hook_eval "$LEGACY_LINTER" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ll_tmpdir/test6.tsx\"}}" \
  2 "block: prettier-ignore block comment" "Biome"

# ── Skip .js files ───────────────────────────────────────────────

printf '// eslint-disable-next-line\nconst x = 1;\n' > "$_ll_tmpdir/test7.js"
run_hook_eval "$LEGACY_LINTER" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ll_tmpdir/test7.js\"}}" \
  0 "legacy-linter: skip .js file"

# ── Allow clean TS files ─────────────────────────────────────────

printf 'const x = 1;\n// biome-ignore lint/suspicious/noExplicitAny: reason\ntype Y = any;\n' > "$_ll_tmpdir/clean.ts"
run_hook_eval "$LEGACY_LINTER" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ll_tmpdir/clean.ts\"}}" \
  0 "allow: clean TS file with biome-ignore"

rm -rf "$_ll_tmpdir"

# ── session-env.sh ──────────────────────────────────────────────

# Test that session-env.sh writes expected env vars
CLAUDE_ENV_FILE=$(mktemp)
export CLAUDE_ENV_FILE
"$SESSION_SCRIPT"
session_exit=$?

if [ $session_exit -eq 0 ]; then
  echo "  PASS  session-env.sh exits 0"
  PASS=$((PASS + 1))
else
  echo "  FAIL  session-env.sh exits $session_exit (expected 0)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: session-env.sh exits $session_exit"
fi

for var in PKG_MANAGER LINTER TEST_RUNNER; do
  if grep -qF "$var" "$CLAUDE_ENV_FILE"; then
    echo "  PASS  session-env.sh sets $var"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  session-env.sh missing $var"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: session-env.sh missing $var"
  fi
done

rm -f "$CLAUDE_ENV_FILE"
unset CLAUDE_ENV_FILE

# ── session-env.sh content checks ──────────────────────────────

run_content_eval "$SESSION_SCRIPT" "package.json" "session-env checks for package.json"
run_content_eval "$SESSION_SCRIPT" "react" "session-env checks for React dependency"
run_content_eval "$SESSION_SCRIPT" "WARNING" "session-env warns on non-frontend projects"
run_content_eval "$SESSION_SCRIPT" "NODE_OPTIONS" "session-env sets NODE_OPTIONS"
run_content_eval "$SESSION_SCRIPT" "dirty-files-baseline" "session-env captures dirty-files baseline"

# ── hook-lib.sh: session-scoped file tracking ──────────────────

HOOKLIB="$REPO_ROOT/shared/hook-lib.sh"
run_content_eval "$HOOKLIB" "session-touched-files" "hook-lib records touched files per session"
run_content_eval "$HOOKLIB" "hook_session_changed_files" "hook-lib provides session-scoped file helper"
run_content_eval "$HOOKLIB" "hook_filter_errors_to_session" "hook-lib provides error filtering helper"
run_content_eval "$HOOKLIB" "dirty-files-baseline" "hook-lib reads dirty-files baseline"
run_content_eval "$HOOKLIB" "hook_has_session_tracking" "hook-lib provides tracking check function"

# ── hook-lib.sh: session-scoping behavioral tests ──────────────

_scope_tmpdir=$(mktemp -d /tmp/session-scope-XXXXXX)
cd "$_scope_tmpdir"
git init -q && git commit --allow-empty -m "init" -q

# Create files that simulate two sessions on same branch
echo "const a = 1" > fileA.ts
echo "const b = 2" > fileB.ts
git add . && git commit -q -m "base"

# Simulate changes: both files modified (dirty working tree)
echo "const a = 2" > fileA.ts
echo "const b = 3" > fileB.ts

# Simulate session state: session only touched fileA.ts, fileB.ts was dirty at start
_test_session="$_scope_tmpdir/.session"
mkdir -p "$_test_session"
echo "$_scope_tmpdir/fileA.ts" > "$_test_session/session-touched-files"
echo "fileB.ts" > "$_test_session/dirty-files-baseline"

# Source hook-lib and override session dir
(
  source "$REPO_ROOT/shared/hook-lib.sh" < /dev/null
  _hook_session_dir="$_test_session"

  result=$(hook_session_changed_files "ts")

  # fileA.ts should be included (this session touched it, not in baseline)
  if echo "$result" | grep -q "fileA.ts"; then
    echo "  PASS  session-scoping includes session-touched file"
    # Write to a temp file so the parent can read it
    echo "PASS" > "$_test_session/test1"
  else
    echo "  FAIL  session-scoping should include fileA.ts but got: $result"
    echo "FAIL" > "$_test_session/test1"
  fi

  # fileB.ts should be excluded (was in dirty baseline)
  if echo "$result" | grep -q "fileB.ts"; then
    echo "  FAIL  session-scoping should exclude fileB.ts (dirty baseline) but included it"
    echo "FAIL" > "$_test_session/test2"
  else
    echo "  PASS  session-scoping excludes dirty-baseline file"
    echo "PASS" > "$_test_session/test2"
  fi

  # hook_has_session_tracking should be active
  if hook_has_session_tracking; then
    echo "  PASS  hook_has_session_tracking returns true with tracking data"
    echo "PASS" > "$_test_session/test3"
  else
    echo "  FAIL  hook_has_session_tracking should be true"
    echo "FAIL" > "$_test_session/test3"
  fi
) 2>/dev/null

# Collect results
for i in 1 2 3; do
  _r=$(cat "$_test_session/test$i" 2>/dev/null || echo "FAIL")
  if [ "$_r" = "PASS" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    case $i in
      1) ERRORS="$ERRORS\n  FAIL: session-scoping includes session-touched file" ;;
      2) ERRORS="$ERRORS\n  FAIL: session-scoping excludes dirty-baseline file" ;;
      3) ERRORS="$ERRORS\n  FAIL: hook_has_session_tracking returns true" ;;
    esac
  fi
done

cd "$REPO_ROOT"
