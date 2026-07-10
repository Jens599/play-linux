#!/usr/bin/env bash

play_pick_result() {
  local title=$1 input_file=$2 line picked key selected
  if [[ ${MENU_PROVIDER:-fzf} == fzf ]] && play_has fzf; then
    picked=$(awk -F '\t' 'function fit(s,w) { return length(s) > w ? substr(s, 1, w - 3) "..." : s } {meta=($4=="NA"?"":$4); count=($7=="NA"?"":$7); source=($5=="NA"?"":$5); printf "%02d   %-10s   %-10s   %-12s   %-22s   %s\n", NR, fit("[" $1 "]", 10), fit(meta, 10), fit(count, 12), fit(source, 22), $2}' "$input_file" | fzf --height 55% --layout reverse --border --expect=ctrl-p --prompt 'play > ' --header "No   Type         Meta         Count          Source                   Title    ctrl-p: channel playlists") || return 1
    key=${picked%%$'\n'*}
    line=${picked#*$'\n'}
    [[ $line =~ ^([0-9]+) ]] || return 1
    selected=$(sed -n "$((10#${BASH_REMATCH[1]}))p" "$input_file")
    if [[ $key == ctrl-p && $selected == Channel$'\t'* ]]; then
      printf 'ChannelPlaylists\t%s\n' "${selected#*$'\t'}"
    else
      printf '%s\n' "$selected"
    fi
    return
  fi

  play_section "$title" >&2
  printf '  %2s   %-10s   %-10s   %-12s   %-22s   %s\n' 'No' 'Type' 'Meta' 'Count' 'Source' 'Title' >&2
  printf '  %2s   %-10s   %-10s   %-12s   %-22s   %s\n' '--' '----' '----' '-----' '------' '-----' >&2
  awk -F '\t' 'function fit(s,w) { return length(s) > w ? substr(s, 1, w - 3) "..." : s } {meta=($4=="NA"?"":$4); count=($7=="NA"?"":$7); source=($5=="NA"?"":$5); printf "  %02d   %-10s   %-10s   %-12s   %-22s   %s\n", NR, fit("[" $1 "]", 10), fit(meta, 10), fit(count, 12), fit(source, 22), $2}' "$input_file" >&2
  printf 'Select number, p<number> for channel playlists, or press Enter to cancel: ' >&2
  read -r line
  [[ -z $line ]] && return 1
  if [[ $line =~ ^p([0-9]+)$ ]]; then
    selected=$(sed -n "$((10#${BASH_REMATCH[1]}))p" "$input_file")
    [[ $selected == Channel$'\t'* ]] || return 1
    printf 'ChannelPlaylists\t%s\n' "${selected#*$'\t'}"
    return
  fi
  [[ $line =~ ^[0-9]+$ ]] || return 1
  sed -n "${line}p" "$input_file"
}
