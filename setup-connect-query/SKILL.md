---
name: setup-connect-query
description: Enforce ConnectRPC + Connect Query + Protobuf v2 patterns via PostToolUse hooks. Bans raw useQuery, empty invalidateQueries, $typeName literals. Use when setting up ConnectRPC, protobuf type safety, or data fetching enforcement.
paths:
  - "**/*_connectquery*"
  - "**/*_pb*"
  - "**/gen/**"
---

# Connect Query Enforcement

## What This Catches

- **Ban raw `useQuery`/`useMutation`** from `@tanstack/react-query` when file use ConnectRPC -- use Connect Query (exception: `useTransport`/`callUnaryMethod` pattern)
- **Ban `invalidateQueries()`** no args -- must specify query key
- **Warn on `axios`/`fetch()`** -- prefer ConnectRPC transport
- **Protobuf v2**: Ban `new Message()` -> use `create(Schema)`. Ban `PlainMessage`/`PartialMessage` -> use `MessageShape`/`MessageInitShape`. Ban manual `$typeName` literals.

Escape hatch: `// allow: direct-query [reason]`

Protobuf gotchas (Timestamp, Duration, Any, cache patterns): [REFERENCE.md](REFERENCE.md). Setup: [SETUP.md](SETUP.md).