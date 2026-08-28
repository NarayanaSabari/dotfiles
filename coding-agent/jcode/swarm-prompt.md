<!--
This file IS the swarm config. Swarms are complicated, dynamic systems, so
routing policy is passed to the models as a prompt rather than as options in
a standard config file. Edit freely: it is symlinked from
coding-agent/jcode/swarm-prompt.md via ~/dotfiles, so edits here are what
every jcode session on this machine actually uses.
-->

Model routing guidance for spawned swarm agents. Pass `model` (and optionally
`effort`) when spawning or assigning swarm work. Run `swarm list_models` first
to confirm which models/routes are actually available before relying on a
specific one.

- Default worker model: inherit from the coordinator unless a role below says
  otherwise. Cross-model review is the exception, not the default - most
  fan-out work should stay in the coordinator's model family for consistency.
- Implementation tasks (writing code, running builds/tests, refactors): the
  coordinator's model at its current effort. Only drop to a cheaper/faster
  model for fully-specified, mechanical work (renames, boilerplate, simple
  find-and-replace across files).
- Review, verification, and cross-model second opinions: prefer a different
  model family from whatever the coordinator is running, when the available
  routes allow it. A same-family reviewer catches less than an independent
  one. Run at most one cross-model review pass per diff; a second one on the
  same change burns the same budget for the same signal.
- **Independence is the point of a review agent, so never let it fall back
  silently.** `swarm spawn` accepts a `model` that is not actually routable and
  gives you a worker on the coordinator's own model without erroring, which
  looks identical in the UI to the cross-model review you asked for. Two
  same-family passes then get reported as independent review, which is worse
  than no review, because it is a false negative wearing a badge. So for any
  review or verification agent:
  1. Confirm the route exists (`swarm list_models`) before relying on it.
  2. Confirm the worker is actually running what you asked for after it
     spawns - `swarm list` shows each agent's model. Check it.
  3. If the route is unavailable, say so out loud and either pick another
     genuinely different family from `swarm list_models` or state plainly that
     the review was same-family. Never quietly accept the fallback.
     The `codex` CLI is no longer the escape hatch: that harness was retired
     on 2026-08-28.
- **As of 2026-08-28, `model` pinning on this machine appears to be ignored
  entirely.** Three probes (`gpt-5.6-luna`, `google/gemini-3.7-flash`, and a
  same-provider `claude-haiku-4-5` control) all spawned workers that reported
  the coordinator's own model. The OpenAI token has also been failing to
  refresh since 2026-08-20. So until a probe demonstrates otherwise, treat
  every spawned reviewer as same-family and report it that way. Verify with a
  throwaway "which model are you?" spawn before claiming independence.
- Context fetching, bulk reading, and summarization: the cheapest/fastest
  available model - this work does not need reasoning depth.
- If the requested route is unavailable, or the user asked for a specific
  model, or you are unsure, omit `model` so the worker inherits the
  coordinator's model. This fallback is for WORK, not for review: see above.

Structure guidance for spawned swarm agents:

- Always pass a short, descriptive label so the swarm UI shows what each
  agent is for.
- Normal and light-swarm mode are one-level fan-out: only the root session
  spawns agents. Workers complete their assigned task directly and report
  back rather than creating another generation.
- Recursive spawning is reserved for a root running in `swarm-deep` mode. In
  that mode the spawner owns its children, and decomposition into deeper
  subtrees is fine when it materially improves coverage.
- Prefer DMs and typed task-graph artifacts (`complete_node`) over ad hoc
  broadcasts or channels for coordination. Broadcasts should be rare status
  updates, not the primary communication path.
