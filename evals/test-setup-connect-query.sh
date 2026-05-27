# Evals for setup-connect-query skill

SCRIPT="$REPO_ROOT/setup-connect-query/scripts/connect-query-check.sh"
SKILL_DIR="$REPO_ROOT/setup-connect-query"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "REFERENCE.md exists"
run_executable_eval "$SCRIPT" "connect-query-check.sh is executable"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-connect-query" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "ConnectRPC" "SKILL.md mentions ConnectRPC"
run_content_eval "$SKILL_DIR/SKILL.md" "allow.*direct-query" "SKILL.md mentions escape hatch"

# ── Hook: skip non-Edit/Write tools ────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}' \
  0 "skip: Bash tool"

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Read","tool_input":{"file_path":"foo.tsx"}}' \
  0 "skip: Read tool"

# ── Hook: skip non-JS/TS files ─────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.go"}}' \
  0 "skip: .go file"

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.css"}}' \
  0 "skip: .css file"

# ── Hook: skip nonexistent file ──────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/nonexistent-cq-abc123.tsx"}}' \
  0 "skip: nonexistent file"

# ── Hook: skip empty file_path ───────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":""}}' \
  0 "skip: empty file_path"

# ── Hook: respect escape hatch ───────────────────────────────────

_cq_tmpdir=$(mktemp -d /tmp/cq-evals-XXXXXX)
tmpfile="$_cq_tmpdir/test.tsx"
printf "// allow: direct-query REST endpoint for legacy auth\nimport { useQuery } from '@tanstack/react-query'\nimport { listUsers } from './gen/users-UserService_connectquery'\n" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "skip: file with allow-direct-query escape hatch"

# tmpfile reused in tmpdir

# ── Check 1: Ban raw useQuery from @tanstack/react-query with ConnectRPC ─

tmpfile="$_cq_tmpdir/test.tsx"
printf "import { useQuery } from '@tanstack/react-query'\nimport { useQuery as useConnectQuery } from '@connectrpc/connect-query'\nimport { listTopics } from './gen/topics-TopicService_connectquery'\n" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: useQuery from @tanstack/react-query with ConnectRPC" "connect-query"

# tmpfile reused in tmpdir

# ── Check 1: Allow raw useQuery without ConnectRPC (REST) ────────

tmpfile="$_cq_tmpdir/test.tsx"
printf "import { useQuery } from '@tanstack/react-query'\nconst { data } = useQuery({ queryKey: ['users'], queryFn: fetchUsers })\n" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: useQuery from @tanstack/react-query without ConnectRPC"

# tmpfile reused in tmpdir

# ── Check 1: Ban raw useMutation with ConnectRPC ─────────────────

tmpfile="$_cq_tmpdir/test.tsx"
printf "import { useMutation } from '@tanstack/react-query'\nimport { useMutation as useConnectMutation } from '@connectrpc/connect-query'\nimport { createTopic } from './gen/topics-TopicService_connectquery'\n" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: useMutation from @tanstack/react-query with ConnectRPC"

# tmpfile reused in tmpdir

# ── Check 1: Allow current Connect Query hook syntax ─────────────

tmpfile="$_cq_tmpdir/test.tsx"
printf "import { useQuery, useMutation } from '@connectrpc/connect-query'\nimport { listTopics, createTopic } from './gen/topics-TopicService_connectquery'\nconst topics = useQuery(listTopics, { pageSize: 20 }, { staleTime: 30_000 })\nconst createTopicMutation = useMutation(createTopic, { onSuccess: () => queryClient.invalidateQueries({ queryKey: ['topics'] }) })\n" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: current Connect Query useQuery/useMutation syntax"

# tmpfile reused in tmpdir

# ── Check 2: Ban invalidateQueries() with no args ────────────────

tmpfile="$_cq_tmpdir/test.ts"
printf "await queryClient.invalidateQueries()\n" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: invalidateQueries() with no args" "invalidates ALL"

# tmpfile reused in tmpdir

# ── Check 2: Allow invalidateQueries with args ───────────────────

