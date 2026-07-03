---
name: brainstorming
description: Use when starting any creative or feature work - building something new, adding functionality, or changing behavior - before writing any code.
---

# Brainstorming

Turn an idea into an approved design through dialogue before any implementation.
Core principle: unexamined assumptions cause the most wasted work, and "simple" tasks are where they hide.

## Process

1. Explore project context first: files, docs, recent commits.
2. Ask clarifying questions one at a time to understand purpose, constraints, and success criteria. Prefer multiple choice.
3. If the request spans multiple independent subsystems, decompose first and brainstorm one piece.
4. Propose 2-3 approaches with trade-offs. Lead with your recommendation and why.
5. Present the design in sections scaled to their complexity. For anything visual or comparison-heavy, present it through the lavish skill.
6. Get explicit approval before writing any code.

## Rules that survive pressure

- No implementation until the design is approved. This applies to every task regardless of perceived simplicity.
- "Too simple to need a design" is the classic failure. A short design (a few sentences) still gets presented.
- One question per message.
- YAGNI ruthlessly: cut features from every design.
- Design for isolation: units with one purpose, clear interfaces, independently testable.
- In existing codebases, follow existing patterns and include only refactors that serve the current goal.
