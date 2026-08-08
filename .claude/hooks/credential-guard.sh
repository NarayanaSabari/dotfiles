#!/bin/bash
# PreToolUse guard: block writes that create or stage credential material.
#
# Two things it catches:
#   1. Write/Edit to a credential-shaped path (.env, *.pem, *.key, service-account JSON, id_rsa).
#   2. File content, or a `git add`/`git commit` payload, carrying a live-looking API key.
#
# Exit 0 = allow, exit 2 = block with the message on stderr.
# Deliberately fast: pure bash, no subprocess beyond one jq read.

set -uo pipefail

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')

block() {
  printf 'BLOCKED by credential-guard: %s\n' "$1" >&2
  printf 'Reference the value from the environment instead. If this is a false positive, say so and I will run it.\n' >&2
  exit 2
}

# --- credential-shaped paths -------------------------------------------------
# bash 3.2 on macOS has no ${var,,}, so lowercase via tr.
is_credential_path() {
  local p
  p=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  # Template files document which vars exist and are meant to be committed.
  case "$p" in
    *.example|*.sample|*.template|*.dist|*.tpl) return 1 ;;
  esac
  case "$p" in
    */.env|*/.env.*|.env|.env.*)                 return 0 ;;
    *.pem|*.key|*.p12|*.pfx|*.jks|*.keystore)    return 0 ;;
    */id_rsa|*/id_dsa|*/id_ecdsa|*/id_ed25519)   return 0 ;;
    id_rsa|id_dsa|id_ecdsa|id_ed25519)           return 0 ;;
    */.npmrc|*/.pypirc|*/.netrc|*/credentials)   return 0 ;;
    .npmrc|.pypirc|.netrc|credentials)           return 0 ;;
    *service-account*.json|*serviceaccount*.json) return 0 ;;
    *_secret*.json|*secrets.json|*secrets.yaml|*secrets.yml) return 0 ;;
  esac
  # .key is legitimate in some contexts; .pub never is a secret
  case "$p" in *.pub) return 1 ;; esac
  return 1
}

# --- live-looking secret material -------------------------------------------
# Each pattern targets a vendor-prefixed key shape, not generic high-entropy
# strings, so placeholders like FOO_KEY=your-key-here do not trip it.
has_secret_material() {
  printf '%s' "$1" | grep -qE \
    -e 'sk-ant-(api|admin)[0-9]{2}-[A-Za-z0-9_-]{32,}' \
    -e 'sk-[A-Za-z0-9]{20}T3BlbkFJ[A-Za-z0-9]{20}' \
    -e 'gh[pousr]_[A-Za-z0-9]{36,}' \
    -e 'github_pat_[A-Za-z0-9_]{60,}' \
    -e 'AKIA[0-9A-Z]{16}' \
    -e 'ASIA[0-9A-Z]{16}' \
    -e 'AIza[0-9A-Za-z_-]{35}' \
    -e 'xox[baprs]-[0-9A-Za-z-]{10,}' \
    -e '(sk|rk)_live_[0-9a-zA-Z]{24,}' \
    -e 'glpat-[A-Za-z0-9_-]{20,}' \
    -e 'npm_[A-Za-z0-9]{36}' \
    -e 'dop_v1_[a-f0-9]{64}' \
    -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' \
    -e '"type"[[:space:]]*:[[:space:]]*"service_account"'
}

