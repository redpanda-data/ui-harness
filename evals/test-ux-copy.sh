# Public context-delivery protocol and plugin packaging, not tone evaluation.

run_file_eval "$REPO_ROOT/ux-copy/SKILL.md" "canonical UX copy skill is bundled"
run_file_eval "$REPO_ROOT/ux-copy/REFERENCE.md" "UX copy reference is bundled"
run_content_eval "$REPO_ROOT/ux-copy/REFERENCE.md" "Remove ambiguous readings" "latest copy guidance covers ambiguous scope"
run_content_eval "$REPO_ROOT/ux-copy/REFERENCE.md" "Task-screen heading" "latest copy guidance distinguishes task titles"
run_content_eval "$REPO_ROOT/ux-copy/REFERENCE.md" "Make grouped requirements explicit" "latest copy guidance preserves permission grouping"
run_content_eval "$REPO_ROOT/ux-copy/REFERENCE.md" "warnings before the action" "latest copy guidance puts warnings before actions"
run_content_eval "$REPO_ROOT/ux-copy/SKILL.md" ".upstream/ux-copy/SKILL.md" "host adapter loads the pinned upstream skill"
run_content_eval "$REPO_ROOT/ux-copy/SKILL.md" "Writing or review never installs" "host adapter preserves installation boundary"

if python3 - "$REPO_ROOT/ux-copy" <<'PY'
import hashlib
import json
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
manifest = json.loads((root / "upstream.json").read_text())
assert manifest["repository"] == "https://github.com/malinskibeniamin/skills"
assert re.fullmatch(r"[0-9a-f]{40}", manifest["revision"])
snapshot = root / ".upstream"
paths = {str(p.relative_to(snapshot)) for p in snapshot.rglob("*") if p.is_file() or p.is_symlink()}
assert paths == set(manifest["files"]), "snapshot file inventory drift"
for path, expected in manifest["files"].items():
    file = snapshot / path
    data = file.readlink().as_posix().encode() if file.is_symlink() else file.read_bytes()
    assert hashlib.sha256(data).hexdigest() == expected["sha256"], path
    assert file.is_symlink() == (expected["mode"] == "120000"), path
    if not file.is_symlink():
        assert bool(file.stat().st_mode & 0o111) == (expected["mode"] == "100755"), path
    assert file.resolve().is_relative_to(snapshot.resolve()), path
for path, target in {"REFERENCE.md": "ux-copy/REFERENCE.md", "GLOSSARY.md": "ux-copy/GLOSSARY.md", "evals": "ux-copy/evals"}.items():
    assert (root / path).is_symlink() and (root / path).resolve() == (snapshot / target).resolve(), path
cases = json.loads((root / "evals/cases.json").read_text())
assert {"task-title", "modifier-scope", "permission-grouping", "instruction-order"} <= {case["id"] for case in cases}
assert (snapshot / "LICENSE").is_file()
assert (snapshot / "ux-copy/scripts/_hook-lib.sh").resolve() == (snapshot / "shared/hook-lib.sh").resolve()
PY
then
  echo '  PASS  pinned upstream snapshot, links, modes, digests and clarity cases'; PASS=$((PASS + 1))
else
  echo '  FAIL  pinned upstream snapshot, links, modes, digests or clarity cases'; FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: UX copy upstream snapshot verification"
fi

for ux_plugin in .claude-plugin/plugin.json .codex-plugin/plugin.json; do
  if jq -e --argjson count "$(jq length "$REPO_ROOT/ux-copy/evals/cases.json")" \
    '.["x-changelog"][.version] | contains("\($count) tone cases")' "$REPO_ROOT/$ux_plugin" >/dev/null; then
    echo "  PASS  $ux_plugin advertises the bundled tone case count"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $ux_plugin has a stale tone case count"; FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: UX copy case count in $ux_plugin"
  fi
done

