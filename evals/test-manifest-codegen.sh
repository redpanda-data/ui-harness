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
_settings_scripts=$(jq -r '.. | objects | ((.args? // [])[]?), (.command? // empty)' "$SETTINGS" 2>/dev/null | grep -oE '[a-z-]+\.sh' | grep -v '^run-hook\.sh$' | sort -u)
_plugin_scripts=$(jq -r '.. | .command? // empty' "$PLUGIN_HOOKS" 2>/dev/null | grep -oE '[a-z-]+\.sh' | sort -u)
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
