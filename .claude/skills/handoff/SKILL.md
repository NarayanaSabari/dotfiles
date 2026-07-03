---
name: handoff
description: Compact the current conversation into a handoff document another agent can pick up. Use when the user invokes /handoff, wants to continue work in a fresh session, or hand work to a parallel agent.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

# Handoff

Write a handoff document summarizing the current conversation so a fresh agent can continue the work immediately.

## Rules

- Save it OUTSIDE the current workspace: use the session scratchpad or the OS temp directory, and print the full path at the end.
- If the user passed arguments, treat them as what the next session will focus on and tailor the document to that.
- Do not duplicate content already captured in other artifacts (plans, PRs, commits, diffs, memory files). Reference them by path or URL instead.
- Include: current state of the work, decisions made and why, what remains, known traps discovered along the way, and exact next steps.
- Include a "suggested skills and agents" section naming which skills (tdd, debugging, no-mistakes, lavish...) and subagents (codex-reviewer, evidence-verifier) the next agent should use for the remaining work.
- REDACT any sensitive values: API keys, tokens, passwords, connection strings, personal data. Reference where they live instead of what they are.
