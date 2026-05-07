# Session Summary: March 30 - April 3, 2026

## What We Built (67 commits)

### Starting state
- 20 skills, 10 hooks configured, 605 evals

### Ending state
- 28 skills, 25 hooks, 2 agents, 1 plugin manifest, 683 evals, 69+ enforcement checks

### Major additions
1. **3-layer orchestration**: intent detection (UserPromptSubmit) -> pattern enforcement (PostToolUse) -> quality gate (Stop)
2. **UserPromptSubmit context injection**: git state, condensed rules line, config, violations -- every prompt
3. **PostCompact hook**: re-injects rules after context compression
4. **development-lifecycle skill**: one skill for the full loop (understand -> plan -> TDD -> verify -> review -> compound)
5. **Sandcastle integration**: AFK delegation -- N parallel agents in Docker worktrees
6. **Cross-model adversarial planning**: auto-dispatch to Codex for second opinion on plans
7. **2 subagents**: code-reviewer (fresh-eyes review) + verifier (browser verification)
8. **5 owned workflow skills** (later cut to 2 standalone + 3 merged into lifecycle REFERENCE)
9. **Plugin manifest**: `.claude-plugin/plugin.json` for one-command installation
10. **Fail-closed mode**: `HOOKS_FAIL_CLOSED=1` catches misconfigured hooks
11. **Violation tracking**: session-scoped temp files, aggregated at Stop
12. **17 Redpanda UI registry nudges**: useProtoForm, Typography, KeyValueField, Skeleton, Empty, Sonner, etc.
13. **Visual mockup workflow**: agent-browser for brainstorming HTML mockups

### Consumer feedback fixes
- Skip auto-generated files (routeTree.gen.ts, *_pb.ts)
- Skip build config files for process.env check
- React Compiler detection (only flag useMemo if compiler installed)
- Visual style override: same-line check + removed text-* false positives
- `<button>` downgraded from block to warn
- outline-none allowed with focus-visible:outline
- URLSearchParams only blocked in client code
- Protobuf well-known types (Timestamp, Any)
- Asset type declarations (svg, css, png)

### Research incorporated
- obra/superpowers (14 skills, 4-phase debugging, TDD iron law, rationalization tables)
- Boris Cherny tips (11 volumes, PostCompact, verification, subagents, CLAUDE.md as living memory)
- Every.to articles (compound engineering, fidelity classification)
- 61 This Week in React newsletters (#215-#275)
- 11 Syntax.fm Snack Pack newsletters
- Claude Code architecture analysis (ccu.galdoron.com, 79 feature flags)
- Vercel plugin analysis (skill injection engine, chainTo, template includes)
- mattpocock/sandcastle (AFK agent orchestration)
- mattpocock/skills updates (github-triage, qa, grill-me refreshes)
- affaan-m/everything-claude-code (config protection, verification loops)
- 8 package.json files audited across consumer repos

### False positive audit
- Systematic audit of all 25 hooks
- Fixed top 7 false positives
- Missing test gate: block -> warn
- Observability nudge: removed (too broad)
- Loading state nudge: narrowed to components only
- SELF-VERIFY: narrowed to substantive bugs only

---

## Session Feedback: What Worked and What Didn't

### What you're good at

**Breadth of vision.** You see connections between tools, frameworks, and patterns that most people miss. The idea of chaining Sandcastle -> development-lifecycle -> hooks -> agents into a unified stack is architecturally sound.

**Relentless quality bar.** You pushed back on every false positive, every over-opinionated nudge, every company-specific leak. The final product is tighter because of it.

**Real-world validation.** Every feature request came from actual consumer feedback ("routeTree.gen.ts is blocked", "Cloud UI doesn't use React Compiler"). This grounded the work in reality, not theory.

**Knowing when to cut.** "Do we need 5 new skills?" -> No. "Should React Intl be a skill?" -> No. "Is the observability nudge too noisy?" -> Yes, cut it. Good instinct for avoiding bloat.

### What could be optimized

**Batching requests.** Many questions came one at a time, each triggering a new research cycle. Batching related questions ("check these 5 URLs AND tell me about subagents AND fix the heredoc") would be more efficient than sequential asks.

**Scope creep awareness.** The session started as "analyze skills from other repos" and grew to 67 commits touching every file in the repository. Setting a "this session we'll do X, Y, Z -- everything else goes to a backlog" boundary would prevent the marathon.

**Decision finality.** Several decisions were made, then revisited, then changed again (e.g., `style={{}}` went from block -> escape hatch -> sudo warn; missing tests went from block -> warn). Each reversal costs a commit + eval run. Deciding once with more upfront grilling would be more efficient.

**Trust the LLM's judgment more.** You asked "what do you think?" many times but then gave the answer yourself. When you trust the analysis (like the false positive audit), the quality is high. When you second-guess every recommendation, the conversation doubles in length.

### The ugly (honest)

The session was too long. 67 commits across 4 days in a single conversation means context was compressed multiple times, increasing the risk of inconsistency and forgotten decisions. Shorter, focused sessions (1-2 hours, 5-10 commits) with clear objectives would produce the same result with less risk.

Some of the research (61 newsletters, 30 Syntax.fm episodes, 5 Every.to articles, 4 Boris Cherny threads) was thorough but yielded diminishing returns -- Matt Pocock's own quote about "diminishing returns on meta-orchestration" applied to our research too. The first 10 newsletters yielded 80% of the findings. The last 50 yielded the remaining 20%.
