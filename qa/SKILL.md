---
name: qa
description: "Interactive QA session where user reports bugs conversationally and agent files GitHub issues. Explores codebase in background for context. Use when user wants to report bugs, do QA, file issues conversationally, or mentions 'QA session'."
---

# QA Session

User describe problems. You clarify, explore codebase for context, file GitHub issues using project domain language.

## AI Disclaimer

Every issue filed during QA **must** include at top of body:

```
> *This issue was filed by AI during a QA session.*
```

## Per Issue

### 1. Listen + Lightly Clarify

Max 2-3 short questions: expected vs actual, repro steps, consistent or intermittent. If clear -> move on. No over-interview.

### 2. Background Codebase Exploration

Kick off Agent(subagent_type=Explore, run_in_background=true) to understand area:
- Domain language (check CONTEXT.md if exists)
- What feature supposed do
- User-facing behavior boundary

Goal = write better issue. Issue itself NOT reference file paths or internals.

### 2b. Browser Capture (optional)

Bug visible in running app? Capture state via
`scripts/skills-browser.sh` (Vercel agent-browser wrapper). Use refs
not screenshots -- cheaper tokens, cookies preserved across runs.

    scripts/skills-browser.sh navigate <url>
    scripts/skills-browser.sh read          # returns @eN ref tree
    scripts/skills-browser.sh screenshot --out /tmp/qa.png

No use for test code -- Playwright test files keep using
`@playwright/test` directly. skills-browser for AI-visible browser
state (QA, /go phase 4 smoke, /design-review). [docs/rfc/browser-daemon.md]

### 3. Single Issue or Breakdown?

**Break down** when: fix spans independent areas, separable concerns, multiple distinct failure modes.

**Single issue** when: one behavior wrong in one place, symptoms share root cause.

### 4. File GitHub Issue(s)

`gh issue create`. No ask review -- file and share URL.

#### Single Issue

    ## What Happened
    [Actual behavior in plain language]

    ## What I Expected
    [Expected behavior]

    ## Steps to Reproduce
    1. [Concrete numbered steps]
    2. [Domain terms, not module names]

    ## Additional Context
    [Observations from exploration -- domain language, no file paths]

#### Breakdown (Multiple Issues)

Create in dependency order (blockers first) so real issue numbers available.

    ## Parent Issue
    #<parent> or "Reported during QA session"

    ## What's Wrong
    [This specific slice only]

    ## Steps to Reproduce
    1. [Steps for THIS issue]

    ## Blocked By
    - #<issue> or "None -- can start immediately"

**Rules**: Many thin issues > few thick. Mark blocking honest. Maximize parallelism.

#### All Issues

- No file paths or line numbers
- Project domain language (check CONTEXT.md)
- Describe behaviors, not code
- Repro steps mandatory
- Concise -- readable in 30 seconds

### 5. Continue

Print issue URLs. Ask: "Next issue, or done?" Each issue independent -- no batch.