ux_context_case() {
  local path="$1" expected="$2" tool="${3:-Edit}" output="" status=0
  local hook="$REPO_ROOT/.claude/hooks/ux-copy-context.sh"
  if [ -x "$hook" ]; then
    output=$(jq -n --arg path "$path" --arg tool "$tool" \
      '{hook_event_name:"PreToolUse",tool_name:$tool,tool_input:{file_path:$path}}' | "$hook") || status=$?
  fi
  local valid=false
  if [ "$expected" = context ]; then
    if [ "$status" = 0 ] && printf '%s' "$output" | jq -e \
      --arg skill "$REPO_ROOT/ux-copy/SKILL.md" \
      --arg reference "$REPO_ROOT/ux-copy/REFERENCE.md" '
        .hookSpecificOutput.hookEventName == "PreToolUse"
        and (.hookSpecificOutput.additionalContext | contains($skill) and contains($reference)
          and contains("State one useful point per sentence") and contains("## Write") and contains("## Review"))
        and (.hookSpecificOutput.additionalContext | contains(".upstream/ux-copy/SKILL.md")
          and contains("Writing or review never installs"))
        and (has("decision") | not)
        and (.hookSpecificOutput | has("permissionDecision") | not)
      ' >/dev/null 2>&1; then valid=true; fi
  elif [ "$status" = 0 ] && [ -z "$output" ] && [ -x "$hook" ]; then valid=true
  fi
  if [ "$valid" = true ]; then
    echo "  PASS  $tool $path -> $expected"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $tool $path -> $expected"; FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: UX copy context for $tool $path"
  fi
}

ux_context_case src/Policy.tsx context
ux_context_case src/Policy.jsx context Read
ux_context_case src/copy.ts context Write
ux_context_case src/copy.js context
ux_context_case locales/en.json context
ux_context_case src/i18n/en.yaml context
ux_context_case translations/pl.po context
ux_context_case messages.en.json context
ux_context_case translations.json context
ux_context_case '/tmp/project with spaces/src/Policy.tsx' context
ux_context_case package.json silent
ux_context_case deploy/config.yaml silent
ux_context_case README.md silent
ux_context_case src/routeTree.gen.ts silent
ux_context_case src/types.d.ts silent
ux_context_case src/policy_pb.ts silent
ux_context_case node_modules/library/index.tsx silent
ux_context_case src/generated/Policy.tsx silent
ux_context_case src/Policy.tsx silent Bash

ux_generated=$(mktemp -d)
printf '// @generated\nexport const title = "Policies";\n' > "$ux_generated/Policy.tsx"
ux_context_case "$ux_generated/Policy.tsx" silent
rm -f "$ux_generated/Policy.tsx"; rmdir "$ux_generated"

if jq -e '.skills | index("./ux-copy/") != null' "$REPO_ROOT/.claude-plugin/plugin.json" >/dev/null; then
  echo "  PASS  Claude plugin exposes ux-copy"; PASS=$((PASS + 1))
else
  echo "  FAIL  Claude plugin does not expose ux-copy"; FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: ux-copy plugin registration"
fi

for ux_config in .claude/settings.json hooks/hooks.json .codex/hooks.json hooks/codex-hooks.json; do
  if jq -e '[.hooks.PreToolUse[] | select(.matcher == "Read|Edit|Write") | .hooks[]
    | select(((.args // []) | index("ux-copy-context.sh")) != null or ((.command // "") | contains("ux-copy-context.sh")))] | length == 1' \
    "$REPO_ROOT/$ux_config" >/dev/null; then
    echo "  PASS  $ux_config wires copy context"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $ux_config does not wire copy context"; FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: UX copy context wiring in $ux_config"
  fi
done

for ux_config in .claude/settings.json hooks/hooks.json .codex/hooks.json hooks/codex-hooks.json; do
  ux_command=$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Read|Edit|Write") | .hooks[0]
    | .command + (if .args then " " + (.args | join(" ")) else "" end)' "$REPO_ROOT/$ux_config")
  ux_output=$(printf '%s' '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"locales/en.json"}}' \
    | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash -c "$ux_command")
  if printf '%s' "$ux_output" | jq -e '.hookSpecificOutput.additionalContext | contains("one useful point")' >/dev/null; then
    echo "  PASS  $ux_config delivers context through its command"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $ux_config command does not deliver context"; FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: UX context command in $ux_config"
  fi
done

for ux_payload in '{}' 'not-json' '{"tool_name":"Edit","tool_input":{}}'; do
  ux_output=$(printf '%s' "$ux_payload" | "$REPO_ROOT/.claude/hooks/ux-copy-context.sh")
  if [ -z "$ux_output" ]; then
    echo '  PASS  missing or malformed input stays silent'; PASS=$((PASS + 1))
  else
    echo '  FAIL  invalid input emits context'; FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: invalid UX context input"
  fi
done
