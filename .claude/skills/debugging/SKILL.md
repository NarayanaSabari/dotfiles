---
name: debugging
description: Use when hitting any bug, test failure, build failure, or unexpected behavior, before proposing fixes - especially under time pressure, or when a previous fix did not work.
---

# Systematic Debugging

Core principle: no fixes without root cause investigation first. Symptom fixes are failure.

## Phases (complete in order)

1. **Investigate.** Reproduce the bug end to end, as closely as possible to how a real user hits it.
   Read the complete error and stack trace; they often contain the answer.
   Check what changed recently (git diff, recent commits, config).
   In multi-component systems, instrument each boundary (log what enters and exits) and find WHERE it breaks before asking why.
2. **Analyze.** Find similar working code in the same codebase.
   List every difference between working and broken, however small. Do not assume "that can't matter".
3. **Hypothesize.** State one specific hypothesis: "X is the root cause because Y".
   Test it with the smallest possible change, one variable at a time.
4. **Fix.** Write a failing test that reproduces the bug (use the tdd skill), fix the root cause, verify the test passes and nothing else broke.
   No "while I'm here" improvements.

## Escalation

After 3 failed fix attempts, stop.
When each fix reveals a new problem somewhere else, the architecture is wrong, not the hypothesis.
Discuss with the user instead of attempting fix #4.

## Red flags - stop and return to phase 1

"Quick fix for now, investigate later". "Just try changing X". "It's probably X". Changing multiple things at once. Proposing fixes before tracing the data flow. "I don't fully understand this, but it might work".
