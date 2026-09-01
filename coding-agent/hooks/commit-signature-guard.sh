#!/bin/bash
# PreToolUse guard: keep tool attribution out of commit messages.
#
# CLAUDE.md: "Never sign your work. No Co-Authored-By trailer, no 'Generated
# with Claude Code' line, no session link, no tool name anywhere in a commit
# message... A commit message is the message and nothing else."
#
# That rule was in force from 2026-07-03 and 13 commits carried a
# `Claude-Session: https://claude.ai/code/session_...` trailer anyway. Prose
# did not hold. This does.
#
# Exit 0 = allow, exit 2 = block with the message on stderr.
#
# TRAILERS ONLY, NEVER PROSE. Every pattern is anchored to the start of a line
# and requires the punctuation a real trailer has. A message that *discusses*
# these strings must pass: this file's own history includes commits whose
# messages talk about Co-Authored-By, and an earlier guard in this directory
# blocked the commit that introduced it by matching its own message text. That
# is a demonstrated failure mode, not a theoretical one.

set -uo pipefail

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# Cheap bail-out first: this runs on every Bash call.
case "$CMD" in *commit*) ;; *) exit 0 ;; esac

# Require an actual `git commit`, path-qualified forms included. Detection runs
# on a quote-stripped copy so `bash -c 'git commit ...'` is still recognised;
# the trailer scan below runs on the ORIGINAL text, because stripping quotes
# would not change line structure but rewriting the text might.
printf '%s' "$CMD" | tr -d "\"'\\\\" \
  | grep -qE '(^|[;&|[:space:]])([^;&|[:space:]]*/)?git[[:space:]]([^;&|]*[[:space:]])?commit([[:space:]]|$)' \
  || exit 0

block() {
  printf 'BLOCKED by commit-signature-guard: %s\n' "$1" >&2
  printf 'A commit message is the message and nothing else (CLAUDE.md). Remove the trailer and commit again.\n' >&2
  exit 2
}

scan() {
  # Co-Authored-By, as a trailer at the start of a line.
  printf '%s' "$1" | grep -qE '^[[:space:]]*Co-[Aa]uthored-[Bb]y:[[:space:]]*[^[:space:]]' &&
    block "the message carries a Co-Authored-By trailer"
  # Any trailer key whose value is a claude.ai/code link. Catches
  # `Claude-Session:` without hard-coding that one key name.
  printf '%s' "$1" | grep -qE '^[[:space:]]*[A-Za-z][A-Za-z-]*:[[:space:]]*https?://claude\.ai/code/' &&
    block "the message carries a session-link trailer"
  # The generated-with line. The markdown link form is the distinctive part;
  # prose saying "generated with Claude Code" in a sentence does not match.
  printf '%s' "$1" | grep -qF 'Generated with [Claude Code](' &&
    block "the message carries a \"Generated with Claude Code\" line"
  return 0
}

# -m, --message=, heredoc bodies and --amend -m all live in the command text.
scan "$CMD"

# -F <file> / --file=<file> put the message on disk instead. Read it if it is
# there; a missing file is git's problem to report, not this hook's.
FFILE=""
# shellcheck disable=SC2086
set -- $CMD
while [ $# -gt 0 ]; do
  case "$1" in
    -F|--file) shift; [ $# -gt 0 ] && FFILE="$1" ;;
    --file=*)  FFILE="${1#--file=}" ;;
  esac
  shift
done
if [ -n "$FFILE" ] && [ "$FFILE" != "-" ]; then
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
  for cand in "$FFILE" "$CWD/$FFILE"; do
    if [ -f "$cand" ]; then
      scan "$(cat "$cand" 2>/dev/null)"
      break
    fi
  done
fi

exit 0
