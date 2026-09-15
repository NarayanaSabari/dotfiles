---
name: velvet
description: "Use Velvet whenever a task mentions worklog, work-log, ticket, or Velvet, and after a meaningful chunk of coding work finishes so the session can record progress, decisions, or blockers."
user-invocable: false
---

# Velvet

Use the `velvet` CLI to read tickets and write concise work-log comments from coding-agent sessions.

## Configuration and invocation

Keep `VELVET_TOKEN` in envkit rather than in a `.env` file or repository file.
Set `VELVET_URL` to the server URL without `/api/v1` and `VELVET_WORKSPACE` to the workspace slug.
Run every authenticated command through envkit so the token is supplied only to the child process:

```bash
envkit run -- velvet me
envkit run -- velvet issues --mine
envkit run -- velvet issue ENG-42
envkit run -- velvet new "Document token rotation" --desc "Add the operator runbook"
```

When the CLI is only available in the Velvet checkout, use its absolute path:

```bash
envkit run -- /Users/sabari/Developer/narayana/velvet-otter-lab/cli/velvet me
envkit run -- /Users/sabari/Developer/narayana/velvet-otter-lab/cli/velvet issues --status in_progress
```

`velvet me` only needs `VELVET_URL` and `VELVET_TOKEN`.
Workspace commands also need `VELVET_WORKSPACE`.

## Find the ticket

Infer the ticket from the current branch before logging:

```bash
KEY="$(velvet key-from-branch)" || KEY=""
if [ -n "$KEY" ]; then
  envkit run -- velvet issue "$KEY"
fi
```

For the checkout-local CLI, replace `velvet` with `/Users/sabari/Developer/narayana/velvet-otter-lab/cli/velvet`.
A branch such as `sabari/eng-42-fix-auth` yields `ENG-42`.
If no key is found, do not invent one and do not write a work-log entry to another ticket.

## When to log

After completing a meaningful unit of work, write one note when there is a ticket key:

- A fix landed. Treat the note as a progress entry.
- A consequential implementation or scope decision was made. Treat the note as a decision entry.
- A blocker was hit or cleared. Treat the note as a blocker entry.

Keep each entry factual, in the first person, and to 1-3 sentences.
Describe what changed, what I decided, or what is blocking me.
Never invent time spent, estimates, or work that did not happen.
Do not change ticket status unless the user explicitly asks for it.

Argument form:

```bash
envkit run -- velvet log "$KEY" "I fixed token authentication and verified the CLI request path."
```

Stdin form for a note with line breaks:

```bash
printf '%s\n' \
  'I decided to keep the CLI dependency-free.' \
  'It uses curl and python3 for transport and JSON.' \
  | envkit run -- velvet log "$KEY"
```

Inspect a ticket and its recent comments with:

```bash
envkit run -- velvet issue "$KEY"
```

Only run a status change when the user asks for it, using one of:
`backlog`, `todo`, `in_progress`, `in_review`, `done`, or `cancelled`.

```bash
envkit run -- velvet status "$KEY" in_review
```
