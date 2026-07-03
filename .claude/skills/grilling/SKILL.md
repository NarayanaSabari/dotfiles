---
name: grilling
description: Use when the user wants a plan or design stress-tested before building, says "grill me" or "grill this plan", or when a design from brainstorming needs hardening before implementation.
---

# Grilling

Interview the user relentlessly about every aspect of the plan until you reach a shared understanding.
Walk down each branch of the design tree, resolving dependencies between decisions one by one.

## Rules

- Ask questions one at a time. Wait for the answer before continuing; multiple questions at once are bewildering.
- For every question, provide your recommended answer and why.
- If a question can be answered by exploring the codebase, explore the codebase instead of asking.
- Attack the plan: probe edge cases, failure modes, hidden dependencies, unstated assumptions, and scope creep. The goal is to find the weak joints before the code does.
- When decisions accumulate, summarize the hardened plan so far in chat (lavish only if the subject is UI itself).
- Do not start implementing until the user confirms shared understanding has been reached.
