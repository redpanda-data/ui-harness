#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/_hook-lib.sh"

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated

# Check for escape hatch
if hook_has_escape "direct-query"; then
  exit 0
fi

hook_get_added_lines

# Read full file for context
file_content=$(cat "$file_path")

# Detect if file uses ConnectRPC/Protobuf
uses_connect=false
if echo "$file_content" | grep -qE "from\s+['\"](@connectrpc/|@buf/)"; then
  uses_connect=true
fi

# ── Check 1: Ban raw useQuery/useMutation from @tanstack/react-query ─

if [ "$uses_connect" = true ]; then
  uses_connect_transport=false
  if echo "$file_content" | grep -qE "from\s+['\"]@connectrpc/connect['\"]|from\s+['\"]@connectrpc/connect-web['\"]|callUnaryMethod|callServerStreamMethod|createGrpcWebTransport|createConnectTransport|useTransport"; then
    uses_connect_transport=true
  fi

  if [ "$uses_connect_transport" = false ]; then
    tanstack_imports=$(echo "$added_lines" | grep -E "from\s+['\"]@tanstack/react-query['\"]" || true)
    if [ -n "$tanstack_imports" ] && echo "$tanstack_imports" | grep -qE '\buseQuery\b[^C]|\buseQuery\b\s*[,}]|\buseMutation\b[^S]|\buseMutation\b\s*[,}]'; then
      hook_block "useQuery/useMutation → import from @connectrpc/connect-query, not @tanstack/react-query. Escape: // allow: direct-query [reason]"
    fi
  fi
fi

# ── Check 2: Ban invalidateQueries() with no args ────────────────────

if echo "$added_lines" | grep -qE 'invalidateQueries\(\s*\)'; then
  hook_block "No invalidateQueries() with empty args (invalidates ALL). Scope: queryKey: [rpcMethod.service.typeName]."
fi

# ── Check 3: Warn on axios imports ────────────────────────────────────

if echo "$added_lines" | grep -qE "from\s+['\"]axios['\"]|require\(['\"]axios['\"]\)"; then
  hook_warn "Prefer ConnectRPC transport over axios. Bypass protobuf type safety. Escape: // allow: direct-query [reason]"
fi

# ── Check 4: Warn on fetch() calls ───────────────────────────────────

if echo "$added_lines" | grep -qE '\bfetch\s*\('; then
  if [ "$uses_connect" = true ]; then
    hook_block "No raw fetch() in ConnectRPC files. Use ConnectRPC transport. Escape: // allow: direct-query [reason]"
  fi
fi

# ── Check 5: (v2) Ban new Message() construction ────────────────────

if echo "$added_lines" | grep -qE '\bnew\s+[A-Z][a-zA-Z]*(Request|Response|Message)\s*\('; then
  if echo "$file_content" | grep -qE "from\s+['\"]@buf/"; then
    hook_block "Proto v2: no new Message(). Use create(Schema, { ... }) from @bufbuild/protobuf."
  fi
fi

# ── Check 6: (v2) Ban PlainMessage/PartialMessage ───────────────────

if echo "$added_lines" | grep -qE '\b(PlainMessage|PartialMessage)\b'; then
  if echo "$file_content" | grep -qE "from\s+['\"]@bufbuild/protobuf['\"]"; then
    hook_block "Proto v2: PlainMessage/PartialMessage are v1. Use MessageShape<typeof Schema> or MessageInitShape<typeof Schema>."
  fi
fi

# ── Check 7: (v2) Ban manual $typeName literals ─────────────────────

if echo "$added_lines" | grep -qE '\$typeName'; then
  is_proto_v2=false
  if [ -f "package.json" ] && grep -qE '"@bufbuild/protobuf":\s*"[\^~]?2' package.json 2>/dev/null; then
    is_proto_v2=true
  fi

  if [ "$is_proto_v2" = true ]; then
    hook_block "Proto v2: no manual \$typeName. Use create(Schema, { ... }) for type-safe construction."
  fi
fi

# ── Check 8: Warn on toJson/fromJson of Any without typeRegistry ──────

if echo "$added_lines" | grep -qE 'toJson|fromJson'; then
  if echo "$file_content" | grep -qE 'google.protobuf.Any|AnySchema|anyPack|anyUnpack'; then
    if ! echo "$file_content" | grep -qE 'typeRegistry|type_registry|createRegistry'; then
      hook_warn "toJson/fromJson with Any requires typeRegistry. Pass { typeRegistry } or configure on transport."
    fi
  fi
fi

# ── Check 9: Warn on Any construction without @type/typeUrl ───────

if echo "$added_lines" | grep -qE 'AnySchema|google\.protobuf\.Any'; then
  if echo "$added_lines" | grep -qE 'create\(.*Any' && ! echo "$added_lines" | grep -qE 'typeUrl|type_url|@type|anyPack'; then
    hook_warn "Any without typeUrl → JSON fails. Use anyPack() or set typeUrl."
  fi
fi

# ── Check 10: Warn on Timestamp as plain object ──────────────────

if echo "$added_lines" | grep -qE '\bTimestamp\b' || echo "$file_content" | grep -qE 'timestamp_pb'; then
  if echo "$added_lines" | grep -qE '\{\s*seconds\s*:|nanos\s*:' && echo "$file_content" | grep -qE '\bTimestamp\b|timestamp_pb'; then
    hook_warn "No manual { seconds, nanos } for Timestamp. Use timestampFromDate(new Date()) from @bufbuild/protobuf/wkt."
  fi
  if echo "$added_lines" | grep -qE 'new Date\(\)' && echo "$added_lines" | grep -qE '\bTimestamp\b'; then
    if ! echo "$added_lines" | grep -qE 'timestampFromDate|timestampDate|Timestamp\.fromDate|toTimestamp'; then
      hook_warn "No raw Date to Timestamp field. Use timestampFromDate(date) from @bufbuild/protobuf/wkt."
    fi
  fi
fi

exit 0
