#!/bin/bash
set -eo pipefail
trap 'exit 0' ERR

# PostToolUse Edit|Write: ensure bun.lock and yarn.lock stay in sync.
# Snyk IO does not natively parse bun.lock -- yarn.lock required for scans.
#
# Sync detection (two signals, any one triggers warn):
#   1. git diff: one lockfile modified/staged without the other in same diff
#   2. package presence: a package added/bumped in bun.lock must also appear
#      at the same version in yarn.lock (and vice versa)
#
# Regen: `bun install && bun install --yarn`
#
# bun.lock is TEXT (bun >= 1.2). Never use binary bun.lockb.

source "$(dirname "$0")/../../shared/hook-lib.sh"
hook_parse_edit_write

case "$file_path" in
  *package.json|*bun.lock|*yarn.lock) ;;
  *bun.lockb)
    hook_warn "bun.lockb detected -- use text bun.lock (bun >= 1.2). Delete bun.lockb, run: bun install"
    ;;
  *) exit 0 ;;
esac

# Find repo root (nearest ancestor with package.json)
repo_dir=$(dirname "$file_path")
while [ "$repo_dir" != "/" ] && [ ! -f "$repo_dir/package.json" ]; do
  repo_dir=$(dirname "$repo_dir")
done
[ -f "$repo_dir/package.json" ] || exit 0

bun_lock="$repo_dir/bun.lock"
yarn_lock="$repo_dir/yarn.lock"

# Only enforce when BOTH lockfiles exist (dual-lock setup opted in)
[ -f "$bun_lock" ] && [ -f "$yarn_lock" ] || exit 0

cd "$repo_dir" || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# ── Signal 1: git diff parity ──────────────────────────────────
# Check both staged and unstaged changes. If one lockfile appears but not the
# other in current diff, nudge.
bun_changed=false
yarn_changed=false
if git diff --name-only HEAD -- bun.lock 2>/dev/null | grep -q .; then bun_changed=true; fi
if git diff --name-only HEAD -- yarn.lock 2>/dev/null | grep -q .; then yarn_changed=true; fi

if [ "$bun_changed" = true ] && [ "$yarn_changed" = false ]; then
  hook_warn "bun.lock modified but yarn.lock unchanged. Snyk IO scans yarn.lock. Run: bun install --yarn"
fi
if [ "$yarn_changed" = true ] && [ "$bun_changed" = false ]; then
  hook_warn "yarn.lock modified but bun.lock unchanged. Run: bun install"
fi

# ── Signal 2: package presence parity ──────────────────────────
# Extract package names added in HEAD diff of bun.lock, assert each appears in yarn.lock.
# bun.lock is JSONC-ish; yarn.lock is custom. Grep package names both sides as heuristic.
if [ "$bun_changed" = true ] && [ "$yarn_changed" = true ]; then
  added_pkgs=$(git diff HEAD -- bun.lock 2>/dev/null \
    | grep -E '^\+' \
    | grep -oE '"[^"]+@[0-9]+\.[0-9]+\.[0-9]+' \
    | sed 's/^"//' \
    | sort -u \
    | head -20)

  missing=""
  while IFS= read -r pkg_ver; do
    [ -z "$pkg_ver" ] && continue
    pkg=${pkg_ver%@*}
    ver=${pkg_ver##*@}
    # yarn.lock format: `pkg@ver:` header, or `version "ver"` line under pkg header
    if ! grep -qE "(^\"?${pkg}@|^\s+version \"${ver}\")" yarn.lock 2>/dev/null; then
      missing="${missing}${pkg}@${ver} "
    fi
  done <<< "$added_pkgs"

  if [ -n "$missing" ]; then
    hook_warn "bun.lock has packages missing from yarn.lock: ${missing}-- regen: bun install --yarn"
  fi
fi

exit 0
