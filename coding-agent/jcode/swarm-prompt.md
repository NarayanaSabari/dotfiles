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
  one. Do not spawn a review agent at all if `no-mistakes` will already gate
  this change with `agent: codex` - that review step already is the
  cross-model pass; spawning one first burns the same review twice.
- Context fetching, bulk reading, and summarization: the cheapest/fastest
  available model - this work does not need reasoning depth.
- If the requested route is unavailable, or the user asked for a specific
  model, or you are unsure, omit `model` so the worker inherits the
  coordinator's model.

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
