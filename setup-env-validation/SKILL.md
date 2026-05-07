---
name: setup-env-validation
description: Enforce type-safe environment variable access using t3-env with zod validation. Bans raw process.env.X outside dedicated env files. Use when setting up env validation, t3-env, type-safe environment variables, or banning raw process.env access.
---

# Setup Env Validation

t3-env + zod for type-safe env vars. Single `src/env.ts` source of truth. PostToolUse hook block raw `process.env.` in TS/TSX/JS/JSX (skip env files + tests).

## Steps

### 1. Install
```bash
bun add @t3-oss/env-core zod
```

### 2. Create `src/env.ts`
```ts
import { createEnv } from "@t3-oss/env-core";
import { z } from "zod";

export const env = createEnv({
  server: {
    DATABASE_URL: z.string().url(),
    API_SECRET: z.string().min(1),
  },
  clientPrefix: "PUBLIC_",
  client: {
    PUBLIC_API_URL: z.string().url(),
  },
  runtimeEnv: process.env,
});
```

Use `import { env } from "@/env"` everywhere instead of `process.env`.

### 3. Hook
Copy `scripts/env-validation-check.sh` + `scripts/_hook-lib.sh` -> `.claude/hooks/`. `chmod +x`. Add to PostToolUse (Edit|Write).

### 4. Verify
- [ ] `import { env } from "@/env"` works
- [ ] Hook block `process.env.X` in regular files
- [ ] Hook allow `process.env` in env.ts/env.mts/env.mjs/env.js
- [ ] Hook skip test files