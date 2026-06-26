---
name: swarm
description: parallel executor. Use /swarm.
---

# Swarm

Repo/code changes: run `/deslop` before commit, push, PR, or merge.
Parallel executor: not planner, not `/goal`, not autopilot.

Use `/swarm <free-form goal>`. Infer lanes from the user's text. Do not ask for approval before launch unless required context is missing.

## Position

- `/goal` owns why and moving target.
- `/work` owns lifecycle.
- `/grill-with-docs` settles plan and docs.
- `/swarm` executes independent lanes faster.
- `/go` verifies and ships.

## Launch flow

1. Prime fast: inspect current repo state, rules, docs, branch, PR, and active goal when present. Use `/prime` style brief internally.
2. Choose workspace policy from text:
   - Default: same branch/worktree/PR.
   - If user asks separate, isolated, or per-agent worktrees: create one worktree/branch per lane.
   - If conflict risk is high: split or serialize writes; say why in manifest.
3. Draft a tiny swarm manifest, then launch immediately:
   ```txt
   Swarm manifest
   Policy: shared | worktrees | hybrid
   - swarm-<lane-name>: <mission> | scope: <paths> | skills: </skill...>
   ```
4. Spawn only distinct lanes. No duplicate or vague agents.
5. Coordinator keeps critical path local, merges results, resolves conflicting findings, verifies, and closes agents.

## Lane design

Every lane gets a Task packet:

```yaml
agent_name: swarm-<area>-<mission>
role: explorer | worker | reviewer | teacher
mission: one concrete outcome
skills: [/prime, /tdd, /review]
context: docs, decisions, branch or PR, relevant paths
workspace_policy: shared | worktree | hybrid
write_scope: exact paths or "report-only"
forbidden: duplicate lanes, unrelated files, commits, pushes unless asked
model_policy: inherit by default; override only when useful or user asks
output schema: status, summary, changed_files, tests_run, findings, blockers, next_action
```

Agents may read and write unless the packet says `report-only`. In shared policy, assign file ownership or serialize write-heavy lanes. In worktree policy, branch names should be descriptive and may follow `<owner>/<ticket>/<lane-desc>` when creating worktrees.

## Skill composition

- Worker lanes start with `/ponytail`; reviewer lanes include `/ponytail-review` before broader review.
- Architecture: fan out `/improve-codebase-architecture` by context, module, seam, or adapter.
- TDD: split coverage by independent behavior or public interface. RED before production edits; require RED->GREEN or failing-test evidence in result.
- Skill/harness work: assign eval ownership per lane. Each changed skill or hook needs matching evals in scope, owned by the lane or the coordinator.
- Design/copy work: split `/visual-review`, `setup-ux-copy`/copywriting, accessibility, and articulation lanes only when their write scopes do not overlap.
- Review: split standards, spec, resilience, security, performance, tests, UX, and steelman axes.
- Diagnose: split reproduction loops, hypotheses, instrumentation, and regression tests.
- Product: combine `/brainstorming`, `/prototype`, and `/steelman` lanes for options and pushback.
- Handoff: after grilling, create compact packets so each agent starts with current decisions.
- Learning: split topic by theory, examples, repo usage, trade-offs, and pitfalls.

## Merge protocol

- Read every result; do not trust summaries blindly for write lanes.
- Apply or keep changes intentionally; never accept overlapping edits blindly.
- Conflicting recommendations: show options, evidence, and coordinator recommendation.
- Run targeted checks after merge. For TDD lanes, require failing-test evidence before implementation evidence.
- Final output: manifest recap, landed changes, rejected/deferred work, tests, blockers, next action.

## Compatibility

Codex and Claude Code must work from prompts and artifacts, not hidden hooks. Use native subagents when available. If no subagent tool exists, emit Task packets as handoff files or commands for manual launch.
