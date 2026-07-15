# Evals for snyk-ux-security skill
# Tests file structure, SKILL.md content, react-peer-check script behavior, lockfile-sync hook

SKILL_DIR="$REPO_ROOT/snyk-ux-security"
SKILL_MD="$SKILL_DIR/SKILL.md"
REFERENCE_MD="$SKILL_DIR/REFERENCE.md"
PEER_CHECK="$SKILL_DIR/scripts/react-peer-check.sh"
LOCK_HOOK="$REPO_ROOT/.claude/hooks/lockfile-sync-check.sh"
MANIFEST="$REPO_ROOT/skill-manifest.json"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_MD" "SKILL.md exists"
run_executable_eval "$PEER_CHECK" "react-peer-check.sh is executable"
run_executable_eval "$LOCK_HOOK" "lockfile-sync-check.sh is executable"

# Guardrail: no static config file (args-based only)
if [ -f "$SKILL_DIR/config.yaml" ] || [ -f "$SKILL_DIR/config.yml" ] || [ -f "$SKILL_DIR/config.json" ]; then
  echo "  FAIL  SKILL has no static config file (should be args-based)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: static config file present"
else
  echo "  PASS  SKILL has no static config file (args-based)"
  PASS=$((PASS + 1))
fi

# ── SKILL.md frontmatter + triggers ─────────────────────────────

run_content_eval "$SKILL_MD" "^name: snyk-ux-security" "SKILL.md has correct name"
run_content_eval "$SKILL_MD" "^description:" "SKILL.md has description"
run_content_eval "$SKILL_MD" "^disable-model-invocation: true$" "SKILL.md requires explicit invocation"

# Description must NOT hardcode specific repo names (generic skill, paths via args)
desc=$(awk '/^description:/{print; exit}' "$SKILL_MD")
if echo "$desc" | grep -qE "Cloud UI|Admin UI|Console UI|UI Registry|cloud-ui|admin-ui|console-ui"; then
  echo "  FAIL  description hardcodes specific repo names (should be generic)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: description hardcodes repo names"
else
  echo "  PASS  description is generic (no hardcoded repo names)"
  PASS=$((PASS + 1))
fi

# ── Args-based input ────────────────────────────────────────────

run_content_eval "$SKILL_MD" "\\\$ARGUMENTS" "SKILL.md reads \$ARGUMENTS"
run_content_eval "$SKILL_MD" "[Gg]lob" "SKILL.md supports globs in args"
run_content_eval "$SKILL_MD" "/snyk-ux-security apps/" "SKILL.md shows usage example with paths"
run_content_eval "$SKILL_MD" "CODEOWNERS" "SKILL.md infers reviewers from CODEOWNERS"
run_content_eval "$SKILL_MD" "git log" "SKILL.md uses git log for reviewer inference fallback"

# ── Workflow contract ───────────────────────────────────────────

run_content_eval "$SKILL_MD" "[Ss]equential" "SKILL.md enforces sequential processing"
run_content_eval "$SKILL_MD" "snyk test" "SKILL.md runs snyk test"
run_content_eval "$SKILL_MD" "snyk monitor" "SKILL.md runs snyk monitor"
run_content_eval "$SKILL_MD" "bun audit" "SKILL.md runs bun audit"
run_content_eval "$SKILL_MD" "bun why" "SKILL.md uses bun why"
run_content_eval "$SKILL_MD" "bun update" "SKILL.md uses bun update"
run_content_eval "$SKILL_MD" "bun info" "SKILL.md uses bun info"

# ── Lockfile sync (bun.lock + yarn.lock) ────────────────────────

