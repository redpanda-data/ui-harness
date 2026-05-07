# Evals for setup-quality-gate skill

SCRIPT="$REPO_ROOT/setup-quality-gate/scripts/typecheck-stop.sh"
SKILL_DIR="$REPO_ROOT/setup-quality-gate"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "REFERENCE.md exists"
run_executable_eval "$SCRIPT" "typecheck-stop.sh is executable"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-quality-gate" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "quality:gate" "SKILL.md mentions quality:gate script"
run_content_eval "$SKILL_DIR/SKILL.md" "type:check" "SKILL.md mentions type:check"
run_content_eval "$SKILL_DIR/SKILL.md" "GitHub Actions" "SKILL.md mentions CI"

# ── REFERENCE.md content ────────────────────────────────────────

run_content_eval "$SKILL_DIR/REFERENCE.md" "quality-gate.yml" "REFERENCE has workflow filename"
run_content_eval "$SKILL_DIR/REFERENCE.md" "git diff --exit-code" "REFERENCE has formatting integrity check"
run_content_eval "$SKILL_DIR/REFERENCE.md" "bun run type:check" "REFERENCE has type:check command"
run_content_eval "$SKILL_DIR/REFERENCE.md" "related" "REFERENCE mentions related tests"

# ── Hook script content ─────────────────────────────────────────

run_content_eval "$SCRIPT" "bun run type:check" "hook uses bun run type:check"
run_content_eval "$SCRIPT" "git diff --name-only" "hook checks for changed JS/TS files"
run_content_eval "$SCRIPT" "hook_(block|stop_block|stop_finding)|decision.*block|exit 2" "hook blocks on failure"
run_content_eval "$SCRIPT" "head -30" "hook truncates output"
run_content_eval "$SCRIPT" "scripts.*type:check" "hook skips when type:check script missing"
run_content_eval "$SCRIPT" "hook_(block|stop_block|stop_finding)|decision.*block|exit 2" "hook blocks on type errors"
run_content_eval "$SCRIPT" "typecheck-baseline" "hook compares against session baseline"
run_content_eval "$SCRIPT" "pre-existing" "hook identifies pre-existing errors"
run_content_eval "$SCRIPT" "comm -23" "hook diffs current errors against baseline"
run_content_eval "$SCRIPT" "new type error|_new_errors|typecheck-baseline" "hook reports only new errors"
run_content_eval "$SCRIPT" "hook_session_changed_files" "hook uses session-scoped file detection"
run_content_eval "$SCRIPT" "hook_filter_errors_to_session" "hook filters errors to session files"
run_content_eval "$SCRIPT" "other session" "hook allows errors from other sessions"

# ── session-env.sh: baseline capture ──────────────────────────────

SESSION_SCRIPT="$REPO_ROOT/setup-toolchain/scripts/session-env.sh"
run_content_eval "$SESSION_SCRIPT" "typecheck-baseline" "session-env captures typecheck baseline"
run_content_eval "$SESSION_SCRIPT" "bun run type:check" "session-env runs type:check for baseline"
run_content_eval "$SESSION_SCRIPT" "dirty-files-baseline" "session-env captures dirty-files baseline"
run_content_eval "$SESSION_SCRIPT" "test-timing-baseline" "session-env captures test timing baseline"
run_content_eval "$SESSION_SCRIPT" "vitest.config" "session-env discovers vitest configs for baseline"
run_content_eval "$SESSION_SCRIPT" "reporter=json" "session-env uses JSON reporter for timing extraction"

# ── test-perf-stop.sh: File structure ────────────────────────────

PERF_SCRIPT="$REPO_ROOT/setup-quality-gate/scripts/test-perf-stop.sh"
run_file_eval "$PERF_SCRIPT" "test-perf-stop.sh exists"
run_executable_eval "$PERF_SCRIPT" "test-perf-stop.sh is executable"

# ── test-perf-stop.sh: symlink wiring ───────────────────────────

