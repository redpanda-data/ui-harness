# Evals for Claude/Codex marketplace naming and install docs.

CLAUDE_MARKETPLACE="$REPO_ROOT/.claude-plugin/marketplace.json"
CODEX_MARKETPLACE="$REPO_ROOT/.agents/plugins/marketplace.json"
README="$REPO_ROOT/README.md"
EXPECTED_MARKETPLACE="ui-harness"
EXPECTED_INSTALL="frontend-skills@ui-harness"
STALE_MARKETPLACE="skills"
LEGACY_INSTALL="frontend-skills@${STALE_MARKETPLACE}"
EXPECTED_CODEX_PATH="./plugins/frontend-skills"
CODEX_PLUGIN_LINK="$REPO_ROOT/plugins/frontend-skills"

# ── Marketplace name must match install selector ────────────────
_claude_name=$(jq -r '.name' "$CLAUDE_MARKETPLACE" 2>/dev/null)
if [ "$_claude_name" = "$EXPECTED_MARKETPLACE" ]; then
  echo "  PASS  Claude marketplace name matches install selector ($EXPECTED_MARKETPLACE)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Claude marketplace name is $_claude_name, expected $EXPECTED_MARKETPLACE"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Claude marketplace name mismatch"
fi

_codex_name=$(jq -r '.name' "$CODEX_MARKETPLACE" 2>/dev/null)
if [ "$_codex_name" = "$EXPECTED_MARKETPLACE" ]; then
  echo "  PASS  Codex marketplace name matches install selector ($EXPECTED_MARKETPLACE)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Codex marketplace name is $_codex_name, expected $EXPECTED_MARKETPLACE"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Codex marketplace name mismatch"
fi

# ── README install snippets should use the configured marketplace ─
if grep -qF -- "$EXPECTED_INSTALL" "$README"; then
  echo "  PASS  README documents $EXPECTED_INSTALL"
  PASS=$((PASS + 1))
else
  echo "  FAIL  README does not document $EXPECTED_INSTALL"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: README missing expected plugin install selector"
fi

if grep -qF -- "$LEGACY_INSTALL" "$README"; then
  echo "  FAIL  README still documents stale selector $LEGACY_INSTALL"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: README contains stale plugin install selector"
else
  echo "  PASS  README does not document stale selector $LEGACY_INSTALL"
  PASS=$((PASS + 1))
fi

# ── Codex marketplace source must point at a plugin directory ─────
_codex_path=$(jq -r '.plugins[] | select(.name == "frontend-skills") | .source.path' "$CODEX_MARKETPLACE" 2>/dev/null)
if [ "$_codex_path" = "$EXPECTED_CODEX_PATH" ]; then
  echo "  PASS  Codex marketplace source points at plugin symlink"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Codex marketplace source path is $_codex_path, expected $EXPECTED_CODEX_PATH"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Codex marketplace source path mismatch"
fi

if [ -L "$CODEX_PLUGIN_LINK" ] && [ "$(readlink "$CODEX_PLUGIN_LINK")" = ".." ]; then
  echo "  PASS  plugins/frontend-skills symlinks to repo root"
  PASS=$((PASS + 1))
else
  echo "  FAIL  plugins/frontend-skills must be a symlink to .."
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Codex plugin symlink missing"
fi

if [ -f "$CODEX_PLUGIN_LINK/.codex-plugin/plugin.json" ]; then
  echo "  PASS  Codex plugin symlink resolves plugin manifest"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Codex plugin symlink does not resolve .codex-plugin/plugin.json"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Codex plugin symlink does not resolve manifest"
fi

# ── Public docs/scripts must not point at the stale cache namespace ─
STALE_CACHE_PATH="cache/${STALE_MARKETPLACE}"
_stale_cache_refs=$(grep -R "$STALE_CACHE_PATH" "$REPO_ROOT/README.md" "$REPO_ROOT/scripts" "$REPO_ROOT/.claude-plugin" "$REPO_ROOT/.agents" "$REPO_ROOT/.codex-plugin" 2>/dev/null || true)
if [ -z "$_stale_cache_refs" ]; then
  echo "  PASS  docs and scripts do not reference stale cache namespace"
  PASS=$((PASS + 1))
else
  echo "  FAIL  stale cache namespace references remain"
  printf '%s\n' "$_stale_cache_refs" | sed 's/^/        /'
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: stale cache namespace references remain"
fi