case "$TOOL" in
  Write|Edit|NotebookEdit)
    FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
    BODY=$(printf '%s' "$INPUT" | jq -r '[.tool_input.content, .tool_input.new_string, .tool_input.new_source] | map(select(. != null)) | join("\n")')

    if [[ -n "$FILE" ]] && is_credential_path "$FILE"; then
      block "$FILE is a credential file. Writing secrets to disk is not something I do unattended."
    fi
    if [[ -n "$BODY" ]] && has_secret_material "$BODY"; then
      block "the content written to ${FILE:-that file} contains what looks like a live API key or private key."
    fi
    ;;

  Bash)
    CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

    # Only inspect commands that stage or record files in git.
    if printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])([^;&|[:space:]]*/)?git[[:space:]]+([^;&|]*[[:space:]])?(add|commit)([[:space:]]|$)'; then
      # Named paths: `git add .env`.
      # Two filters keep commit-message prose out of this. Without them,
      # `git commit -m "stop committing .env files"` was blocked by its own
      # message - this guard rejected the commit that introduced it.
      #   1. drop quoted spans, which is where message text lives
      #   2. require the token to resolve to a real file
      # A quoted path (`git add ".env"`) is therefore not caught here; the
      # sweep check below and the Write/Edit path check still cover it.
      CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
      CMD_PATHS=$(printf '%s' "$CMD" | sed -e "s/\"[^\"]*\"/ /g" -e "s/'[^']*'/ /g")
      for tok in $CMD_PATHS; do
        case "$tok" in
          -*) continue ;;
        esac
        is_credential_path "$tok" || continue
        if [ -e "$tok" ] || { [ -n "$CWD" ] && [ -e "$CWD/$tok" ]; }; then
          block "$tok is a credential file and must never be committed."
        fi
      done

      # Sweeping forms name no path, so the loop above cannot see what they
      # would pick up. Ask git. Only these forms pay for the subprocess, so the
      # cost is not on every Bash call.
      #
      # Deliberately only `git add` with -A/--all/. - the forms that stage
      # UNTRACKED files, which is the whole risk. `-u`/`--update` and
      # `commit -a` touch tracked files only, so they cannot pull in a new
      # .env; triggering on them would false-positive on every `commit -am`.
      # Scoping to `add` also keeps a commit message containing " . " from
      # tripping the check.
      if printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])([^;&|[:space:]]*/)?git[[:space:]]+([^;&|]*[[:space:]])?add([[:space:]]|$)' &&
         printf '%s' "$CMD" | grep -qE '(^|[[:space:]])(-[a-zA-Z]*A[a-zA-Z]*|--all|\.)([[:space:]]|$)'; then
        CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
        if [ -n "$CWD" ] && command -v git >/dev/null 2>&1 &&
           git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
          # --porcelain -uall is read-only and lists every worktree path a
          # `git add -A` would stage. Never mutates the index.
          if ! STAGEABLE=$(git -C "$CWD" status --porcelain -uall 2>/dev/null); then
            block "git could not report what \"$CMD\" would stage, so I cannot rule out a credential file."
          fi
          # Narrow with one grep before touching the shell loop. Calling
          # is_credential_path per line costs ~2ms, so a repo with 60k
          # untracked files took 133s - thirteen times the hook's own 10s
          # timeout. This regex is deliberately WIDER than
          # is_credential_path: it only has to avoid missing a candidate, and
          # every survivor is then judged by the function itself, so the
          # decision stays identical.
          CANDIDATES=$(printf '%s\n' "$STAGEABLE" \
            | sed -e 's/^...//' -e 's/.* -> //' \
            | grep -iE '(^|/)\.env($|\.)|\.(pem|key|p12|pfx|jks|keystore)$|(^|/)id_(rsa|dsa|ecdsa|ed25519)$|(^|/)(\.npmrc|\.pypirc|\.netrc|credentials)$|service-?account|_secret|secrets\.(json|ya?ml)$' \
            | head -200)
          HIT=""
          if [ -n "$CANDIDATES" ]; then
            OLDIFS=$IFS; IFS='
'
            for path in $CANDIDATES; do
              IFS=$OLDIFS
              if is_credential_path "$path"; then HIT="$path"; break; fi
              IFS='
'
            done
            IFS=$OLDIFS
          fi
          if [ -n "$HIT" ]; then
            block "this sweeps the whole worktree and $HIT is a credential file. Stage the paths you mean explicitly, or add $HIT to .gitignore first."
          fi
        fi
        # Not a repo, or no git: nothing can be staged from here, so allow. A
        # `cd <repo> && git add -A` is checked against the wrong directory and
        # is a known gap; blocking it instead would false-positive on a common
        # and harmless pattern.
      fi
    fi

    # Heredocs and echo-into-file are the usual way a key reaches disk via Bash.
    if has_secret_material "$CMD"; then
      block "the command contains what looks like a live API key, token, or private key."
    fi
    ;;
esac

exit 0
