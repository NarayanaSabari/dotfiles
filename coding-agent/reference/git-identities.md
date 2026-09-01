# Git identities

Two GitHub accounts.
`~/.gitconfig` picks one automatically via `includeIf`, matching both directory and remote URL.

| Account | Email | Matches |
|---------|-------|---------|
| NarayanaSabari | sabarinarayanakg@proton.me | `~/Developer/narayana/`, `~/Developer/neuskale/`, remotes under `NarayanaSabari/` |
| Sabari-RentAI | sabarinarayanakg@rentai.now | `~/Developer/rentai/`, remotes under `renatainow/` |

Check `git config user.email` against this before committing.
Empty or wrong means the repo sits outside the configured roots: ask rather than commit under the wrong account.

Full details in `~/Developer/README-github-accounts.md`.

The `git-identity-guard.sh` PreToolUse hook enforces this table.
It checks the cwd plus every `git -C <path>` in the command, and resolves linked worktrees to their main repo.
See [harness.md](harness.md).
