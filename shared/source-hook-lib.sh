#!/bin/bash
# Shim for Stop hooks to source hook-lib.sh reliably.
# Resolves the _hook-lib.sh vs hook-lib.sh naming difference between
# .claude/hooks/ (symlinks with underscore prefix) and shared/ (direct).
#
# Usage in Stop hooks:
#   source "$(dirname "$0")/source-hook-lib.sh" 2>/dev/null || true
#
# This file is safe to source under set -eo pipefail.

_shim_dir="$(dirname "${BASH_SOURCE[0]}")"

# Try underscore variant first (symlink convention in .claude/hooks/)
if [ -f "$_shim_dir/_hook-lib.sh" ]; then
  source "$_shim_dir/_hook-lib.sh"
elif [ -f "$_shim_dir/hook-lib.sh" ]; then
  source "$_shim_dir/hook-lib.sh"
else
  # Last resort: try repo-relative path
  _repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$_repo_root" ] && [ -f "$_repo_root/shared/hook-lib.sh" ]; then
    source "$_repo_root/shared/hook-lib.sh"
  fi
fi
