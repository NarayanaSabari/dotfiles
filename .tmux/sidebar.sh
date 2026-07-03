#!/bin/bash
# Agent sidebar - runs inside a slim right pane, one per window.
# Shows: session (+ prefix WAIT), vertical window list with attention dots
# (window_bell_flag), treehouse summary, clock. Refreshes twice a second.

# Mark own pane so attach/toggle scripts can find it.
[ -n "$TMUX_PANE" ] && tmux set -p -t "$TMUX_PANE" @sidebar 1 2>/dev/null

P='\033[38;2;117;107;177m'; G='\033[38;2;49;163;84m'; Y='\033[38;2;220;160;96m'
O='\033[38;2;230;85;13m'; R='\033[38;2;227;26;28m'; D='\033[38;2;115;116;117m'
F='\033[38;2;183;184;185m'; RST='\033[0m'; BLD='\033[1m'
SEP="──────────────"

tput civis 2>/dev/null
trap 'tput cnorm 2>/dev/null; exit 0' INT TERM

tick=0
th_line=""
while :; do
  if [ $((tick % 40)) -eq 0 ] && command -v treehouse >/dev/null 2>&1; then
    th_line=$(treehouse status 2>/dev/null | awk '
      BEGIN{b=0;i=0}
      /in use|busy|active/{b++}
      /idle|free/{i++}
      END{if (b+i>0) printf "%d busy · %d idle", b, i}')
  fi

  sess=$(tmux display -p '#S' 2>/dev/null) || exit 0
  prefix=$(tmux display -p '#{client_prefix}' 2>/dev/null)

  printf '\033[H'
  if [ "$prefix" = "1" ]; then
    printf "${O}${BLD}◆ WAIT${RST}\033[K\n"
  else
    printf "${P}${BLD}◆ %s${RST}\033[K\n" "$sess"
  fi
  printf "${D}%s${RST}\033[K\n" "$SEP"

  tmux list-windows -F $'#{window_index}\t#{window_active}\t#{window_bell_flag}\t#{window_name}' 2>/dev/null |
  while IFS=$'\t' read -r idx active bell name; do
    name="${name:0:16}"
    dot=""
    [ "$bell" = "1" ] && dot=" ${R}${BLD}●${RST}"
    if [ "$active" = "1" ]; then
      printf "${Y}${BLD}▸ %s %s${RST}%b\033[K\n" "$idx" "$name" "$dot"
    else
      printf "${F}  %s %s${RST}%b\033[K\n" "$idx" "$name" "$dot"
    fi
  done

  printf "${D}%s${RST}\033[K\n" "$SEP"
  if [ -n "$th_line" ]; then
    printf "${D}treehouse${RST}\033[K\n${G}%s${RST}\033[K\n" "$th_line"
    printf "${D}%s${RST}\033[K\n" "$SEP"
  fi
  printf "${D}%s${RST}\033[K\n" "$(date '+%H:%M · %a')"
  printf '\033[J'

  tick=$((tick+1))
  sleep 0.5
done
