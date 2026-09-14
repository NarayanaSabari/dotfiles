# Jcode configuration

The config and prompt files here are exposed through .jcode Stow links and ~/.jcode links.
Keep ~/.jcode a real directory: authentication, sessions, memory, logs, and binaries remain untracked.
Shared skills are already managed under coding-agent/global/skills and exposed through ~/.agents/skills.

The stable v0.84.0 configuration supports coordinator and worker effort defaults, not per-model hard maximums.
The routing prompt specifies the user's ceilings; it is not a mechanically enforced quota or effort limiter.
Live tests confirmed Luna max, Sol high, Terra xhigh, and Claude Sonnet low on the intended OAuth routes.
The coding trial used Terra medium and Claude Sonnet low successfully.
These observations do not enforce future per-model ceilings.
Subscription pricing does not establish available tokens or remaining usage.
The daemon retains startup settings; restart it when idle after changing startup defaults.
Existing saved sessions and reused workers may retain their previous model settings.

Automatic idle pokes are disabled to reduce unrequested continuation.
A native swarm stop was observed removing a worker from membership while its tool calls continued on v0.84.0.
The coordinator must revoke future tools using `jcode-revoke-worker` before stopping an owned worker and verify that in-flight work has settled.
Revocation markers live in ~/.jcode/revoked-workers outside Git.
The guard is a pre-tool check, not an OS sandbox; jcode's hook timeout/startup failures remain fail-open.

## Custom source build

Worker routing and the input usage footer live in `~/Developer/narayana/jcode` on `feat/input-usage-footer`.
The personal fork is `https://github.com/NarayanaSabari/jcode`.
The checkout is separate from the pinned skill source under `coding-agent/vendor/jcode-skills`.
The custom display preserves full model names, shows provider/auth and effort, and surfaces effort fallbacks and subsequent route changes.
The footer below the composer shows context usage, model, effort, service tier, and cached subscription limits.
The footer uses at most three colored rows: model/context, OpenAI, and Claude.
The input and footer stay at the bottom of the chat pane, with a muted horizontal divider above the input.
Each provider row shows one account email and an additional-account count; `/usage` lists every account.
Usage refreshes in the background; unavailable and stale results are labeled explicitly.
Narrow terminals shorten details without wrapping; short terminals prioritize typing and the transcript.
Astra defaults to low effort with the Standard service tier, with Fast disabled.
Runtime values describe the provider selected by the harness; they are not independent verification of the upstream service's internal model routing.
Build and publish through `jcode self-dev --build` from the source checkout.
The local `current` channel is separate from the retained `stable` channel.
After an upstream update, integrate and verify these changes again before adopting the new build.
