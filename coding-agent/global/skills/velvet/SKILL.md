---
name: velvet
description: "Use Velvet whenever a task mentions worklog, work-log, ticket, recap, or Velvet, and after a meaningful chunk of coding work finishes so the session can record progress, decisions, or blockers."
user-invocable: false
---

# Velvet

Velvet is the record of what work actually happened, across every organisation and project.
Prefer the typed Velvet MCP tools when the current agent exposes them, especially `velvet_log_work`, `velvet_attach_evidence`, `velvet_current_ticket`, and `velvet_my_worklog`.
Use the `velvet` CLI when MCP is unavailable.

## Configuration and invocation

Keep `VELVET_TOKEN` in envkit rather than in a `.env` file or repository file.
Set `VELVET_URL` to the server URL without `/api/v1`.

`VELVET_WORKSPACE` is optional.
When it is unset, Velvet resolves the organisation and project from the checkout's git remote, so one configuration works in every repository.
Set it only to override that, or in a directory with no connected remote.

Run every authenticated command through envkit so the token is supplied only to the child process:

```bash
envkit run -- velvet where
envkit run -- velvet issues --mine
envkit run -- velvet recap --days 7
```

When the CLI is only available in the Velvet checkout, use its absolute path:

```bash
envkit run -- /Users/sabari/Developer/narayana/velvet-otter-lab/cli/velvet where
```

`velvet me` only needs `VELVET_URL` and `VELVET_TOKEN`.

## Always log, even without a ticket

After completing a meaningful unit of work, write one entry.
There is always somewhere to put it, so never skip logging because no ticket exists.

Find the ticket from the branch when there is one:

```bash
KEY="$(velvet key-from-branch)" || KEY=""
```

With a key, log against the ticket:

```bash
envkit run -- velvet log "$KEY" --kind progress "I fixed token authentication and verified the CLI request path."
```

Without a key, log against the project instead.
Omitting `--project` uses the project this repository is mapped to:

```bash
envkit run -- velvet log --kind progress "I fixed token authentication and verified the CLI request path."
```

If that fails because the repository is not mapped to a project, name one explicitly with `--project`, or list the options with `velvet projects`.
Do not invent a ticket key, and do not write the entry to an unrelated ticket.

Classify each entry with `--kind`:

- `progress` when a fix or change landed.
- `decision` when a consequential implementation or scope choice was made.
- `blocker` when something is blocking, or has just been cleared.
- `note` for anything else worth remembering.

Keep each entry factual, in the first person, and to 1-3 sentences.
Describe what changed, what was decided, or what is blocking.
Never invent time spent, estimates, or work that did not happen.

Stdin form for a note with line breaks:

```bash
printf '%s\n' \
  'I decided to keep the CLI dependency-free.' \
  'It uses curl and python3 for transport and JSON.' \
  | envkit run -- velvet log "$KEY" --kind decision
```

## Attach the proof

A pull request or commit is evidence that the work happened.
Attach it once it exists, using whatever reference is to hand:

```bash
envkit run -- velvet attach "$KEY" https://github.com/acme/widgets/pull/42
envkit run -- velvet attach "$KEY" acme/widgets#42
envkit run -- velvet attach "$KEY" "$(git rev-parse HEAD)"
```

Attaching evidence never changes a ticket's status, and must never be treated as though it did.

## Answering "what have you been working on"

```bash
envkit run -- velvet recap --days 7
envkit run -- velvet recap --days 30 --workspace client-slug
```

This spans every organisation the token's owner belongs to and returns Markdown that can be pasted into a message.

## Reading and changing tickets

```bash
envkit run -- velvet issue "$KEY"
envkit run -- velvet issues --status in_progress
envkit run -- velvet projects
envkit run -- velvet new "Document token rotation" --desc "Add the operator runbook"
```

Only run a status change when the user explicitly asks for it, using one of
`backlog`, `todo`, `in_progress`, `in_review`, `done`, or `cancelled`:

```bash
envkit run -- velvet status "$KEY" in_review
```

Never change a status because a pull request was merged, a branch was deleted, or evidence was attached.
The record should reflect what the person decided, not what a branch name implied.