run_content_eval "$SKILL_MD" "bun install --yarn" "SKILL.md runs bun install --yarn (regen yarn.lock for Snyk)"
run_content_eval "$SKILL_MD" "yarn\.lock" "SKILL.md references yarn.lock"
run_content_eval "$SKILL_MD" "bun\.lock" "SKILL.md references bun.lock"
run_content_eval "$SKILL_MD" "Snyk IO.*yarn\.lock|yarn\.lock.*Snyk" "SKILL.md explains Snyk IO needs yarn.lock"
run_content_eval "$SKILL_MD" "[Dd]ual.lockfile|both lockfiles" "SKILL.md enforces dual-lockfile sync"
run_content_eval "$SKILL_MD" "lockfile-sync-check" "SKILL.md references lockfile-sync-check hook"
run_content_eval "$SKILL_MD" "package-lock\.json" "SKILL.md calls out package-lock.json"
run_content_eval "$SKILL_MD" 'Do not create, update, or commit|No `package-lock\.json` by default' "SKILL.md avoids package-lock churn"
run_content_eval "$REFERENCE_MD" "JS package manager stance" "REFERENCE.md documents JS package-manager stance"
run_content_eval "$REFERENCE_MD" 'Do not run `npm audit`|Do not.*npm audit' "REFERENCE.md forbids npm audit"
run_content_eval "$REFERENCE_MD" "package-lock\.json.*stale|stale/wrong.*package-lock\.json" "REFERENCE.md treats package-lock as stale in bun projects"
run_content_eval "$REFERENCE_MD" "Evidence gate for npm transitives" "REFERENCE.md requires evidence before dismissing npm transitives"

# Guardrail: bun-only for runtime (no npm/yarn/pnpm commands except `bun install --yarn`)
if grep -qE "^\s*(npm (install|update|audit|view|why)|yarn (add|upgrade|audit|why)|pnpm (add|update|audit|why))" "$SKILL_MD"; then
  echo "  FAIL  SKILL.md contains npm/yarn/pnpm runtime commands"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: npm/yarn/pnpm runtime commands present"
else
  echo "  PASS  SKILL.md uses bun-only runtime commands"
  PASS=$((PASS + 1))
fi

# ── React 18 pin ────────────────────────────────────────────────

run_content_eval "$SKILL_MD" "React 18" "SKILL.md pins React 18"
run_content_eval "$SKILL_MD" "react19-blocked" "SKILL.md records react19-blocked skip reason"
run_content_eval "$SKILL_MD" "peerDependencies\.react" "SKILL.md reads react peer dep"

# ── No-deferral rule ────────────────────────────────────────────

run_content_eval "$SKILL_MD" "[Nn]ever defer" "SKILL.md forbids deferring vulns"
run_content_eval "$SKILL_MD" "[Ii]ncremental|step by step|one at time|one major per commit" "SKILL.md describes incremental major migration"
run_content_eval "$SKILL_MD" "7.*8.*9" "SKILL.md walks majors one at a time"
run_content_eval "$SKILL_MD" "[Ee]scalate" "SKILL.md escalates instead of skipping"

if grep -q "breaking-deferred" "$SKILL_MD"; then
  echo "  FAIL  SKILL.md still references breaking-deferred"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: SKILL.md references breaking-deferred"
else
  echo "  PASS  SKILL.md does not defer breaking changes"
  PASS=$((PASS + 1))
fi

# ── Changelog read mandatory ────────────────────────────────────

run_content_eval "$SKILL_MD" "[Cc]hangelog" "SKILL.md requires changelog read"
run_content_eval "$SKILL_MD" "BREAKING" "SKILL.md looks for BREAKING markers"

# ── Verify gate ─────────────────────────────────────────────────

run_content_eval "$SKILL_MD" "bun run lint:fix" "SKILL.md runs lint:fix verify"
run_content_eval "$SKILL_MD" "bun run type:check" "SKILL.md runs type:check verify"
run_content_eval "$SKILL_MD" "bun test" "SKILL.md runs tests verify"

# ── PR open + metadata ──────────────────────────────────────────

run_content_eval "$SKILL_MD" "gh pr create" "SKILL.md opens PR via gh"
run_content_eval "$SKILL_MD" "--reviewer" "SKILL.md assigns reviewers"
run_content_eval "$SKILL_MD" "--label" "SKILL.md adds labels"
run_content_eval "$SKILL_MD" "--assignee" "SKILL.md assigns UX team"
run_content_eval "$SKILL_MD" "security" "SKILL.md uses security label"
run_content_eval "$SKILL_MD" "gh workflow run" "SKILL.md triggers cloud review workflow"

# ── Commit format ───────────────────────────────────────────────

