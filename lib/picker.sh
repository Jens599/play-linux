#!/usr/bin/env bash

play_pick_result() {
  local title=$1 input_file=$2 line
  if [[ ${MENU_PROVIDER:-fzf} == fzf ]] && play_has fzf; then
    line=$(awk -F '\t' '{printf "%02d  [%-8s] %-8s %-18s %s\n", NR, $1, ($4=="NA"||$4==""?"-":$4), ($5=="NA"||$5==""?"-":$5), $2}' "$input_file" | fzf --height 55% --layout reverse --border --header "$title") || return 1
    [[ $line =~ ^([0-9]+) ]] || return 1
    sed -n "$((10#${BASH_REMATCH[1]}))p" "$input_file"
    return
  fi

  printf '\n%s\n' "$title" >&2
  awk -F '\t' '{printf "  %02d  [%-8s] %-8s %-18s %s\n", NR, $1, ($4=="NA"||$4==""?"-":$4), ($5=="NA"||$5==""?"-":$5), $2}' "$input_file" >&2
  printf 'Select number or press Enter to cancel: ' >&2
  read -r line
  [[ -z $line ]] && return 1
  [[ $line =~ ^[0-9]+$ ]] || return 1
  sed -n "${line}p" "$input_file"
}
