#!/bin/bash
# Claude Code status line. Receives session JSON on stdin.
# Colors follow the base16 Brewer dark palette to match WezTerm.
# Shows: model (effort) | directory | git branch (+dirty) | git identity | 5h + weekly limits.

input=$(cat)
model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // empty' 2>/dev/null)
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty' 2>/dev/null)
five_pct=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null | cut -d. -f1)
week_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null | cut -d. -f1)
five_reset=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd="$PWD"

PUR='\033[38;2;117;107;177m'
CYN='\033[38;2;128;177;211m'
GRN='\033[38;2;49;163;84m'
ORG='\033[38;2;230;85;13m'
YLW='\033[38;2;220;160;96m'
RED='\033[38;2;227;26;28m'
DIM='\033[38;2;115;116;117m'
RST='\033[0m'

# Pick a color for a usage percentage: green under 50, yellow under 80, red at/above.
pct_color() {
  if [ "$1" -ge 80 ] 2>/dev/null; then printf '%s' "$RED"
  elif [ "$1" -ge 50 ] 2>/dev/null; then printf '%s' "$YLW"
  else printf '%s' "$GRN"
  fi
}

dir="${cwd/#$HOME/~}"
dir=$(printf '%s' "$dir" | awk -F/ 'NF<=3 {print; next} {print "\xe2\x80\xa6/" $(NF-1) "/" $NF}')

model_seg="${PUR}${model}"
[ -n "$effort" ] && model_seg="${model_seg} ${DIM}(${effort})"

git_seg=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  br=$(git -C "$cwd" branch --show-current 2>/dev/null)
  [ -z "$br" ] && br=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null | head -1)" ]; then
    git_seg="${DIM} | ${ORG}${br}*"
  else
    git_seg="${DIM} | ${GRN}${br}"
  fi
  ident=$(git -C "$cwd" config user.name 2>/dev/null)
  [ -n "$ident" ] && git_seg="${git_seg}${DIM} | ${YLW}${ident}"
fi

# Rate limits appear only for Pro/Max sessions after the first API response.
limits_seg=""
if [ -n "$five_pct" ]; then
  reset_txt=""
  [ -n "$five_reset" ] && reset_txt=" ${DIM}→$(date -r "$five_reset" +%H:%M 2>/dev/null)"
  limits_seg="${DIM} | $(pct_color "$five_pct")5h ${five_pct}%${reset_txt}"
fi
if [ -n "$week_pct" ]; then
  limits_seg="${limits_seg}${DIM} | $(pct_color "$week_pct")wk ${week_pct}%"
fi

printf "%b${DIM} | ${CYN}%s%b%b${RST}" "$model_seg" "$dir" "$git_seg" "$limits_seg"

# Line 2: context-window usage bar (appears once the first API response arrives).
ctx=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null | cut -d. -f1)
if [ -n "$ctx" ]; then
  filled=$((ctx / 10)); [ "$filled" -gt 10 ] && filled=10
  bar=""; i=0
  while [ $i -lt 10 ]; do
    if [ $i -lt "$filled" ]; then bar="${bar}\xe2\x96\x93"; else bar="${bar}\xe2\x96\x91"; fi
    i=$((i+1))
  done
  if [ "$ctx" -ge 80 ] 2>/dev/null; then cc="$RED"; elif [ "$ctx" -ge 60 ] 2>/dev/null; then cc="$YLW"; else cc="$GRN"; fi
  printf "\n${DIM}ctx ${cc}${bar} ${ctx}%%${RST}"
fi
