---
name: velvet
description: "Use Velvet whenever a task mentions worklog, work-log, ticket, recap, or Velvet, and after a meaningful chunk of coding work finishes so the session can record progress, decisions, or blockers."
user-invocable: false
---

# Velvet

Velvet is the record of what work actually happened.
Agents write to it with the `velvet` CLI, from a repository linked to one Velvet project.
If the Velvet plugin is installed, its skills (`log-work`, `tickets`, `sprints`, `attach-image`, `recap`, `setup`) carry the full workflow; follow them.

## Check the link

Run `velvet whoami` in the repository.

- `command not found`: ask the user to run `curl -fsSL https://velvet.sabarinarayana.com/install.sh | sh`.
- Exit 78 (no `velvet.yaml`) or exit 3 (no key, or revoked): ask the user to run `velvet init` in the repository. It opens a browser to approve.

Never ask for a key in chat, write one to a file, or edit `velvet.yaml` to reach another project.

## Always log, even without a ticket

After each meaningful unit of work, write one factual, first-person entry of 1-3 sentences.

1. If `velvet key-from-branch` prints a key, log to it: `velvet log ENG-42 "..."`.
2. Otherwise log to the repository's project: `velvet log "..."`.

Flags go before the message: `velvet log ENG-42 --kind decision "..."`, with `progress` (default), `decision`, `blocker`, or `note`.
Never invent a ticket key, time spent, or work that did not happen.
Exit 7 means the ticket is in another project: tell the user.

## Attach the proof

`velvet attach ENG-42 <pull request URL | owner/repo#42 | commit sha>`.

## Status

Run `velvet status KEY STATUS` only when the user explicitly asks.
Never change it because work was logged, a pull request merged, or evidence was attached.

## Recap

`velvet recap --days 7` covers this repository's project; My work log in the web app covers everything.
