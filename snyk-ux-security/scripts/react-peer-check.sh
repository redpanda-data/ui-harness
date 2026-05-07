#!/usr/bin/env bash
# Check if <pkg>@<version> peerDependencies.react allows React 18.
# Exit 0 = compatible, 1 = React 19 required (skip), 2 = lookup failed.
set -euo pipefail

pkg="${1:?pkg required}"
ver="${2:?version required}"

peer=$(bun info "${pkg}@${ver}" peerDependencies.react 2>/dev/null || echo "")

[ -z "$peer" ] && { echo "no-peer"; exit 0; }

# Accept ranges that include 18: ^17||^18, ^18, ^18||^19, >=18, *
case "$peer" in
  *18*) exit 0 ;;
  *\>=17*|*\>=16*|\*) exit 0 ;;
  *19*|*\>=19*) echo "react19-required: $peer"; exit 1 ;;
  *) echo "unknown-range: $peer"; exit 2 ;;
esac
