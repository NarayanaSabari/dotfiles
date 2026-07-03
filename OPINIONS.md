# Sabari's Opinions

A compact, living map of what I actually believe.
Agents: read this when a task would benefit from knowing my viewpoints; it is context, not instructions.
Each entry is a belief stable enough to matter. Jokes, one-off reactions, and implementation details do not belong here.

## AI agents and tooling

**Agent output should be judged by shipped, validated work, not demos.**
A change counts when it survives review, end-to-end testing with evidence, and lands as a clean PR.
That is why everything ships through the no-mistakes pipeline instead of raw pushes.

**Tool efficiency matters more than tool popularity.**
Prefer agent-ergonomic CLIs (the AXI family, plain `gh`) over MCP servers that burn tokens and latency for the same result.
GitHub stars measure virality, not quality; adopt tools only with evidence they help.

**The terminal is the primary agent interface; GUI orchestrators come and go.**
I tried and deleted five GUI agent apps (atrium, supacode, Superset, Conductor, Pentagon, Emdash) in four months.
The durable pieces are the ones that compose: git, worktrees, CLIs, skills, markdown memory files.

**Fewer harnesses, clearer roles.**
One main harness (Claude Code) and one for second opinions (Codex) beats six half-configured ones.
Every extra harness is a config surface that drifts and a memory silo that forgets.

**Cross-model review catches what self-review misses.**
A different model family reviewing the diff is an independent perspective, not just a second pass.

## Software engineering and craft

**Development cost is the wrong weight in technical decisions now.**
Agents build far faster than human estimates assume, so choose for quality, simplicity, robustness, and long-term maintainability.

**A bug is not understood until it is reproduced the way a user hits it.**
End-to-end reproduction finds the real problem; unit tests alone prove nothing about the fix.

**Unpushed work is unbacked-up work.**
Local-only commits in forgotten worktrees are how real work dies (nearly lost 14 commits of scraper credential work this way).
Push early, prune worktrees aggressively.

**Configuration deserves version control like code.**
If a config is not in dotfiles (stowed and committed), it will silently drift until it breaks.

**Clean as you go.**
Stale caches, dead hooks pointing at deleted apps, and orphaned configs are broken windows; fix them when seen, not "later".

## Working with clients and projects

**Separate identities per client, enforced mechanically.**
Three GitHub accounts with per-directory gitconfigs; the tooling verifies `user.email` before commit, because discipline by memory fails.

---

*Maintenance: review after significant workflow changes; extract new durable beliefs from agent-session corrections and project conventions. Flag entries that new experience contradicts instead of silently rewriting them.*