run_content_eval "$SKILL_MD" "fix\(deps\)" "SKILL.md uses fix(deps) conventional commit"
run_content_eval "$SKILL_MD" "refactor\(deps\)" "SKILL.md uses refactor(deps) for migration commits"

# ── Worktree isolation ──────────────────────────────────────────

run_content_eval "$SKILL_MD" "worktree" "SKILL.md uses worktree per path"
run_content_eval "$SKILL_MD" "isolation" "SKILL.md specifies isolation mode"
run_content_eval "$SKILL_MD" "subagent" "SKILL.md spawns subagent per path"

# ── Security hygiene ────────────────────────────────────────────

run_content_eval "$SKILL_MD" "[Nn]ever (execute|run) code from advisories|[Nn]ever.*token" "SKILL.md has security notes"

# ── Dismissal hardening: transitive-only findings ────────────────

run_content_eval "$SKILL_MD" "direct dep absence.*dismiss|not add.*package\\.json" "SKILL.md warns not to add direct deps just to suppress transitives"
run_content_eval "$SKILL_MD" "/steelman" "SKILL.md explicitly invokes /steelman for transitive-only bump decisions"
run_content_eval "$SKILL_MD" "/diagnose" "SKILL.md invokes the available /diagnose skill before package.json security fixes"
run_content_eval "$SKILL_MD" "package\\.json admission gate|admission gate.*package\\.json" "SKILL.md has package.json admission gate"
run_content_eval "$SKILL_MD" "uncertain.*escalate|escalate.*uncertain" "SKILL.md escalates uncertain transitive findings"
run_content_eval "$SKILL_MD" "bump.*makes no sense|makes no sense.*bump" "SKILL.md blocks nonsensical transitive bumps"
run_content_eval "$SKILL_MD" "Override list growth is a smell|override list.*smell" "SKILL.md treats override-list growth as smell"
run_content_eval "$SKILL_MD" "Remove dependency surface|dependency surface third|native/in-house" "SKILL.md prefers dependency-surface removal before overrides"
run_content_eval "$REFERENCE_MD" "Transitive-only dismissal checklist" "REFERENCE.md has transitive-only dismissal checklist"
run_content_eval "$REFERENCE_MD" "Direct dependency absence is evidence" "REFERENCE.md treats missing direct dep as dismissal evidence"
run_content_eval "$REFERENCE_MD" "do not add.*package\\.json" "REFERENCE.md forbids package.json growth for suppression-only overrides"
run_content_eval "$REFERENCE_MD" "/steelman transitive bump gate|transitive bump gate.*\\/steelman" "REFERENCE.md documents the /steelman transitive bump gate"
run_content_eval "$REFERENCE_MD" "strongest case.*dismiss|dismiss.*strongest case" "REFERENCE.md requires arguing strongest dismissal case before bump"
run_content_eval "$REFERENCE_MD" "/diagnose reachability loop|reachability loop.*\\/diagnose" "REFERENCE.md documents the available /diagnose reachability loop"
run_content_eval "$REFERENCE_MD" "real potential vulnerability" "REFERENCE.md requires real potential vulnerability proof"
run_content_eval "$REFERENCE_MD" "Package.json admission gate" "REFERENCE.md documents package.json admission gate"
run_content_eval "$REFERENCE_MD" "[Pp]roven not reachable.*dismiss|dismiss.*[Pp]roven not reachable" "REFERENCE.md dismisses only proven-not-reachable findings"
run_content_eval "$REFERENCE_MD" "[Uu]ncertain.*escalate|escalate.*[Uu]ncertain" "REFERENCE.md escalates uncertain findings"
run_content_eval "$REFERENCE_MD" "code smell|burn-down queue" "REFERENCE.md treats overrides/resolutions as burn-down debt"
run_content_eval "$REFERENCE_MD" "native/in-house|in-house code|dependency surface removal" "REFERENCE.md prefers lower dependency surface before overrides"

# ── Minimum release age gates ────────────────────────────────────

