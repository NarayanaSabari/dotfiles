---
description: Cross-model review, then validate through the no-mistakes gate
argument-hint: "[what this change is meant to accomplish]"
---

Ship the current branch's work, following the flow in CLAUDE.md rather than pushing directly.

Context the user gave about this change: $ARGUMENTS

1. **Confirm the target.** Run `git status` and `git log --oneline @{u}.. 2>/dev/null || git log --oneline -5`. The work must be committed on a feature branch, not the default branch. If it is uncommitted, or you are on the default branch, fix that first: branch, then commit only the changes belonging to this task, leaving unrelated working-tree changes alone.

2. **Check the identity.** Compare `git config user.email` against the table in CLAUDE.md. If it is empty or wrong, stop and ask - the `git-identity-guard` hook will block the commit anyway, and guessing an identity is worse than asking.

3. **Get the second opinion.** Delegate to the `codex-reviewer` subagent, telling it which branch and base to review. Wait for its verified findings.

4. **Act on the findings.** Fix what is real. For anything you disagree with, say so with your reasoning rather than silently skipping it - the reviewer is a different model family and is sometimes wrong, but it is also the check that catches what same-model review misses. Commit the fixes on the same branch.

5. **Validate.** Run the no-mistakes pipeline via the `no-mistakes` skill, passing an `--intent` that captures what the user set out to accomplish plus the decisions and tradeoffs made along the way - not a description of the diff. If the repo is not initialized for no-mistakes, say so and ask how to proceed instead of pushing around the gate.

6. **Report** what the review found, what you changed in response, and where the pipeline ended up.
