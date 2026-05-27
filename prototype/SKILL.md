---
name: prototype
description: Build throwaway logic or UI prototypes to answer design questions fast.
---

# Prototype

Prototype = throwaway code answering one question.

## Pick branch

- Logic/state question -> [LOGIC.md](LOGIC.md): tiny terminal app, push state machine through hard cases.
- UI question -> [UI.md](UI.md): several variants on one route, switchable by URL/search param + floating controls.

If ambiguous and user absent: infer from code. Backend/module -> logic. Page/component -> UI. State assumption.

## Rules

1. Mark throwaway clearly. Keep near target code.
2. One command to run.
3. No persistence unless question needs it. Scratch DB/file only, clearly wipeable.
4. Skip polish: no tests, minimal errors, no abstractions.
5. Surface full relevant state after each action/switch.
6. When answered: delete or absorb into real code.

## Done

Capture answer + original question in commit msg, ADR, issue, or local notes. Prototype itself should not rot.