tmpfile="$_cq_tmpdir/test.ts"
printf "import { createConnectQueryKey, useTransport } from '@connectrpc/connect-query'\nimport { TopicService } from './gen/topics_pb'\nconst transport = useTransport()\nawait queryClient.invalidateQueries({ queryKey: createConnectQueryKey({ schema: TopicService, transport, cardinality: 'finite' }), exact: false })\n" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: invalidateQueries with queryKey"

# tmpfile reused in tmpdir

# ── Check 3: Warn on axios imports ───────────────────────────────

tmpfile="$_cq_tmpdir/test.ts"
printf "import axios from 'axios'\n" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: axios import (exit 0, not block)" "ConnectRPC transport"

# tmpfile reused in tmpdir

# ── Check 5: (v2) Ban new Message() construction ─────────────────

tmpfile="$_cq_tmpdir/test.ts"
printf "import { ListTopicsRequest } from '@buf/redpandadata_cloud.bufbuild_es'\nconst req = new ListTopicsRequest({ filter: 'active' })\n" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: new Message() construction (v2)" "create(Schema"

# tmpfile reused in tmpdir

# ── Check 6: (v2) Ban PlainMessage ───────────────────────────────

tmpfile="$_cq_tmpdir/test.ts"
printf "import { PlainMessage } from '@bufbuild/protobuf'\ntype Req = PlainMessage<ListTopicsRequest>\n" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: PlainMessage (v2)" "MessageShape"

# tmpfile reused in tmpdir

# ── Hook script content ──────────────────────────────────────────

run_content_eval "$SCRIPT" "connectrpc" "hook checks for ConnectRPC imports"
run_content_eval "$SCRIPT" "invalidateQueries" "hook checks for invalidateQueries"
run_content_eval "$SCRIPT" "axios" "hook checks for axios"
run_content_eval "$SCRIPT" "PlainMessage" "hook checks for PlainMessage"
run_content_eval "$SCRIPT" "hook_block|hook_warn" "hook uses shared output functions"
run_content_eval "$SCRIPT" "hook_has_escape" "hook respects escape hatch"
run_content_eval "$SCRIPT" "typeName" "hook checks for \$typeName object literals"
run_content_eval "$SCRIPT" "uses_connect_transport" "hook allows useTransport/callUnaryMethod pattern"
run_content_eval "$SCRIPT" "@connectrpc/connect-query" "hook messages point to Connect Query runtime"

# ── REFERENCE content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/REFERENCE.md" "useTransport" "REFERENCE documents useTransport pattern"
run_content_eval "$SKILL_DIR/REFERENCE.md" "toBinary" "REFERENCE documents schema-first serialization"
run_content_eval "$SKILL_DIR/REFERENCE.md" "timestampFromDate" "REFERENCE documents Timestamp gotcha"

# ── SETUP.md content (one-time setup) ───────────────────────────

run_content_eval "$SKILL_DIR/SETUP.md" "protovalidate" "SETUP documents Standard Schema + protovalidate"
run_content_eval "$SKILL_DIR/SETUP.md" "createRegistry" "SETUP documents type registry"
run_content_eval "$SKILL_DIR/SETUP.md" "TransportProvider" "SETUP documents transport setup"

# ── Check 1: Allow useQuery with @connectrpc/connect (useTransport pattern) ─

tmpfile="$_cq_tmpdir/test.tsx"
printf "import { useTransport, callUnaryMethod } from '@connectrpc/connect'\nimport { useQuery } from '@tanstack/react-query'\nimport { SomeService } from '@buf/gen'\n" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: useQuery with @connectrpc/connect import (useTransport pattern)"

# ── Check 7: (v2) Ban $typeName object literals ─────────────────

tmpfile="$_cq_tmpdir/test.ts"
# Create a fake package.json with protobuf v2 for detection
mkdir -p "$_cq_tmpdir"
echo '{"dependencies":{"@bufbuild/protobuf":"^2.0.0"}}' > "$_cq_tmpdir/package.json"
printf "const msg = { \\\$typeName: 'foo.Bar', field: 'value' }\n" > "$tmpfile"

# Run from the tmpdir so package.json is found
cd "$_cq_tmpdir"
run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: manual \$typeName object literal (v2)" "create(Schema"
cd "$REPO_ROOT"

rm -rf "$_cq_tmpdir"
