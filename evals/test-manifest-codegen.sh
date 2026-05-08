# Evals for skill-manifest.json → settings.json/hooks.json codegen.

MANIFEST="$REPO_ROOT/skill-manifest.json"
GENERATOR="$REPO_ROOT/scripts/generate-hook-configs.sh"
SETTINGS="$REPO_ROOT/.claude/settings.json"
PLUGIN_HOOKS="$REPO_ROOT/hooks/hooks.json"

# ── Source files exist ──────────────────────────────────────────
run_file_eval "$MANIFEST" "skill-manifest.json exists"
run_file_eval "$GENERATOR" "scripts/generate-hook-configs.sh exists"
run_executable_eval "$GENERATOR" "scripts/generate-hook-configs.sh is executable"

# ── Manifest is valid JSON ──────────────────────────────────────
if jq empty "$MANIFEST" 2>/dev/null; then
  echo "  PASS  skill-manifest.json is valid JSON"
  PASS=$((PASS + 1))
else
  echo "  FAIL  skill-manifest.json is invalid JSON"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: manifest not valid JSON"
fi

# ── Drift check: generated files must match manifest ────────────
if bash "$GENERATOR" --check >/dev/null 2>&1; then
  echo "  PASS  settings.json and hooks.json match manifest (no drift)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  DRIFT: settings.json or hooks.json out of sync with manifest — run scripts/generate-hook-configs.sh --apply"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: manifest drift detected"
fi

# ── Both configs reference same script set ──────────────────────
_settings_scripts=$(jq -r '.. | .command? // empty' "$SETTINGS" 2>/dev/null | grep -oE '[^/;" ]+\.sh' | sort -u)
_plugin_scripts=$(jq -r '.. | .command? // empty' "$PLUGIN_HOOKS" 2>/dev/null | grep -oE '[^/;" ]+\.sh' | sort -u)
if [ "$_settings_scripts" = "$_plugin_scripts" ]; then
  echo "  PASS  settings.json and hooks.json reference identical script set"
  PASS=$((PASS + 1))
else
  echo "  FAIL  settings.json and hooks.json diverge on scripts"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: script set mismatch"
fi

# ── Every manifest-referenced script exists on disk ─────────────
_missing=0
while IFS= read -r script; do
  [ -z "$script" ] && continue
  if [ ! -f "$REPO_ROOT/.claude/hooks/$script" ]; then
    _missing=$((_missing + 1))
  fi
done < <(jq -r '.hooks | .. | .[]? | select(type=="string")' "$MANIFEST" | grep -E '\.sh$' | sort -u)
if [ "$_missing" = "0" ]; then
  echo "  PASS  all manifest-referenced scripts exist on disk"
  PASS=$((PASS + 1))
else
  echo "  FAIL  $_missing manifest scripts missing from .claude/hooks/"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: $_missing missing scripts"
fi

# ── Hook inventory coverage: no silent hook scripts ──────────────
_all_hook_scripts=$(find "$REPO_ROOT/.claude/hooks" -maxdepth 1 -type f -name '*.sh' -exec basename {} \; | sort -u)
_manifest_scripts=$(jq -r '.hooks | .. | .[]? | select(type=="string")' "$MANIFEST" 2>/dev/null | grep -E '\.sh$' | sort -u)
_exempt_scripts=$(jq -r '((.supportScripts // []) + (.manualScripts // []) + (.codexOnlyHooks // []))[]?' "$MANIFEST" 2>/dev/null | sort -u)
_unaccounted=$(comm -23 <(printf '%s\n' "$_all_hook_scripts") <(printf '%s\n%s\n' "$_manifest_scripts" "$_exempt_scripts" | awk 'NF' | sort -u))
if [ -z "$_unaccounted" ]; then
  echo "  PASS  every .claude/hooks/*.sh script is configured or explicitly exempted"
  PASS=$((PASS + 1))
else
  echo "  FAIL  unaccounted hook scripts: $_unaccounted"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: unaccounted hook scripts"
fi

# ── Claude configs include every manifest lifecycle hook ─────────
_claude_scripts=$(jq -r '.. | .command? // empty' "$PLUGIN_HOOKS" 2>/dev/null | grep -oE '[^/;" ]+\.sh' | sort -u)
if [ "$_claude_scripts" = "$_manifest_scripts" ]; then
  echo "  PASS  Claude hook config references exactly the manifest lifecycle hooks"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Claude hook config does not match manifest lifecycle hook set"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Claude hook set mismatch"
fi

# ── Codex configs include supported manifest hooks + Codex adapters ─
CODEX_HOOKS="$REPO_ROOT/hooks/codex-hooks.json"
_codex_scripts=$(jq -r '.. | .command? // empty' "$CODEX_HOOKS" 2>/dev/null | grep -oE '[^/;" ]+\.sh' | sort -u)
_expected_codex_scripts=$(jq -r '
  def direct: ["SessionStart","PreToolUse","PostToolUse","UserPromptSubmit","Stop"];
  ([.hooks | to_entries[] | select(.key as $k | direct | index($k)) | .value | to_entries[] | .value[]]
   + [.hooks.PostToolUseFailure? // {} | to_entries[] | .value[]]
   + (.codexOnlyHooks // []))[]
' "$MANIFEST" 2>/dev/null | grep -E '\.sh$' | sort -u)
if [ "$_codex_scripts" = "$_expected_codex_scripts" ]; then
  echo "  PASS  Codex hook config references every supported manifest hook plus Codex adapters"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Codex hook config does not match supported manifest hook set"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Codex hook set mismatch"
fi

# ── Claude plugin registers every skill directory ────────────────
_all_skills=$(cd "$REPO_ROOT" && find . -path "./.git" -prune -o -name SKILL.md -print | sed 's#/SKILL.md$#/#' | sort -u)
_plugin_skills=$(jq -r '.skills[]?' "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null | sort -u)
if [ "$_all_skills" = "$_plugin_skills" ]; then
  echo "  PASS  .claude-plugin/plugin.json registers every SKILL.md directory"
  PASS=$((PASS + 1))
else
  echo "  FAIL  .claude-plugin/plugin.json skill list is incomplete or stale"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: plugin skill registry mismatch"
fi