PERF_SYMLINK="$REPO_ROOT/.claude/hooks/test-perf-stop.sh"
if [ -f "$PERF_SYMLINK" ] && [ ! -L "$PERF_SYMLINK" ]; then
  echo "  PASS  test-perf-stop.sh is a real file in .claude/hooks/"
  PASS=$((PASS + 1))
else
  echo "  FAIL  test-perf-stop.sh missing or is symlink in .claude/hooks/"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: test-perf-stop.sh"
fi

# ── test-perf-stop.sh: wired in all hook configs ────────────────

for config_file in "$REPO_ROOT/.claude/settings.json" "$REPO_ROOT/hooks/hooks.json" "$REPO_ROOT/.codex/hooks.json"; do
  config_name=$(basename "$(dirname "$config_file")")/$(basename "$config_file")
  if grep -q "test-perf-stop" "$config_file" 2>/dev/null; then
    echo "  PASS  test-perf-stop.sh wired in $config_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  test-perf-stop.sh missing from $config_name"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: test-perf-stop.sh missing from $config_name"
  fi
done

# ── test-perf-stop.sh: script content ───────────────────────────

run_content_eval "$PERF_SCRIPT" "test-timing-baseline" "perf hook reads session baseline"
run_content_eval "$PERF_SCRIPT" "test-timing-current" "perf hook captures current timings"
run_content_eval "$PERF_SCRIPT" "hook_session_changed_files" "perf hook uses session-scoped file detection"
run_content_eval "$PERF_SCRIPT" "vitest.config" "perf hook discovers vitest configs"
run_content_eval "$PERF_SCRIPT" "reporter=json" "perf hook uses JSON reporter"
run_content_eval "$PERF_SCRIPT" "additionalContext" "perf hook outputs as informational context (non-blocking)"
run_content_eval "$PERF_SCRIPT" "pct > 30" "perf hook uses 30% threshold for significant changes"
run_content_eval "$PERF_SCRIPT" "before > 10" "perf hook filters noise from tests under 10ms"

# ── bundle-guard.sh: File structure ───────────────────────────────

BUNDLE_SCRIPT="$REPO_ROOT/setup-quality-gate/scripts/bundle-guard.sh"
run_file_eval "$BUNDLE_SCRIPT" "bundle-guard.sh exists"
run_executable_eval "$BUNDLE_SCRIPT" "bundle-guard.sh is executable"

# ── bundle-guard.sh: skip non-package.json ────────────────────────

run_hook_eval "$BUNDLE_SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.ts"}}' \
  0 "skip: non-package.json file"

# ── bundle-guard.sh: skip non-Edit/Write ─────────────────────────

run_hook_eval "$BUNDLE_SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}' \
  0 "skip: Bash tool"

# ── bundle-guard.sh: block moment in dependencies ────────────────

tmpdir=$(mktemp -d /tmp/bundle-guard-XXXXXX)
printf '{"dependencies":{"moment":"^2.29.0"}}' > "$tmpdir/package.json"

run_hook_eval "$BUNDLE_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpdir/package.json\"}}" \
  2 "block: moment in dependencies" "moment"

rm -rf "$tmpdir"

# ── bundle-guard.sh: block lodash in dependencies ────────────────

tmpdir=$(mktemp -d /tmp/bundle-guard-XXXXXX)
printf '{"dependencies":{"lodash":"^4.17.0"}}' > "$tmpdir/package.json"

run_hook_eval "$BUNDLE_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpdir/package.json\"}}" \
  2 "block: lodash in dependencies" "lodash"

rm -rf "$tmpdir"

# ── bundle-guard.sh: allow lodash-es ─────────────────────────────

tmpdir=$(mktemp -d /tmp/bundle-guard-XXXXXX)
printf '{"dependencies":{"lodash-es":"^4.17.0"}}' > "$tmpdir/package.json"

run_hook_eval "$BUNDLE_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpdir/package.json\"}}" \
  0 "allow: lodash-es in dependencies"

rm -rf "$tmpdir"

# ── bundle-guard.sh: block jquery ────────────────────────────────

tmpdir=$(mktemp -d /tmp/bundle-guard-XXXXXX)
printf '{"dependencies":{"jquery":"^3.6.0"}}' > "$tmpdir/package.json"

