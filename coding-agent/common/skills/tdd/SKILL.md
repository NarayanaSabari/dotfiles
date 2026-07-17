---
name: tdd
description: Use when implementing any feature or bugfix, before writing implementation code. Not for throwaway prototypes or generated code (ask first).
---

# Test-Driven Development

Core principle: if you did not watch the test fail, you do not know whether it tests the right thing.

## The law

No production code without a failing test first.
Wrote code before the test? Delete it and start over. Do not keep it as "reference", do not adapt it while writing tests.

## Cycle

1. **RED**: write one minimal test for one behavior, derived from the INTENT (what should happen), not from an implementation. Clear name; real code over mocks.
2. **Verify RED**: run it and watch it fail for the right reason (feature missing, not a typo or setup error). If it passes, you are testing existing behavior; fix the test.
3. **GREEN**: write the simplest code that passes. No extra options, no speculative features.
4. **Verify GREEN**: the new test and the whole suite pass.
5. **REFACTOR**: clean up while staying green.

## Review the tests hardest

Generated tests can bless the wrong behavior.
Review them more carefully than the implementation: does each assertion encode the actual requirement, or just mirror what the code happens to do?

## Rationalizations

| Excuse | Reality |
|---|---|
| "Too simple to test" | Simple code breaks. The test takes 30 seconds. |
| "I'll write tests after" | Tests that pass immediately prove nothing. |
| "Skip TDD just this once" | That thought is the signal to use it. |
