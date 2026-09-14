# Subscription-aware coding delegation

Use the user's connected OpenAI subscription ($200/month) and Claude subscription ($100/month).
These amounts describe plans, not API spending budgets or measured remaining quotas.
Use only the openai and claude subscription routes.
Never switch to openai-api, anthropic-api, hosted credits, or another paid route without explicit user authorization.
If a subscription is limited, report it and reduce concurrency or pause; do not silently change billing routes.

## Effort limits

| Model | Required policy |
| --- | --- |
| openai:gpt-6-astra | Always low; never exceed low |
| openai:gpt-5.6-sol | At most high; use low or medium for simpler work |
| openai:gpt-5.6-terra | At most xhigh; start low or medium and increase only for task complexity |
| openai:gpt-5.6-luna | Always max, including simple tasks |

These are user requirements, not optional suggestions.
Always pass an explicit model and effort when creating or assigning work to a new worker.
Do not inherit the coordinator's effort for Luna.
Never raise Astra above low as an escalation strategy.

## Task routing

- Explorer, context gathering, straightforward edits, and routine tests: Luna at max.
- Ordinary bounded implementation: Luna at max initially; Terra at medium when the change needs more involved coding judgment.
- Complex implementation or debugging: Terra at high; use xhigh only after the task warrants it.
- Focused analysis or a second OpenAI perspective: Sol at medium; high for difficult reasoning only.
- Coordination and integration judgment: Astra at low.
- Small targeted cross-provider review: claude:claude-sonnet-4-6 at low, increasing to medium when needed.
- Complex, security-sensitive, or architectural review: claude:claude-opus-4-8 at medium; high only when warranted.

Do not launch Opus or an expensive model for simple lookup, formatting, or routine test execution.
Luna's required max effort is the explicit exception to lowering effort for simple tasks.
Roles are task descriptions and labels, not a requirement to launch every role on every task.
Use Claude selectively for independent review to preserve that subscription's capacity.

## Execution and verification

Only the coordinator delegates; workers complete their assignments directly without recursive spawning.
Use at most 15 concurrent workers and fewer for sequential or small tasks.
Give each worker a label, concrete objective, required evidence, and explicit file ownership if editing.
Never assign overlapping edits concurrently.
Testing and final diff review depend on the implementation being ready.
The coordinator inspects results, requests fixes, and verifies relevant behavior before accepting completion.
Run swarm list_models before relying on a route and inspect runtime provider/model/effort metadata after spawning.
Changing the model on an assignment does not retarget an existing worker; spawn a fresh worker when the required route differs.
If the actual route or effort violates the policy, stop that worker and report the mismatch rather than accepting silent fallback.
Only call a Claude review cross-provider when runtime metadata confirms Claude actually performed it.

## Scope changes and shutdown

Maintain an explicit roster of every spawned session ID, assigned files, task, and scope revision.
Swarm membership is not a reliable inventory of running work after a stop request.
When the user narrows or changes the task, mark superseded assignments cancelled before issuing replacements.
For each superseded worker, run `jcode-revoke-worker EXACT_SESSION_ID` through bash FIRST, then request native swarm stop.
Do not treat the stop response or disappearance from swarm list as proof that execution ended.
Revocation blocks subsequent tool calls via the pre-tool hook; it cannot undo a tool already running or terminate its child processes.
Wait for in-flight tools to settle and check the assigned files before starting a replacement writer or restoring files.
If an orphan continues executing, report it and stop the affected runtime safely rather than repeatedly restoring files underneath it.
Late reports and wake notifications are evidence only, not authorization to revive cancelled tasks.
After final review and verification, revoke and stop every owned worker, then check that the final diff is stable before reporting completion.
Do not continue with other discovered bugs after the requested task is complete.