run_content_eval "$SKILL_MD" "minimum release age gate audit" "SKILL.md requires release age gate audit"
run_content_eval "$REFERENCE_MD" "Minimum release age gate audit" "REFERENCE.md documents release age gate audit"
run_content_eval "$REFERENCE_MD" "bunfig\\.toml.*minimumReleaseAge|minimumReleaseAge.*bunfig\\.toml" "REFERENCE.md covers Bun release gate config"
run_content_eval "$REFERENCE_MD" "\\.npmrc.*min-release-age|min-release-age.*\\.npmrc" "REFERENCE.md covers npm release gate config"
run_content_eval "$REFERENCE_MD" "pnpm-workspace\\.yaml.*minimumReleaseAge|minimumReleaseAge.*pnpm-workspace\\.yaml" "REFERENCE.md covers pnpm release gate config"
run_content_eval "$REFERENCE_MD" "\\.yarnrc\\.yml.*npmMinimalAgeGate|npmMinimalAgeGate.*\\.yarnrc\\.yml" "REFERENCE.md covers Yarn release gate config"
run_content_eval "$REFERENCE_MD" "WARN.*release age gate missing|release age gate missing.*WARN" "REFERENCE.md warns instead of silently passing when age gate absent"

# ── Socket.dev web-only supply-chain scan ────────────────────────

run_content_eval "$SKILL_MD" "Socket\\.dev web check|socket\\.dev web check" "SKILL.md wires Socket.dev web check"
run_content_eval "$REFERENCE_MD" "Socket\\.dev web check" "REFERENCE.md documents Socket.dev web check"
run_content_eval "$REFERENCE_MD" "https://socket\\.dev/npm/package" "REFERENCE.md uses Socket package web pages"
run_content_eval "$REFERENCE_MD" "no Socket CLI|no socket CLI|No Socket CLI" "REFERENCE.md makes Socket check web-only"
run_content_eval "$REFERENCE_MD" "install script|typosquat|unstable ownership|native code|shell access|environment variable access" "REFERENCE.md lists Socket attack vectors"

# ── Automatic internal skill gates ───────────────────────────────

run_content_eval "$SKILL_MD" "/resilience-review" "SKILL.md auto-runs resilience-review before PR"
run_content_eval "$SKILL_MD" "gh issue create" "SKILL.md creates tracking issues for security debt"
run_content_eval "$SKILL_MD" "/review" "SKILL.md auto-runs review before PR"
run_content_eval "$REFERENCE_MD" "Automatic internal skill gates" "REFERENCE.md documents automatic internal skill gates"
run_content_eval "$REFERENCE_MD" "resilience-review.*before PR|before PR.*resilience-review" "REFERENCE.md runs resilience-review before PR"
run_content_eval "$REFERENCE_MD" "gh issue create.*missing release age|missing release age.*gh issue create" "REFERENCE.md sends release gate debt to a tracking issue"
run_content_eval "$REFERENCE_MD" "review.*package\\.json admission gate|package\\.json admission gate.*review" "REFERENCE.md review checks admission gate"

if grep -qE '/(upgrade-dependency|to-tickets)|diagnosing-bugs|/github:gh-fix-ci|snyk-project-create-guard\.sh|SNYK_ALLOW_EXISTING_PROJECT_MONITOR|SNYK_EXISTING_PROJECT_ID|PreToolUse guard' "$SKILL_MD" "$REFERENCE_MD"; then
  echo "  FAIL  migrated Snyk docs reference unavailable ui-harness skills or hooks"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: migrated Snyk docs contain unavailable ui-harness references"
else
  echo "  PASS  migrated Snyk docs only reference available ui-harness skills and hooks"
  PASS=$((PASS + 1))
fi

# ── lockfile-sync-check.sh hook behavior ────────────────────────

run_content_eval "$LOCK_HOOK" "bun\.lock" "lockfile hook matches bun.lock"
run_content_eval "$LOCK_HOOK" "yarn\.lock" "lockfile hook matches yarn.lock"
run_content_eval "$LOCK_HOOK" "package\.json" "lockfile hook matches package.json"
run_content_eval "$LOCK_HOOK" "bun install --yarn" "lockfile hook suggests bun install --yarn"
run_content_eval "$LOCK_HOOK" "hook_parse_edit_write" "lockfile hook uses shared lib parser"
run_content_eval "$LOCK_HOOK" "hook_warn" "lockfile hook uses hook_warn (non-blocking)"
run_content_eval "$LOCK_HOOK" "git diff" "lockfile hook uses git diff for sync check"
run_content_eval "$LOCK_HOOK" "bun_changed|yarn_changed" "lockfile hook tracks per-lockfile change state"
run_content_eval "$LOCK_HOOK" "bun\.lockb" "lockfile hook warns on binary bun.lockb usage"

