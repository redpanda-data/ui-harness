#!/bin/bash
set -euo pipefail

# Spawn a git worktree + feature branch + bound session atomically.
# Invoked by /development-lifecycle and /go when starting a new feature
# while on a default branch. User never invokes directly; Claude runs
# this helper as part of phase 1 (Understand).
#
# Usage:
#   scripts/mux-worktree.sh <branch-name> [base]
#
# Example:
#   scripts/mux-worktree.sh feat/oauth-login        # from HEAD
#   scripts/mux-worktree.sh fix/rate-limit main     # from main
#
# Modes:
#   --list           list active worktrees + bindings
#   --clean          prune merged worktrees with clean working tree
#
# Exit codes:
#   0 spawned OK (or listed)
#   1 validation / spawn failed
#   2 worktree exists at target path

case "${1:-}" in
  --list)
    git worktree list --porcelain 2>/dev/null | awk '
      /^worktree / { wt=$2 }
      /^branch / { br=$2; sub("refs/heads/", "", br) }
      /^$/ { if (wt) { hint = (system("[ -f \"" wt "/.claude/session-hint\" ]") == 0) ? "yes" : ""; printf "%-60s %-30s %s\n", wt, br, hint; wt=""; br=""; hint="" } }
      END { if (wt) { hint = (system("[ -f \"" wt "/.claude/session-hint\" ]") == 0) ? "yes" : ""; printf "%-60s %-30s %s\n", wt, br, hint } }
    '
    exit 0
    ;;
  --clean)
    default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo main)
    git worktree list --porcelain | awk -v def="$default" '
      /^worktree / { wt=$2 }
      /^branch / { br=$2; sub("refs/heads/", "", br) }
      /^$/ { if (wt && br != def) print wt "\t" br; wt=""; br="" }
    ' | while IFS=$'\t' read -r wt br; do
      if [ -z "$(git -C "$wt" status --porcelain 2>/dev/null)" ] \
        && git branch --merged "$default" 2>/dev/null | grep -qx "  $br"; then
        echo "prune candidate: $wt ($br merged, clean)"
        read -r -p "  remove? [y/N] " yn
        case "$yn" in
          y|Y) git worktree remove "$wt" ;;
        esac
      fi
    done
    exit 0
    ;;
esac

branch="${1:-}"
base="${2:-HEAD}"

if [ -z "$branch" ]; then
  echo "usage: scripts/mux-worktree.sh <branch> [base]" >&2
  echo "       scripts/mux-worktree.sh --list | --clean" >&2
  exit 1
fi

# Conventional-commits style validation — blocks path traversal.
if ! printf '%s' "$branch" | grep -qE '^(feat|fix|chore|docs|refactor|style|test|perf|ci|build|revert)/[a-z0-9][a-z0-9-]*$'; then
  echo "invalid branch name '$branch'. pattern: <type>/<kebab-case>" >&2
  echo "types: feat fix chore docs refactor style test perf ci build revert" >&2
  exit 1
fi

if ! git rev-parse --verify "$base" >/dev/null 2>&1; then
  echo "base '$base' does not exist" >&2
  exit 1
fi

repo=$(git rev-parse --show-toplevel)
name=$(basename "$repo")
safe=$(printf '%s' "$branch" | tr '/' '-')
path="$(dirname "$repo")/${name}-worktrees/${safe}"

if [ -e "$path" ]; then
  echo "worktree exists: $path" >&2
  echo "pick a new branch name or run: scripts/mux-worktree.sh --clean" >&2
  exit 2
fi

git worktree add -b "$branch" "$path" "$base" >/dev/null

mkdir -p "$path/.claude"
if [ -f "$repo/.claude/settings.local.json" ]; then
  cp "$repo/.claude/settings.local.json" "$path/.claude/settings.local.json"
fi

cat > "$path/.claude/session-hint" <<EOF
worktree=$path
branch=$branch
base=$base
spawned_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

printf 'spawned: %s at %s\n' "$branch" "$path"
printf 'cd %s && claude\n' "$path"
