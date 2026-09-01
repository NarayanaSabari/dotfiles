# Git identities

Two GitHub accounts.
`~/.gitconfig` picks one automatically with `includeIf`, matching both the directory and the remote URL.

| Account | Email | Matches |
|---------|-------|---------|
| NarayanaSabari | sabarinarayanakg@proton.me | `~/Developer/narayana/`, `~/Developer/neuskale/`, remotes under `NarayanaSabari/` |
| Sabari-RentAI | sabarinarayanakg@rentai.now | `~/Developer/rentai/`, remotes under `renatainow/`, `Sabari-RentAI/`, `TAMIRATECH-PRIVATE-LIMITED/` |

Check `git config user.email` against this before committing.
Empty or wrong means the repo sits outside the configured roots: ask rather than commit under the wrong account.
Longer background in `~/Developer/README-github-accounts.md`.

## Why there are four patterns per owner

The remote-URL rules exist so identity follows the *repo* rather than the directory, which matters because tool-managed clones and worktrees land outside `~/Developer/<account>/`.

Git matches `hasconfig:remote.*.url` with wildmatch, where a single `*` does **not** cross a `/` and the pattern must cover the whole URL.
So each owner needs all four remote spellings:

```
https://github.com/OWNER/r      ssh://git@github.com/OWNER/r
git@github.com:OWNER/r          git@github-nick:OWNER/r
```

The earlier `github-rentai:**` and `github-narayana:**` forms silently matched nothing.
They had no leading `*` to absorb the `git@` userinfo, and a trailing `**` cannot span the `OWNER/repo` slash.
Every scp-style and alias-host remote therefore fell through to the `[user]` default, which is the NarayanaSabari identity.
A Sabari-RentAI repo cloned outside `~/Developer/rentai/` would have committed under the wrong account, with nothing reporting it.

To map a new owner, copy all four lines of a block and swap the owner.
Verify with `cd <repo> && git config --show-origin user.email`.

## The credential helper flips underneath you

`gh auth setup-git` installs one credential helper for all of github.com, and `gh` keeps the active account in a single global `hosts.yml`.
So a session working in a Sabari-RentAI repo flips the active account, and HTTPS pushes from a NarayanaSabari repo then fail with `Repository not found`.
That 404 means "you are authenticated as someone who cannot see this", not a missing repo.

`.gitconfig-narayana` works around it by rewriting that account's HTTPS remotes onto the `github-narayana` SSH host, which pins `IdentityFile` to the right key.
The rewrite lives inside the `includeIf`, so rentai repos are untouched and keep using the helper.

## Enforcement

`git-identity-guard.sh` blocks a mismatched `commit`, `push`, `cherry-pick`, `revert`, `merge`, `rebase` or `am` before git runs, so no commit is created.
It checks the session cwd, every `git -C <path>` in the command, and a leading literal `cd`, and it resolves linked worktrees to their main repo.
`--abort`, `--quit` and `--skip` are exempt: unwinding a stopped rebase creates no commits, and a guard that stops you abandoning a conflicted rebase is one you would route around.

It is a backstop. Check the identity yourself.
See [harness.md](/Users/sabari/dotfiles/coding-agent/reference/harness.md).
