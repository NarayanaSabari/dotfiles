---
name: velvet
description: "Use Velvet whenever a task mentions worklog, work-log, ticket, recap, or Velvet, and after a meaningful chunk of coding work finishes so the session can record progress, decisions, or blockers."
user-invocable: false
---

# Velvet

Velvet is the record of what work actually happened, across every organisation and project.
Use the hosted Velvet MCP tools: `velvet_log_work`, `velvet_current_ticket`, `velvet_attach_evidence`, `velvet_my_worklog`, and the rest of the `velvet_` tools.
If the Velvet plugin is installed, its skills (`log-work`, `tickets`, `sprints`, `attach-image`, `recap`, `setup`) carry the full workflow; follow them.

If no `velvet_` tools are available, the agent is not connected.
Tell the user to connect the hosted server at `<velvet-url>/api/v1/w/<organisation>/mcp` with a personal API token as a bearer token, or to install the Velvet plugin.
Never ask for the token in chat or write it to a file.

## Always log, even without a ticket

After each meaningful unit of work, write one factual, first-person entry of 1-3 sentences with `velvet_log_work`.

1. If `git branch --show-current` names a ticket, pass it to `velvet_current_ticket` and log with that `key`.
2. Otherwise log with the `project` named in the repository's "Velvet work log" section of `AGENTS.md` or `CLAUDE.md`.
3. Otherwise pick the matching project from `velvet_list_projects`, or ask once.

Set `kind` to `progress`, `decision`, `blocker`, or `note`.
Never invent a ticket key, time spent, or work that did not happen.

## Attach the proof

Attach a pull request URL, `owner/repo#42`, or a commit sha with `velvet_attach_evidence`.

## Status

Change a ticket's status with `velvet_set_status` only when the user explicitly asks.
Never change it because work was logged, a pull request merged, or evidence was attached.

## Without MCP

The `velvet` CLI covers the same work log from a terminal when `VELVET_URL` and `VELVET_TOKEN` are exported:

```bash
velvet log --kind progress "I fixed token authentication and verified the request path."
velvet recap --days 7
```
