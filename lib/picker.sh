#!/usr/bin/env bash

play_pick_result() {
  local title=$1 input_file=$2 line
  if [[ ${MENU_PROVIDER:-fzf} == fzf ]] && play_has fzf; then
    line=$(awk -F '\t' '{count=($7=="NA"?"":$7); meta=($4=="NA"?"":$4); if (meta=="") meta=count; else if (count!="") meta=meta " / " count; source=($5=="NA"?"":$5); printf "%02d  %-9s %-18s %-18s %s\n", NR, "[" $1 "]", meta, source, $2}' "$input_file" | fzf --height 55% --layout reverse --border --prompt 'play > ' --header "No  Type      Meta               Source             Title") || return 1
    [[ $line =~ ^([0-9]+) ]] || return 1
    sed -n "$((10#${BASH_REMATCH[1]}))p" "$input_file"
    return
  fi

  play_section "$title" >&2
  printf '  %-4s %-9s %-18s %-18s %s\n' 'No' 'Type' 'Meta' 'Source' 'Title' >&2
  printf '  %-4s %-9s %-18s %-18s %s\n' '--' '----' '----' '------' '-----' >&2
  awk -F '\t' '{count=($7=="NA"?"":$7); meta=($4=="NA"?"":$4); if (meta=="") meta=count; else if (count!="") meta=meta " / " count; source=($5=="NA"?"":$5); printf "  %02d   %-9s %-18s %-18s %s\n", NR, "[" $1 "]", meta, source, $2}' "$input_file" >&2
  printf 'Select number or press Enter to cancel: ' >&2
  read -r line
  [[ -z $line ]] && return 1
  [[ $line =~ ^[0-9]+$ ]] || return 1
  sed -n "${line}p" "$input_file"
}
