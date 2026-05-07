#!/bin/bash
set -eo pipefail
trap 'exit 0' ERR

# FileChanged matcher: package.json, bun.lockb
# Dependencies changed — remind about install, audit, lockfile consistency.

input=$(cat 2>/dev/null || echo '{}')
file=$(echo "$input" | jq -r '.filename // .file_path // empty' 2>/dev/null)
[ -n "$file" ] || exit 0

msg=""
run_audit=false
case "$file" in
  */package.json|package.json)
    msg="package.json changed. Run \`bun install\` to sync bun.lockb. If adding a dep, verify peer deps and run type:check."
    run_audit=true
    ;;
  */bun.lockb|bun.lockb)
    msg="bun.lockb changed. Dependency tree shifted."
    run_audit=true
    ;;
  */package-lock.json|package-lock.json)
    msg="package-lock.json detected in bun project — this is wrong. Delete it, keep bun.lockb only. (enforce-toolchain bans npm.)"
    ;;
esac

# Auto-audit on lockfile/manifest change. Prefer snyk, fall back to bun.
# Graceful skip if neither installed. npm tools are banned per toolchain.
if [ "$run_audit" = true ]; then
  audit_result=""
  if command -v snyk >/dev/null 2>&1; then
    audit_result=$(snyk test --severity-threshold=high --json 2>/dev/null \
      | jq -r '.vulnerabilities[]? | "\(.severity | ascii_upcase) \(.packageName)@\(.version): \(.title)"' 2>/dev/null | head -5 || true)
  elif command -v bun >/dev/null 2>&1; then
    audit_result=$(bun audit 2>/dev/null | grep -E '(HIGH|CRITICAL)' | head -5 || true)
  fi
  if [ -n "$audit_result" ]; then
    msg="$msg | vulns: $(printf '%s' "$audit_result" | tr '\n' ';' | head -c 300)"
  fi
fi

[ -n "$msg" ] || exit 0
echo "{\"suppressOutput\":true,\"systemMessage\":\"[deps] $msg\"}" >&2
exit 0
