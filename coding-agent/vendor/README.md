# Third-party sources

Each child directory is a pinned Git submodule.
Keeping upstream repositories here makes the agent setup reproducible without copying generated skill installations into this repository.

Initialize them with:

```sh
git submodule update --init --recursive
```

Update them deliberately with `git -C ~/dotfiles submodule update --remote`, review the resulting skill changes, and commit the new revisions.
