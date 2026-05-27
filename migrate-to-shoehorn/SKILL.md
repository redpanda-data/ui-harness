---
name: migrate-to-shoehorn
description: Migrate test casts from `as` to @total-typescript/shoehorn.
---

# Migrate to Shoehorn

Test code only. Never prod.

`@total-typescript/shoehorn` replaces test `as` casts with type-safe helpers for partial data.

## Install

```bash
bun add -d @total-typescript/shoehorn
```

## Patterns

`as Type` with partial object -> `fromPartial()`:

```ts
import { fromPartial } from "@total-typescript/shoehorn";
getUser(fromPartial({ body: { id: "123" } }));
```

Intentionally invalid data -> `fromPartial()` plus targeted override helper from package docs. Avoid `as unknown as`.

## Workflow

1. Limit to tests: `*.test.*`, `*.spec.*`, fixtures.
2. Find casts: `rg " as |as unknown as"`.
3. Replace one cluster at a time.
4. Run related tests + type check.
5. Keep production files untouched.