# Guardrail: SKILL must NOT rely on bun.lockb (binary).
# Allowed: mention inside explicit deprecation language ("never ... bun.lockb" or "no binary bun.lockb")
if grep -qE "bun\.lockb" "$SKILL_MD"; then
  if grep -qE "(never|no).{0,40}bun\.lockb|bun\.lockb.{0,40}(deprecat|never)" "$SKILL_MD"; then
    echo "  PASS  SKILL.md mentions bun.lockb only in deprecation context"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  SKILL.md references bun.lockb outside deprecation context"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: SKILL.md references bun.lockb"
  fi
else
  echo "  PASS  SKILL.md does not reference binary bun.lockb"
  PASS=$((PASS + 1))
fi

# Hook may mention bun.lockb only in the deprecation warning branch; assert it's in a warn context
if grep -A2 "bun.lockb" "$LOCK_HOOK" | grep -q "hook_warn"; then
  echo "  PASS  lockfile hook only mentions bun.lockb in deprecation warning"
  PASS=$((PASS + 1))
else
  echo "  FAIL  lockfile hook references bun.lockb outside deprecation warning"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: bun.lockb referenced as normal path in hook"
fi

# ── Hook wired in manifest ──────────────────────────────────────

run_content_eval "$MANIFEST" "lockfile-sync-check\.sh" "lockfile-sync-check.sh registered in skill-manifest.json"

# ── lockfile-sync-check.sh behavior (git-diff drift) ───────────

_lock_tmpdir=$(mktemp -d /tmp/snyk-lock-eval-XXXXXX)
cd "$_lock_tmpdir"
git init -q
git config user.email "eval@test"
git config user.name "eval"
echo '{"name":"x","version":"1.0.0"}' > package.json
echo '{"lockfileVersion":1,"packages":{}}' > bun.lock
printf '# yarn lockfile v1\n\n' > yarn.lock
git add -A && git commit -q -m "init"

# Modify bun.lock but not yarn.lock
echo '{"lockfileVersion":1,"packages":{"foo@1.0.0":{}}}' > bun.lock

# Invoke hook with Edit tool_input referencing bun.lock
hook_out=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_lock_tmpdir/bun.lock\"}}" \
  | "$LOCK_HOOK" 2>&1 || true)

cd "$REPO_ROOT"
if echo "$hook_out" | grep -qE "yarn.lock unchanged|bun install --yarn"; then
  echo "  PASS  lockfile hook nudges when bun.lock changes without yarn.lock"
  PASS=$((PASS + 1))
else
  echo "  FAIL  lockfile hook silent on drift (bun.lock changed, yarn.lock not)"
  echo "        output: $hook_out"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: lockfile hook silent on drift"
fi

# Inverse: modify yarn.lock but not bun.lock
cd "$_lock_tmpdir"
git checkout -q bun.lock
printf '# yarn lockfile v1\n\nfoo@1.0.0:\n  version "1.0.0"\n' > yarn.lock
hook_out2=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_lock_tmpdir/yarn.lock\"}}" \
  | "$LOCK_HOOK" 2>&1 || true)
cd "$REPO_ROOT"
if echo "$hook_out2" | grep -qE "bun.lock unchanged|Run: bun install"; then
  echo "  PASS  lockfile hook nudges when yarn.lock changes without bun.lock"
  PASS=$((PASS + 1))
else
  echo "  FAIL  lockfile hook silent on drift (yarn.lock changed, bun.lock not)"
  echo "        output: $hook_out2"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: lockfile hook silent on inverse drift"
fi

# bun.lockb path triggers deprecation warn (file must exist for parser to proceed)
cd "$_lock_tmpdir"
: > bun.lockb
cd "$REPO_ROOT"
hook_out3=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_lock_tmpdir/bun.lockb\"}}" \
  | "$LOCK_HOOK" 2>&1 || true)
