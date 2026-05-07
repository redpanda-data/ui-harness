# Toolchain Hook Scripts

## enforce-toolchain.sh

> Script: [`scripts/enforce-toolchain.sh`](scripts/enforce-toolchain.sh)

## session-env.sh

> Script: [`scripts/session-env.sh`](scripts/session-env.sh)

## Blocked Commands Quick Reference

| Attempted command | Blocked? | Suggested alternative |
|---|---|---|
| `npm install` | Yes | `bun install --yarn` |
| `npm run build` | Yes | `bun run build` |
| `npx some-tool` | Yes | `bunx some-tool` or `bun run <script>` |
| `tsc` | Yes | `tsgo` |
| `tsc --noEmit` | Yes | `tsgo --noEmit` |
| `bun add -g pkg` | Yes | `bun add -D pkg --yarn` |
| `bun install` | Yes | `bun install --yarn` |
| `bun add lodash` | Yes | `bun add lodash --yarn` |
| `bunx biome check` | Yes | `bun run lint` |
| `bunx ultracite fix` | Yes | `bun run lint:fix` |
| `eslint .` | Yes | `bun run lint` |
| `prettier --write .` | Yes | `bun run lint:fix` |
| `bunx eslint .` | Yes | `bun run lint` |
| `bunx prettier .` | Yes | `bun run lint:fix` |
| `bun add eslint` | Yes | Use Biome (already configured) |
| `bun add prettier` | Yes | Use Biome (already configured) |
| `rm -rf /` | Yes | Remove specific safe targets only |
| `rm -rf node_modules` | No | Allowed (safe target) |
| `rm -rf .next dist` | No | Allowed (safe targets) |
| `rm -rf .claude/skills` | No | Allowed (skill infra cleanup) |
| `rm -rf .claude/hooks` | No | Allowed (skill infra cleanup) |
| `rm -r skills-lock.json` | No | Allowed (skill infra cleanup) |
| `git rm -r .claude/skills` | No | Allowed (git rm version-controlled) |
| `rm -rf src` | Yes | Remove files individually |
| `git push --force` | Yes | `git push --force-with-lease` |
| `git push -f` | Yes | `git push --force-with-lease` |
| `git push --force-with-lease` | No | Allowed |
| `git reset --hard` | Yes | `git stash` or `git reset --soft` |
| `git checkout .` | Yes | `git checkout -- <file>` |
| `git restore .` | Yes | `git restore <file>` |
| `bun add --yarn lodash` | No | Allowed |
| `bun run build` | No | Allowed |
| `vitest` | No | Allowed |