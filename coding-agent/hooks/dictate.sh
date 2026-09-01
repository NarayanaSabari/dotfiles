#!/usr/bin/env bash
# jcode dictation backend: record from the default mic until silence, then
# transcribe locally with whisper.cpp and print the transcript on stdout.
# jcode injects whatever this prints into the prompt (mode = "insert").
#
# Deps: sox (rec), whisper-cpp. Model auto-downloaded on first run.
set -euo pipefail

model_dir="$HOME/.cache/whisper"
model="$model_dir/ggml-small.en.bin"
tmp="$(mktemp -t jcode-dictate).wav"
trap 'rm -f "$tmp"' EXIT

command -v rec >/dev/null || { echo "dictation: 'sox' not installed (brew install sox)" >&2; exit 1; }
whisper_bin="$(command -v whisper-cli || command -v whisper-cpp || true)"
[ -n "$whisper_bin" ] || { echo "dictation: whisper-cpp not installed (brew install whisper-cpp)" >&2; exit 1; }

if [ ! -f "$model" ]; then
  mkdir -p "$model_dir"
  curl -fsSL -o "$model" \
    https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin >&2
fi

# 16 kHz mono, stop after 1.5s of silence below 2%. Max 120s enforced by jcode.
rec -q -c 1 -r 16000 -b 16 "$tmp" \
  silence 1 0.1 2% 1 1.5 2% trim 0 120 2>/dev/null || true

[ -s "$tmp" ] || exit 0

# The initial prompt biases decoding toward software vocabulary, so "commit",
# "repo", and "async" don't come out as everyday homophones.
"$whisper_bin" -m "$model" -f "$tmp" -nt -np -otxt -of "${tmp%.wav}" \
  --prompt "Software engineering dictation: git commit, rebase, refactor, repo, branch, PR, async, API, TypeScript, Rust, npm, config, schema, endpoint." \
  >/dev/null 2>&1
transcript_file="${tmp%.wav}.txt"
if [ -f "$transcript_file" ]; then
  tr '\n' ' ' <"$transcript_file" | sed 's/^ *//; s/ *$//'
  rm -f "$transcript_file"
fi