if echo "$hook_out3" | grep -q "bun.lockb detected"; then
  echo "  PASS  lockfile hook warns on bun.lockb (binary, deprecated)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  lockfile hook does not warn on bun.lockb"
  echo "        output: $hook_out3"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: lockfile hook silent on bun.lockb"
fi

rm -rf "$_lock_tmpdir"

# ── react-peer-check.sh behavior ────────────────────────────────

_peer_tmpdir=$(mktemp -d /tmp/snyk-peer-eval-XXXXXX)
cat > "$_peer_tmpdir/bun" <<'EOF'
#!/bin/bash
echo "${PEER_RANGE:-}"
EOF
chmod +x "$_peer_tmpdir/bun"

peer_test() {
  local range="$1"
  local expected_exit="$2"
  local desc="$3"
  local actual_exit=0
  PEER_RANGE="$range" PATH="$_peer_tmpdir:$PATH" "$PEER_CHECK" somepkg 1.2.3 > /dev/null 2>&1 || actual_exit=$?
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "  PASS  $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $desc (expected exit $expected_exit, got $actual_exit)"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $desc"
  fi
}

peer_test "^18" 0 "peer check: ^18 -> exit 0"
peer_test "^18.0.0" 0 "peer check: ^18.0.0 -> exit 0"
peer_test "^17 || ^18" 0 "peer check: ^17 || ^18 -> exit 0"
peer_test "^18 || ^19" 0 "peer check: ^18 || ^19 -> exit 0"
peer_test "^19" 1 "peer check: ^19 -> exit 1"
peer_test ">=19" 1 "peer check: >=19 -> exit 1"
peer_test "" 0 "peer check: empty -> exit 0"
peer_test "*" 0 "peer check: wildcard * -> exit 0"
peer_test ">=17" 0 "peer check: >=17 -> exit 0"

rm -rf "$_peer_tmpdir"

# ── Exploitability triage (top-level-first, override-last rule) ─

run_content_eval "$SKILL_MD" "[Ee]xploitability|[Rr]eachable|[Nn]ot reachable|not-reachable" "SKILL.md triages exploitability before bumping"
run_content_eval "$SKILL_MD" "snyk ignore" "SKILL.md dismisses non-exploitable vulns via snyk ignore"
run_content_eval "$SKILL_MD" "--reason" "SKILL.md requires reason on snyk ignore dismissals"
run_content_eval "$SKILL_MD" "--expiry" "SKILL.md requires expiry on snyk ignore dismissals"
run_content_eval "$SKILL_MD" "\.snyk" "SKILL.md requires .snyk policy file committed with dismissals"
run_content_eval "$SKILL_MD" "[Pp]R[- ]description.*not enough|[Nn]ot an audit artifact|PR.*alone.*not enough|not just PR" "SKILL.md states PR-description text alone is insufficient"
REF_MD="$SKILL_DIR/REFERENCE.md"
run_content_eval "$REF_MD" "\.snyk" "REFERENCE.md documents .snyk policy file commit"
run_content_eval "$REF_MD" "snyk monitor" "REFERENCE.md pushes ignores to Snyk IO via monitor"
run_content_eval "$REF_MD" "[Ii]gnored" "REFERENCE.md verifies re-scan shows Ignored status"
run_content_eval "$SKILL_MD" "[Tt]op-level|direct dep" "SKILL.md prefers top-level direct dep bumps"
run_content_eval "$SKILL_MD" "[Ll]ast resort|last-resort" "SKILL.md treats overrides/resolutions as last resort"
run_content_eval "$SKILL_MD" "resolutions|overrides|replace" "SKILL.md acknowledges resolutions/overrides/replace mechanisms"
run_content_eval "$SKILL_MD" "[Bb]loat|scale poorly|do not scale|don.t scale" "SKILL.md explains why overrides do not scale"
run_content_eval "$REF_MD" "Dependency surface removal" "REFERENCE.md has dependency surface removal step"
run_content_eval "$REF_MD" "Lower third-party surface area" "REFERENCE.md names lower third-party surface as the durable win"

