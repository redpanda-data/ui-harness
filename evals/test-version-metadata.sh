#!/bin/bash
# Version metadata eval

EXPECTED_VERSION="4.11.1"
EXPECTED_DATE="2026-06-10"

json_get() {
  local file="$1"
  local expr="$2"
  python3 - "$file" "$expr" <<'PY'
import json, sys
file, expr = sys.argv[1], sys.argv[2]
data = json.load(open(file))
value = eval(expr, {}, {"data": data})
print(value)
PY
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local description="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS  $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $description (expected: $expected, got: $actual)"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $description"
  fi
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  if grep -qF -- "$pattern" "$file"; then
    echo "  PASS  $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $description (missing: $pattern)"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $description"
  fi
}

assert_eq "$(json_get skill-manifest.json 'data["version"]')" "$EXPECTED_VERSION" "skill manifest version is current"

for file in .claude-plugin/plugin.json .codex-plugin/plugin.json; do
  assert_eq "$(json_get "$file" 'data["version"]')" "$EXPECTED_VERSION" "$file version is current"
  assert_eq "$(json_get "$file" 'data["x-updatedAt"]')" "$EXPECTED_DATE" "$file updated date is current"
  assert_eq "$(json_get "$file" 'str("4.11.1" in data["x-changelog"]).lower()')" "true" "$file changelog includes current version"
done

for file in .claude-plugin/marketplace.json .agents/plugins/marketplace.json; do
  assert_eq "$(json_get "$file" 'data["plugins"][0]["version"]')" "$EXPECTED_VERSION" "$file plugin version is current"
  assert_eq "$(json_get "$file" 'data["plugins"][0]["x-updatedAt"]')" "$EXPECTED_DATE" "$file plugin updated date is current"
  assert_eq "$(json_get "$file" 'str("4.11.1" in data["plugins"][0]["x-changelog"]).lower()')" "true" "$file changelog includes current version"
done

assert_file_contains CHANGELOG.md "## 4.11.1" "changelog includes current release"
assert_file_contains README.md "--ref v4.11.1" "README pinned install uses current release tag"
