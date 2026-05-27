# Connect Query Reference

## connect-query-check.sh

> Script: [`scripts/connect-query-check.sh`](scripts/connect-query-check.sh)

## Protobuf v1 Variant

`@bufbuild/protobuf` ^1.x: remove checks 5-6 (`new Message()` and `PlainMessage`/`PartialMessage`). Correct in v1.

## TanStack Query Hooks -- No False Positives

Hook use `\buseQuery\b` word boundaries. `useQueryClient` (stripped before match), `useQueries`, `useSuspenseQuery`, `useInfiniteQuery`, `useMutationState` safe. Not flagged.

## Cache Invalidation Patterns

### Invalidate by Connect Query Key

```tsx
import { createConnectQueryKey, useTransport } from '@connectrpc/connect-query'
import { TopicService } from './gen/topics_pb'

const transport = useTransport()

await queryClient.invalidateQueries({
  queryKey: createConnectQueryKey({
    schema: TopicService,
    transport,
    cardinality: 'finite',
  }),
  exact: false,
})
```

### Mutation with Invalidation

```tsx
import { createConnectQueryKey, useMutation, useTransport } from '@connectrpc/connect-query'
import { createTopic } from './gen/topics-TopicService_connectquery'
import { TopicService } from './gen/topics_pb'

function CreateTopicButton() {
  const queryClient = useQueryClient()
  const transport = useTransport()

  const mutation = useMutation(createTopic, {
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: createConnectQueryKey({
          schema: TopicService,
          transport,
          cardinality: 'finite',
        }),
        exact: false,
      })
    },
  })
}
```

## TanStack Query + useTransport/callUnaryMethod Pattern

With `useTransport`/`callUnaryMethod` from `@connectrpc/connect`, raw TanStack Query hooks OK:

```tsx
import { useTransport, callUnaryMethod } from '@connectrpc/connect'
import { useQuery } from '@tanstack/react-query'

function MyComponent() {
  const transport = useTransport()
  const { data } = useQuery({
    queryKey: ['some-service', 'method'],
    queryFn: () => callUnaryMethod(transport, SomeService.method, { id: '123' }),
  })
}
```

## Protobuf v2 Message Construction

```tsx
import { create, toBinary, fromBinary, fromJson, toJson } from '@bufbuild/protobuf'
import { MyMessageSchema } from './gen/my_pb'

const msg = create(MyMessageSchema, { field: 'value' })
const bytes = toBinary(MyMessageSchema, msg)
const restored = fromBinary(MyMessageSchema, bytes)
```

Never construct with `$typeName` literals. Use `create()`.

## Well-Known Types (Timestamp, Duration, Any)

### Timestamp

```ts
// BAD -- fails: "cannot decode Timestamp from JSON: object"
const msg = create(MySchema, {
  createdAt: { seconds: BigInt(Date.now() / 1000), nanos: 0 },
})

// BAD -- raw Date object, not a Timestamp
const msg = create(MySchema, { createdAt: new Date() })

// GOOD -- use @bufbuild/protobuf/wkt helpers
import { timestampFromDate, timestampDate } from '@bufbuild/protobuf/wkt'

const msg = create(MySchema, {
  createdAt: timestampFromDate(new Date()),
})

// Read back as Date
const date = timestampDate(msg.createdAt)
```

### Duration

```ts
import { durationFromJson } from '@bufbuild/protobuf/wkt'

const msg = create(MySchema, {
  timeout: durationFromJson('30s'),
})
```

### Any (with @type)

```ts
// BAD -- fails: "@type" is empty
const anyMsg = create(AnySchema, { value: toBinary(ConfigSchema, config) })

// GOOD -- use anyPack which sets @type automatically
import { anyPack, anyUnpack } from '@bufbuild/protobuf/wkt'

const anyMsg = anyPack(ConfigSchema, config)
const unpacked = anyUnpack(anyMsg, typeRegistry)
```

## ConnectError -> form.setError per field

`formatConnectError` / generic toast loses BadRequest.FieldViolation -- server-side validation feedback dies. Unpack in `onError`:

```tsx
import { ConnectError } from '@connectrpc/connect'
import { BadRequestSchema } from '@buf/googleapis_googleapis.bufbuild_es/google/rpc/error_details_pb'
import { toast } from 'sonner'

function useCreateLLMProvider(form: UseFormReturn<LLMProviderForm>) {
  return useMutation(createLLMProvider, {
    onError: (error) => {
      const ce = ConnectError.from(error)
      const [badRequest] = ce.findDetails(BadRequestSchema)
      const mappedFields: string[] = []

      badRequest?.fieldViolations.forEach((v) => {
        form.setError(v.field as keyof LLMProviderForm, {
          type: 'server',
          message: v.description,
        })
        mappedFields.push(v.field)
      })

      // Only toast when we couldn't map to a field -- otherwise the
      // inline FormMessage shows the server validation error.
      if (mappedFields.length === 0) {
        toast.error(formatToastErrorMessageGRPC(ce))
      }
    },
  })
}
```

Rules:
- `ConnectError.findDetails(BadRequestSchema)` -- never parse toast strings
- One `setError` per violation; use proto field name as key
- Toast only for non-field errors (auth, network, unmapped) -- otherwise duplicate signal
- Reset server errors on next submit (`form.clearErrors()` in onSubmit) -- stale server messages confuse users after edit