run_hook_eval "$BUNDLE_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpdir/package.json\"}}" \
  2 "block: jquery in dependencies" "jQuery"

rm -rf "$tmpdir"

# ── bundle-guard.sh: allow moment in devDependencies ─────────────

tmpdir=$(mktemp -d /tmp/bundle-guard-XXXXXX)
printf '{"devDependencies":{"moment":"^2.29.0"}}' > "$tmpdir/package.json"

run_hook_eval "$BUNDLE_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpdir/package.json\"}}" \
  0 "allow: moment in devDependencies"

rm -rf "$tmpdir"

# ── bundle-guard.sh: block classnames ────────────────────────────

tmpdir=$(mktemp -d /tmp/bundle-guard-XXXXXX)
printf '{"dependencies":{"classnames":"^2.3.0"}}' > "$tmpdir/package.json"

run_hook_eval "$BUNDLE_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpdir/package.json\"}}" \
  2 "block: classnames in dependencies" "clsx"

rm -rf "$tmpdir"

# ── bundle-guard.sh: block core-js ───────────────────────────────

tmpdir=$(mktemp -d /tmp/bundle-guard-XXXXXX)
printf '{"dependencies":{"core-js":"^3.37.0"}}' > "$tmpdir/package.json"

run_hook_eval "$BUNDLE_SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpdir/package.json\"}}" \
  2 "block: core-js in dependencies" "core-js"

rm -rf "$tmpdir"

# ── bundle-guard.sh: script content ──────────────────────────────

run_content_eval "$BUNDLE_SCRIPT" "moment" "bundle-guard checks moment"
run_content_eval "$BUNDLE_SCRIPT" "lodash" "bundle-guard checks lodash"
run_content_eval "$BUNDLE_SCRIPT" "jquery" "bundle-guard checks jquery"
run_content_eval "$BUNDLE_SCRIPT" "classnames" "bundle-guard checks classnames"
run_content_eval "$BUNDLE_SCRIPT" "core-js" "bundle-guard checks core-js"

# ── test-perf-check.sh: File structure ───────────────────────────

PERF_CHECK_SCRIPT="$REPO_ROOT/setup-quality-gate/scripts/test-perf-check.sh"
run_file_eval "$PERF_CHECK_SCRIPT" "test-perf-check.sh exists"
run_executable_eval "$PERF_CHECK_SCRIPT" "test-perf-check.sh is executable"

PERF_CHECK_SYMLINK="$REPO_ROOT/.claude/hooks/test-perf-check.sh"
if [ -f "$PERF_CHECK_SYMLINK" ] && [ ! -L "$PERF_CHECK_SYMLINK" ]; then
  echo "  PASS  test-perf-check.sh is a real file in .claude/hooks/"
  PASS=$((PASS + 1))
else
  echo "  FAIL  test-perf-check.sh missing or is symlink in .claude/hooks/"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: test-perf-check.sh"
fi

# ── test-perf-check.sh: wired in hook configs ───────────────────

for config_file in "$REPO_ROOT/.claude/settings.json" "$REPO_ROOT/hooks/hooks.json"; do
  config_name=$(basename "$(dirname "$config_file")")/$(basename "$config_file")
  if grep -q "test-perf-check" "$config_file" 2>/dev/null; then
    echo "  PASS  test-perf-check.sh wired in $config_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  test-perf-check.sh missing from $config_name"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: test-perf-check.sh missing from $config_name"
  fi
done

# ── test-perf-check.sh: script content ──────────────────────────

run_content_eval "$PERF_CHECK_SCRIPT" "await.*import" "perf-check detects dynamic imports"
run_content_eval "$PERF_CHECK_SCRIPT" "pool.*threads" "perf-check detects missing pool: threads"
run_content_eval "$PERF_CHECK_SCRIPT" "isolate.*false" "perf-check detects missing isolate: false"
run_content_eval "$PERF_CHECK_SCRIPT" "importActual" "perf-check excludes vi.importActual from dynamic import check"
run_content_eval "$PERF_CHECK_SCRIPT" "happy-dom.*jsdom" "perf-check skips isolate check for browser-env configs"

