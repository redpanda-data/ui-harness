---
name: steelman
description: Argue strongest case against the user's assertion with evidence. Explicit anti-sycophancy guard. Use when user says "steelman", "/steelman", "give me pushback", "second opinion", "am I wrong", or for high-stakes/irreversible calls where wrong premise costs most.
---

# Steelman

Anti-sycophancy. LLMs agree by default. This skill forces opposite case.

## When invoked

User asserted something -- design, architecture, bug cause, "we should X", "Y won't work". Build strongest possible case *against* it before agreeing.

## Procedure

### Step 1: Identify claim

Restate user claim in one sentence. Flag type:
- **Factual** (verifiable: grep, docs, run) -> verify first
- **Causal** ("X breaks because Y") -> test the mechanism
- **Architectural** ("pattern Z won't scale") -> explore existing usage
- **Preference/goal/scope** -> decline steelman. Log `noise`. Return.

Preference/goal is user's call. No steelman.

### Step 2: Evidence gather

Fan out checks *before* arguing:
- Grep for named symbols / patterns
- Read referenced files
- Run tests/commands if cheap
- Consult docs/web for version/tooling claims

Do NOT argue from generics ("pattern smells"). Argue from repo evidence.

### Step 3: Steelman opposite

Write strongest counter-argument with specific references:
- What would have to be true for user to be wrong?
- What evidence in the repo supports wrong-case?
- What failure mode does user not consider?
- What precedent contradicts (git blame, prior commits, related files)?

Format: 2-4 bullet points. Each cites file:line or command output.

### Step 4: Verdict

Three outcomes:
- **Confirmed**: evidence supports user. Say so with refs. Proceed with user plan.
- **Contradicted**: evidence against user. Surface with refs. Let user decide (override or revise). Do NOT block.
- **Mixed**: partial confirm. Name which parts hold, which don't.

## When NOT to use

- User request is a goal / preference / scope call
- Trivial op (read file, list dir, format code)
- User already showed their work (grep output, test run in prompt)
- Implementation phases 3-6 unless security / data loss / irreversible

## Anti-pattern

Don't:
- Ask "are you sure?" -- verify silently, surface evidence only
- Play devil's advocate without refs -- grounded in repo only
- Block user. Surface, don't gate.
- Steelman every turn -- signal decays. Reserve for high-stakes + explicit invite.

[ETHOS: User fallible. Verify before act. Surface evidence, not doubt.]
