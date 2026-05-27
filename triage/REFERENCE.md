# Triage Reference

## Triage Workflow (Specific Issue)

### Step 1: Gather Context

Before presenting anything:

- Read full issue: body, comments, labels/status, reporter, age
- Parse prior triage notes from previous sessions
- Explore the codebase using the project's domain glossary; respect ADRs in the area
- Read `.out-of-scope/*.md` -- check for matches with prior rejections

### Step 2: Present Recommendation

Tell the maintainer: category (`bug` / `enhancement`) + reasoning, state recommendation + reasoning. If matching a prior out-of-scope: "Similar to `.out-of-scope/<concept>.md` -- rejected before because X. Still feel the same?"

Wait for direction.

### Step 3: Bug Reproduction (bugs only)

Attempt reproduction before grilling:

- Follow the reporter's steps
- Explore relevant code paths
- Run tests / trace logic
- Report success / failure to maintainer
- Lack of detail -> strong signal for `needs-info`

For root-cause investigation + a TDD fix plan, see [TDD Fix Plan Mode](#tdd-fix-plan-mode).

### Step 4: Grilling Session (if needed)

Flesh out the issue to a complete spec. Use `/grill-me` for a fast grill, `/grill-with-docs` when domain language/ADRs matter.

### Step 5: Apply Outcome

| Outcome | Action |
|---|---|
| `ready-for-agent` | Post agent brief comment ([AGENT-BRIEF.md](./AGENT-BRIEF.md)) |
| `ready-for-human` | Post summary + why can't delegate |
| `needs-info` | Post triage notes + questions |
| `wontfix` (bug) | Comment explaining why -> close |
| `wontfix` (enhancement) | Write `.out-of-scope/<concept>.md` -> comment -> close |

---

## TDD Fix Plan Mode

Triggered when: a bug is investigated to root cause and the maintainer wants a `ready-for-agent` brief that the agent can implement test-first.

### 1. Capture

If the user opens with "users report X" / "investigate Y" / "file a ticket for Z", treat the conversation as the input. One question max if the symptom isn't clear.

### 2. Explore + Diagnose

Use `Agent(subagent_type=Explore)`: where (modules / behaviours), what (symptoms), why (root cause), related (interacting code).

### 3. Fix Approach

Minimal change (surgical > rewrite). Affected interfaces / contracts. Behaviours to verify -> tests.

### 4. TDD Fix Plan

Ordered RED -> GREEN cycles. Vertical slices (one test -> one fix). Describe behaviours, not implementation steps. Use durable language (module names, contracts, domain glossary terms) -- no file paths, no line numbers.

### 5. File the Ticket

Embed the TDD fix plan in the agent brief body. Use the issue / work item template appropriate to the tracker (see `tracker-github.md` or `tracker-jira.md`):

```markdown
## Problem
Observable symptoms.

## Root Cause Analysis
Why -- the underlying mechanism.

## TDD Fix Plan
1. RED: test [behaviour] -> GREEN: fix [root cause]
2. RED: test [edge case] -> GREEN: handle [condition]

## Acceptance Criteria
- [ ] Testable criterion 1
- [ ] Testable criterion 2
```

No file paths or line numbers -- the brief must survive refactors.

---

## Needs-Info Template

```markdown
## Triage Notes

**What we've established so far:**

- point 1
- point 2

**What we still need from you (@reporter):**

- specific question 1
- specific question 2
```

Capture everything resolved during grilling under "established so far" so the work isn't lost. Questions must be specific and actionable -- not "please provide more info".

## State Machine

| From | To | Trigger | Action |
|---|---|---|---|
| unlabeled | needs-triage | Skill | Present recommendation |
| unlabeled | ready-for-agent | Maintainer | Write agent brief, apply role |
| unlabeled | wontfix | Maintainer | Close (+ `.out-of-scope/` for enhancements) |
| needs-triage | needs-info | Maintainer | Post triage notes + questions |
| needs-triage | ready-for-agent | Maintainer | Grilling done -> agent brief |
| needs-triage | ready-for-human | Maintainer | Grilling done -> summary |
| needs-triage | wontfix | Maintainer | Close with comment |
| needs-info | needs-triage | Skill | Reporter replied -> re-evaluate |
