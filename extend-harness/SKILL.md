---
name: extend-harness
description: Extend frontend-skills hook harness. Add new rules via skill-manifest.json, pick severity tier (block/warn/nudge/info/block-strict/diagnostic), view analytics via /frontend-skills-stats. Use when adding enforcement, tuning rule severity, or debugging hook that isn't firing.
---

# Extend the Harness

## 1. Never hand-edit generated configs

`.claude/settings.json` and `hooks/hooks.json` generated. Edit `skill-manifest.json`, regenerate:

```bash
bash scripts/generate-hook-configs.sh --apply
bash scripts/generate-hook-configs.sh --check   # drift check (lefthook runs this pre-push)
```

## 2. Add a new rule (grep-expressible)

1. Write `my-check.sh` in `.claude/hooks/` -- start from any existing `*-check.sh` as template.
2. Add filename to matcher block in `skill-manifest.json` (usually `PostToolUse.Edit|Write`).
3. Regenerate: `bash scripts/generate-hook-configs.sh --apply`.
4. Test: feed synthetic edit event on stdin:

```bash
echo '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/tmp/x.ts"}}' | bash .claude/hooks/my-check.sh
```

## 3. Pick the right severity tier

| Function | Exit | Claude sees | Logged | Use when |
|---|---|---|---|---|
| `hook_block` | 2 | systemMessage | JSONL | Must fix before continuing |
| `hook_block_strict` | 2 | `[STRICT]` prefix | JSONL | Security-critical, no escape hatch |
| `hook_warn` | 0 | systemMessage | JSONL | Should fix, but proceed |
| `hook_nudge` | 0 | `[nudge]` prefix | JSONL | Pattern suboptimal most cases |
| `hook_info` | 0 | -- | JSONL | Telemetry only, no UI |
| `hook_emit_diagnostic` | 0 or 2 | LSP JSON with `range` + `fix` | JSONL | Machine-parseable with auto-fix |

Default `hook_warn` for style, `hook_block` for correctness, `hook_info` for observation.

## 4. When grep isn't enough

Grep can't express nested interactives, exhaustive switches, or useState-object-ref leaks reliably. AST-level patterns: handle in code review for now, or file issue for future Biome custom-rule integration. Don't fake with fragile multi-line regex -- too many false positives.

## 5. View analytics

```
/frontend-skills-stats
```

Reports per-hook P50/P95 latency, blocks/warns/nudges/infos per rule, zero-fire candidates (prune), over-aggressive hooks (soften). Needs >=5 session summaries in `~/.claude/hook-metrics/`.

## 6. Debug a hook that isn't firing

```bash
HOOK_DEBUG=1 HOOKS_FAIL_CLOSED=1 claude
```

Then: `tail -f /tmp/hook-session-*/debug.log`. Fail-closed turns crash-into-silent-exit into crash-into-visible-block.

## 7. Verification checklist

- [ ] `skill-manifest.json` lists script under correct event+matcher
- [ ] `bash scripts/generate-hook-configs.sh --check` exits 0
- [ ] Script executable (`chmod +x`)
- [ ] Sources `_hook-lib.sh`, parses input, filters extension, handles escape hatch
- [ ] Test fixture added to `evals/` if non-trivial
- [ ] `bash evals/run.sh` passes