# ── test-perf-check.sh: skip non-test, non-config files ─────────

tmpdir=$(mktemp -d /tmp/perf-check-XXXXXX)
printf 'const x = await import("./foo");\n' > "$tmpdir/utils.ts"
(cd "$tmpdir" && git init -q && git add . && git commit -q -m "init") 2>/dev/null

run_hook_eval "$PERF_CHECK_SCRIPT" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$tmpdir/utils.ts\"}}" \
  0 "skip: non-test non-config file"

rm -rf "$tmpdir"

# ── test-perf-check.sh: warn on await import() in test file ─────

tmpdir=$(mktemp -d /tmp/perf-check-XXXXXX)
printf 'const mod = await import("./helpers");\n' > "$tmpdir/foo.test.ts"
(cd "$tmpdir" && git init -q && git add . && git commit -q -m "init" && printf '+const mod = await import("./helpers");\n' > "$tmpdir/foo.test.ts") 2>/dev/null

run_hook_eval "$PERF_CHECK_SCRIPT" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$tmpdir/foo.test.ts\"}}" \
  0 "warn: await import() in test file" "~100ms"

rm -rf "$tmpdir"

# ── test-perf-check.sh: allow vi.importActual ───────────────────

tmpdir=$(mktemp -d /tmp/perf-check-XXXXXX)
printf 'const actual = await vi.importActual("./helpers");\n' > "$tmpdir/bar.test.ts"
(cd "$tmpdir" && git init -q && git add . && git commit -q -m "init" && printf '+const actual = await vi.importActual("./helpers");\n' > "$tmpdir/bar.test.ts") 2>/dev/null

run_hook_eval "$PERF_CHECK_SCRIPT" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$tmpdir/bar.test.ts\"}}" \
  0 "allow: vi.importActual in test file"

rm -rf "$tmpdir"

# ── test-perf-check.sh: warn on vitest config missing pool ──────

tmpdir=$(mktemp -d /tmp/perf-check-XXXXXX)
cat > "$tmpdir/vitest.config.mts" << 'VEOF'
import { defineConfig } from 'vitest/config';
export default defineConfig({
  test: {
    globals: true,
  },
});
VEOF
(cd "$tmpdir" && git init -q && git add . && git commit -q -m "init") 2>/dev/null

run_hook_eval "$PERF_CHECK_SCRIPT" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$tmpdir/vitest.config.mts\"}}" \
  0 "warn: vitest config missing pool: threads" "pool"

rm -rf "$tmpdir"

# ── test-perf-check.sh: allow vitest config with pool: threads ──

tmpdir=$(mktemp -d /tmp/perf-check-XXXXXX)
cat > "$tmpdir/vitest.config.mts" << 'VEOF'
import { defineConfig } from 'vitest/config';
export default defineConfig({
  test: {
    globals: true,
    pool: 'threads',
  },
});
VEOF
(cd "$tmpdir" && git init -q && git add . && git commit -q -m "init") 2>/dev/null

run_hook_eval "$PERF_CHECK_SCRIPT" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$tmpdir/vitest.config.mts\"}}" \
  0 "allow: vitest config with pool: threads"

rm -rf "$tmpdir"

# ── test-perf-check.sh: warn on unit config missing isolate ─────

tmpdir=$(mktemp -d /tmp/perf-check-XXXXXX)
cat > "$tmpdir/vitest.config.mts" << 'VEOF'
import { defineConfig } from 'vitest/config';
export default defineConfig({
  test: {
    globals: true,
    pool: 'threads',
  },
});
VEOF
(cd "$tmpdir" && git init -q && git add . && git commit -q -m "init") 2>/dev/null

run_hook_eval "$PERF_CHECK_SCRIPT" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$tmpdir/vitest.config.mts\"}}" \
  0 "warn: unit vitest config missing isolate: false" "isolate"

rm -rf "$tmpdir"

# ── test-perf-check.sh: skip isolate warn for integration config ─