# REFERENCE.md must document the full upgrade-priority ladder
REF_MD="$SKILL_DIR/REFERENCE.md"
run_file_eval "$REF_MD" "REFERENCE.md exists"
run_content_eval "$REF_MD" "[Ee]xploitability triage" "REFERENCE.md documents exploitability triage"
run_content_eval "$REF_MD" "[Uu]pgrade priority" "REFERENCE.md documents upgrade priority ladder"
run_content_eval "$REF_MD" "bun why" "REFERENCE.md uses bun why for JS reachability"
run_content_eval "$REF_MD" "go mod why" "REFERENCE.md uses go mod why for Go reachability"

# ── Go ecosystem parity ─────────────────────────────────────────

run_content_eval "$SKILL_MD" "go\.mod" "SKILL.md handles Go go.mod paths"
run_content_eval "$SKILL_MD" "govulncheck" "SKILL.md runs govulncheck for Go"
run_content_eval "$SKILL_MD" "go get -u" "SKILL.md bumps Go modules via go get -u"
run_content_eval "$SKILL_MD" "go mod tidy" "SKILL.md syncs go.mod + go.sum via go mod tidy"
run_content_eval "$SKILL_MD" "go test" "SKILL.md runs go test for Go verify"
run_content_eval "$SKILL_MD" "go build" "SKILL.md runs go build for Go verify"
run_content_eval "$REF_MD" "snyk test --file=go\.mod" "REFERENCE.md runs snyk test --file=go.mod for Go"
run_content_eval "$REF_MD" "replace.{0,3}directive" "REFERENCE.md flags Go replace directive as last resort"
run_content_eval "$REF_MD" "go\.sum" "REFERENCE.md commits go.sum alongside go.mod"
run_content_eval "$REF_MD" "call graph|reachability" "REFERENCE.md leverages govulncheck reachability"

# ── Bazel Snyk parity ─────────────────────────────────────────

run_content_eval "$SKILL_MD" "single Snyk vulnerability|pasted Snyk|Snyk output" "SKILL.md accepts pasted single-vulnerability Snyk output"
run_content_eval "$SKILL_MD" "MODULE\.bazel" "SKILL.md checks MODULE.bazel for Bazel-managed deps"
run_content_eval "$SKILL_MD" "bazel/repositories\.bzl" "SKILL.md checks bazel/repositories.bzl for http_archive deps"
run_content_eval "$SKILL_MD" "bazel mod deps --lockfile_mode=update" "SKILL.md regenerates Bazel module lockfile"
run_content_eval "$SKILL_MD" "Backport|backport" "SKILL.md requires backport assessment for Bazel Snyk fixes"
run_content_eval "$REF_MD" "Bazel track|Bazel Snyk" "REFERENCE.md documents the Bazel Snyk track"
run_content_eval "$REF_MD" "ticket|FIXES=" "REFERENCE.md preserves ticket auto-linking for Bazel PRs"
run_content_eval "$REF_MD" "OpenSSL|FIPS|CMVP" "REFERENCE.md documents OpenSSL FIPS handling"
run_content_eval "$REF_MD" "artifact mirror|mirrored artifact|S3" "REFERENCE.md documents artifact mirror dependency flow"
run_content_eval "$REF_MD" "Never change.*mirrored.*github\.com|mirrored.*upstream.*ask" "REFERENCE.md forbids silently swapping mirrored artifact URLs to direct upstream hosts"
run_content_eval "$REF_MD" "draft PR|--draft" "REFERENCE.md opens Bazel Snyk PRs as draft"
run_content_eval "$REF_MD" "pull_request_template\.md|PR template" "REFERENCE.md uses the live target PR template"

# ── Existing .snyk revisit (cleanup stale ignores) ──────────────

