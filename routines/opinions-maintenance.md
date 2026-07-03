You are running as Sabari's weekly OPINIONS.md and memory maintenance routine (unattended, headless).
Your job: extract durable opinion candidates from the past week's activity and run watchdog checks.
You PROPOSE changes; you never rewrite ~/OPINIONS.md itself.

## Steps

1. Read ~/OPINIONS.md and ~/.claude/projects/-Users-sabari/memory/MEMORY.md (follow links to individual memory files).

2. Gather the week's evidence, sampling to keep this cheap:
   - List transcript dirs under ~/.claude/projects/ modified in the last 7 days (`find ~/.claude/projects -maxdepth 1 -type d -mtime -7`). For at most 8 of them (largest/most recent), skim the newest .jsonl for USER messages that correct, override, or redirect the agent's judgment. User corrections are opinion candidates; implementation chatter is not.
   - `git -C ~/dotfiles log --oneline --since="7 days ago"` for workflow/config changes.

3. Extract durable opinion candidates: beliefs, taste, recurring judgments, tradeoff preferences.
   Exclude one-off reactions, jokes, facts the repo already records, and implementation details.

4. Watchdog pass over the existing ~/OPINIONS.md entries:
   - Drift: does any recent behavior contradict an existing entry? Flag it; do not resolve it yourself.
   - Staleness: does any entry rest on a claim that changed (tools deleted/replaced, workflow changed)? Flag it.

5. Write your findings to ~/dotfiles/OPINIONS-proposals.md under a new dated heading (## YYYY-MM-DD), newest section on top:
   - "Proposed additions" with belief statement + one-line evidence for each
   - "Watchdog flags" with drift/staleness items
   - If there is genuinely nothing this week, write a single line saying so under the dated heading.

6. Update memory files only for clear factual corrections (a memory that names something that no longer exists). Do not rewrite opinions there.

7. `git -C ~/dotfiles add OPINIONS-proposals.md && git -C ~/dotfiles commit -m "opinions: weekly maintenance proposals"` (only if there are changes).

Keep the whole run modest: no web access needed, no subagents, sample rather than read everything.
