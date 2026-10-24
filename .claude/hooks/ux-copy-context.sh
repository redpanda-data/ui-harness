#!/usr/bin/env bash
set -euo pipefail
exec "$(cd "$(dirname "$0")/../.." && pwd)/ux-copy/scripts/ux-copy-context.sh"