tmpdir=$(mktemp -d /tmp/perf-check-XXXXXX)
cat > "$tmpdir/vitest.config.integration.mts" << 'VEOF'
import { defineConfig } from 'vitest/config';
export default defineConfig({
  test: {
    globals: true,
    pool: 'threads',
    environment: 'happy-dom',
  },
});
VEOF
(cd "$tmpdir" && git init -q && git add . && git commit -q -m "init") 2>/dev/null

run_hook_eval "$PERF_CHECK_SCRIPT" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$tmpdir/vitest.config.integration.mts\"}}" \
  0 "skip: no isolate warn for happy-dom config"

rm -rf "$tmpdir"

# ── test-perf-check.sh: skip non-Edit/Write tool ────────────────

run_hook_eval "$PERF_CHECK_SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"vitest --run"}}' \
  0 "skip: non-Edit/Write tool"

# ── test-perf-check.sh: warn on userEvent.type() ────────────────

tmpdir=$(mktemp -d /tmp/perf-check-XXXXXX)
printf 'await user.type(input, "hello world");\n' > "$tmpdir/login.test.tsx"
(cd "$tmpdir" && git init -q && git add . && git commit -q -m "init" && printf '+await user.type(input, "hello world");\n' > "$tmpdir/login.test.tsx") 2>/dev/null

run_hook_eval "$PERF_CHECK_SCRIPT" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$tmpdir/login.test.tsx\"}}" \
  0 "warn: userEvent.type() in test file" "per-keystroke"

rm -rf "$tmpdir"

# ── test-perf-check.sh: allow user.paste() ──────────────────────

tmpdir=$(mktemp -d /tmp/perf-check-XXXXXX)
printf 'await user.clear(input);\nawait user.paste("hello world");\n' > "$tmpdir/login.test.tsx"
(cd "$tmpdir" && git init -q && git add . && git commit -q -m "init" && printf '+await user.clear(input);\n+await user.paste("hello world");\n' > "$tmpdir/login.test.tsx") 2>/dev/null

run_hook_eval "$PERF_CHECK_SCRIPT" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$tmpdir/login.test.tsx\"}}" \
  0 "allow: user.paste() in test file (no type warning)"

rm -rf "$tmpdir"

# ── test-perf-check.sh: warn on setInterval() in test file ──────

tmpdir=$(mktemp -d /tmp/perf-check-XXXXXX)
printf 'const id = setInterval(tick, 1000);\n' > "$tmpdir/poll.test.tsx"
(cd "$tmpdir" && git init -q && git add . && git commit -q -m "init" && printf '+const id = setInterval(tick, 1000);\n' > "$tmpdir/poll.test.tsx") 2>/dev/null

run_hook_eval "$PERF_CHECK_SCRIPT" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$tmpdir/poll.test.tsx\"}}" \
  0 "warn: setInterval() in test file" "open handle"

rm -rf "$tmpdir"

# ── test-perf-check.sh: allow setInterval with escape hatch ─────

tmpdir=$(mktemp -d /tmp/perf-check-XXXXXX)
printf 'const id = setInterval(tick, 1000); // allow: test-set-interval needs real timer for x\n' > "$tmpdir/poll.test.tsx"
(cd "$tmpdir" && git init -q && git add . && git commit -q -m "init" && printf '+const id = setInterval(tick, 1000); // allow: test-set-interval needs real timer for x\n' > "$tmpdir/poll.test.tsx") 2>/dev/null

run_hook_eval "$PERF_CHECK_SCRIPT" \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$tmpdir/poll.test.tsx\"}}" \
  0 "allow: setInterval with escape hatch"

rm -rf "$tmpdir"

run_content_eval "$PERF_CHECK_SCRIPT" "setInterval" "perf-check detects setInterval leak"

# ── test-perf-stop.sh: script content (new features) ────────────

run_content_eval "$PERF_SCRIPT" "detectAsyncLeaks" "perf-stop runs async leak detection"
run_content_eval "$PERF_SCRIPT" "Slow tests detected" "perf-stop flags slow tests"
run_content_eval "$PERF_SCRIPT" "500" "perf-stop has 500ms unit threshold"
