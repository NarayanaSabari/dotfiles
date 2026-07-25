---
description: Ship the current branch through the no-mistakes gate
argument-hint: "[what this change is meant to accomplish]"
---

Ship the current branch's work through the no-mistakes gate rather than pushing directly.

Context the user gave about this change: $ARGUMENTS

Do not run `codex-reviewer` as part of this command. The no-mistakes pipeline is configured with `agent: codex`, so its review step already performs the cross-model Codex review. Running the subagent first would review the same diff twice with the same model family and spend the ChatGPT Plus budget twice.

1. **Confirm the target.** Run `git status` and `git log --oneline @{u}.. 2>/dev/null || git log --oneline -5`. The work must be committed on a feature branch, not the default branch. If it is uncommitted, or you are on the default branch, fix that first: branch, then commit only the changes belonging to this task, leaving unrelated working-tree changes alone.

2. **Check the identity.** Compare `git config user.email` against the table in CLAUDE.md. If it is empty or wrong, stop and ask - the `git-identity-guard` hook will block the commit anyway, and guessing an identity is worse than asking.

3. **Check the repo is gated.** If `no-mistakes axi` reports the repo is not initialized, stop and ask whether to run `no-mistakes init` here. Do not push around the gate on your own. This is also the case where `codex-reviewer` is still the right tool: an ungated repo gets no Codex review otherwise.

4. **Run the gate** via the `no-mistakes` skill. Pass an `--intent` that captures what the user set out to accomplish plus the decisions and tradeoffs made along the way, not a description of the diff. The review step uses that intent to tell a deliberate choice apart from a mistake, so a thin one-liner makes it flag things the user already decided.

5. **Drive the gates as they come.** Findings marked `auto-fix` you can decide yourself. Findings marked `ask-user` belong to the user: relay each one verbatim with its id, file, and full description, then translate their answer into the matching `respond` call. Never edit files yourself while a run is active; the pipeline owns both the findings and the fixes.

6. **Report** what the review found, what the pipeline fixed, and where the run ended up. If the outcome is `checks-passed`, the PR is green but unmerged - give the user the link and let them merge.