run_content_eval "$SKILL_MD" "[Rr]evisit|re-triage" "SKILL.md revisits existing .snyk entries before new scan"
run_content_eval "$SKILL_MD" "snyk ignore --remove|--remove --id=" "SKILL.md removes stale ignores via snyk ignore --remove"
run_content_eval "$SKILL_MD" "[Cc]leaned up|clean up|accumulate" "SKILL.md prevents dismissal accumulation"
run_content_eval "$REF_MD" "Existing .snyk revisit|revisit.*every run|revisit.*before scan" "REFERENCE.md documents .snyk revisit procedure"
run_content_eval "$REF_MD" "snyk ignore --remove" "REFERENCE.md removes stale ignores"
run_content_eval "$REF_MD" "[Ee]xpiry passed|expir" "REFERENCE.md checks expiry on existing ignores"
run_content_eval "$REF_MD" "Dismissed .cleaned up." "REFERENCE.md PR template includes Dismissed (cleaned up) section"

# ── PR metadata: assignee = triggerer, reviewer = team group ───

run_content_eval "$SKILL_MD" "gh api user --jq \.login|triggerer|triggered the sweep" "SKILL.md sets assignee to the triggerer"
run_content_eval "$SKILL_MD" "team group|CODEOWNERS team|@.*/.*|reviewer group" "SKILL.md requires a team-group reviewer"
run_content_eval "$SKILL_MD" ">=1|at least one" "SKILL.md enforces at least one reviewer"
run_content_eval "$SKILL_MD" "[Ss]ecurity team.*automatically|security team.*added" "SKILL.md adds security team on dismissals/overrides"
run_content_eval "$SKILL_MD" "team/" "SKILL.md applies team-domain labels"
run_content_eval "$SKILL_MD" "dismissals|overrides-added|react19-blocked|cleaned-up" "SKILL.md applies status labels"
run_content_eval "$REF_MD" "gh api user --jq \.login" "REFERENCE.md resolves triggerer via gh api"
run_content_eval "$REF_MD" "team group|team-group|CODEOWNERS team" "REFERENCE.md requires team-group reviewers"
run_content_eval "$REF_MD" "only individual reviewers|lone individual|without a team" "REFERENCE.md rejects PRs with only individual reviewers"
run_content_eval "$REF_MD" "security team group|security.team.*automatically" "REFERENCE.md auto-adds security team on dismissals/overrides"

# ── Existing-project Snyk monitor (prevent project churn) ───────

run_content_eval "$SKILL_MD" "existing Snyk project|existing project|reuse existing" "SKILL.md reuses existing Snyk projects"
run_content_eval "$SKILL_MD" "Never create|Do not create|must not create" "SKILL.md forbids creating Snyk projects during audits"
run_content_eval "$SKILL_MD" "audit branch|sweep branch|YYYY-MM-DD|date-derived" "SKILL.md calls out audit/sweep branch project churn"
run_content_eval "$REF_MD" "snyk monitor.*creates a project|creates a project.*snyk monitor" "REFERENCE.md documents that snyk monitor is a create-capable write"
run_content_eval "$REF_MD" "/orgs/\\{org_id\\}/projects|List all Projects|org\\.project\\.read" "REFERENCE.md preflights existing projects via Snyk Projects API"
run_content_eval "$REF_MD" "target_reference|target_file|names_start_with" "REFERENCE.md matches existing projects by stable Snyk identity"
run_content_eval "$REF_MD" "skip.*monitor|do not run.*monitor|must not run.*monitor" "REFERENCE.md skips monitor when no existing project match is found"

org_arg_count=$(grep -c -- '--org=' "$REF_MD" || true)
canonical_org_arg_count=$(grep -c -- '--org="\$SNYK_ORG_ID"' "$REF_MD" || true)
if [ "$org_arg_count" -gt 0 ] && [ "$org_arg_count" -eq "$canonical_org_arg_count" ]; then
  echo "  PASS  Snyk preflight and monitor use one canonical org identity"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Snyk monitor org differs from the preflight org identity"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Snyk monitor and preflight use different org identities"
fi

if grep -qE 'target-reference="?\$branch|target-reference=<branch>|project-name=.*\$\{?repo.*branch|ref="\$\{repo_slug\}-\$\{branch\}"' "$SKILL_MD" "$REF_MD"; then
  echo "  FAIL  Snyk monitor must not use audit branch/date-derived project identity"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Snyk monitor uses audit branch/date-derived identity"
else
  echo "  PASS  Snyk monitor avoids audit branch/date-derived project identity"
  PASS=$((PASS + 1))
fi
