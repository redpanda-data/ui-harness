# Project Rules

This project uses ConnectRPC + Connect Query for all API calls:
- When ConnectRPC is available, **NEVER use `useQuery`/`useMutation` from `@tanstack/react-query`** directly. Use Connect Query hooks instead.
- Exception: if using `useTransport`/`callUnaryMethod` from `@connectrpc/connect`, raw TanStack Query hooks are allowed.
- **NEVER call `invalidateQueries()` with no arguments.** Always specify a query key.
- **Prefer ConnectRPC transport over axios or fetch** for API calls.
- **Protobuf v2:** use `create(Schema, { ... })` for message construction. NEVER use `new Message()` or manual object literals with `$typeName`.
- **Protobuf v2:** use `MessageShape`/`MessageInitShape` — NEVER use `PlainMessage`/`PartialMessage`.
- Escape hatch: `// allow-direct-query: [reason]` for legitimate REST endpoints.
- Use bun with `--yarn` flag.

# Task

Create a React component at `src/TopicList.tsx` that:
1. Fetches a list of topics using Connect Query hooks (NOT raw useQuery from @tanstack/react-query)
2. Has a "Create Topic" button that uses a Connect Query mutation
3. After creating a topic, invalidates the topics list query using the service type name (NOT invalidateQueries() with no args)
4. Creates the topic request using `create(CreateTopicRequestSchema, { name: 'new-topic' })` pattern (NOT `new CreateTopicRequest()`)
5. Uses `MessageInitShape<typeof CreateTopicRequestSchema>` for the type (NOT `PartialMessage<CreateTopicRequest>`)
