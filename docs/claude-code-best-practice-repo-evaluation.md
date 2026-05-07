# Claude Code Best Practice Repo Evaluation

**Date:** 2026-04-12
**Status:** Analysed -- no action needed, selective ideas noted
**Repository:** https://github.com/shanraisshan/claude-code-best-practice

## What Is It?

A reference encyclopedia by a Claude Community Ambassador cataloging Claude Code best practices, configuration options, and implementation patterns. Documents 68 slash commands, 170+ environment variables, 60+ settings, 16 subagent frontmatter fields, and 13 skill frontmatter fields. Includes implementation guides, reports on advanced features, and community workflow links.

- **Author:** shanraisshan (Claude Certified Architect)
- **Stars:** ~148K (as of 2026-04-12)
- **Last Updated:** 2026-04-11 (Claude Code v2.1.101)
- **Nature:** Documentation/reference -- not an enforcement engine

## Key Strengths

- **Comprehensive settings reference** -- documents the full configuration hierarchy (Managed > CLI args > settings.local.json > settings.json > ~/.claude/settings.json)
- **MCP server recommendations** -- Context7 for library docs, DeepWiki for repo docs, Playwright for browser testing
- **Advanced feature coverage** -- Programmatic Tool Calling, Dynamic Filtering, Tool Search optimization
- **Monorepo skill discovery** -- documents `SLASH_COMMAND_TOOL_CHAR_BUDGET` and skill loading behavior
- **Newer frontmatter fields** -- `paths` (auto-activation), `effort` (per-skill override), `shell`, `color`, `initialPrompt`

## Why No Action Needed

### Different goals: encyclopedia vs enforcement engine

Their repo documents what's possible. Ours makes things happen. We already exceed their practical implementation in every enforcement dimension.

| Dimension | Their repo | Our repo |
|---|---|---|
| Hooks | 1 unified Python handler | 44 targeted shell hooks, 8 fire points |
| Agents | Documentation only | 3 reviewers + structured JSON findings schema |
| Quality gates | Not implemented | P0-P3 severity, autofix routing, conditional dispatch |
| Testing | No eval suite | 27 eval scripts verifying each skill |
| Lifecycle | Described as best practice | Enforced via hooks + 6-phase workflow |
| Cross-tool | Claude Code only | Codex compatibility layer |

### Nothing structurally missing

Every major concept they document -- hooks, skills, subagents, memory, MCP, settings -- we already use. The gap is cosmetic features (spinner verbs, agent colors) or reference documentation we don't need to duplicate.

## Ideas Worth Noting (Low Priority)

| Idea | What | Priority | Notes |
|---|---|---|---|
| MCP: Context7 | Up-to-date library docs, prevents API hallucination | Medium | Useful for fast-moving deps (TanStack, protobuf-es). Add to `.mcp.json` if hallucination becomes a problem |
| MCP: DeepWiki | Structured GitHub repo documentation | Low | Useful for onboarding to unfamiliar repos |
| Auto-compact override | `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: "80"` | Medium | With 69+ hooks injecting messages, earlier compaction could prevent context blowout |
| `SLASH_COMMAND_TOOL_CHAR_BUDGET` | Controls skill description budget (default 15K chars) | Low | Worth checking if any of our 33 skills get truncated |
| `paths` frontmatter | Auto-activates skills when matching files are read | Low | Proactive context vs our reactive PostToolUse checks |
| `effort` frontmatter | Per-skill effort override | Low | adversarial-reviewer could use `effort: max` |
| Agent `memory` scopes | user/project/local memory for subagents | Low | Cross-session reviewer knowledge, not urgent |
| Agent `color` | Display color in task list | Trivial | Visual polish only |

## When to Revisit

- Context hallucination becomes a recurring problem -> adopt Context7 MCP
- Context window blowout observed -> tune `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`
- Skill count exceeds ~40 -> check `SLASH_COMMAND_TOOL_CHAR_BUDGET`
- Monorepo adoption -> review their monorepo skill discovery patterns
