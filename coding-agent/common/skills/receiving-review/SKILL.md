---
name: receiving-review
description: Use when receiving code review feedback - from the user, codex-reviewer, no-mistakes, or PR reviewers - before implementing any suggestion, especially if feedback seems unclear or questionable.
---

# Receiving Code Review

Core principle: verify before implementing. Technical correctness over social comfort.

## Response pattern

1. READ the complete feedback without reacting.
2. RESTATE the requirement in your own words, or ask.
3. VERIFY each claim against the actual code before touching anything.
4. EVALUATE whether it is right for this codebase specifically.
5. IMPLEMENT one item at a time, testing each.

## Never

- "You're absolutely right!" or any performative agreement.
- Implementing a suggestion before verifying its claim is true.
- Partial implementation while some items are unclear: clarify everything first, because items may be related.

## Push back when

The suggestion breaks existing functionality, the reviewer lacks context, it is technically wrong for this stack, or it adds capability nothing uses (YAGNI: grep for actual usage first).
Push back with evidence, not opinion.
If external feedback conflicts with a decision the user already made, stop and raise it with the user.

## Order

Blocking issues first (breakage, security), then simple fixes, then complex ones. Verify no regressions at the end.
