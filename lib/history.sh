#!/usr/bin/env bash

play_add_history() {
  local type=$1 title=$2 url=$3 path tmp
  [[ -z $url ]] && return 0
  path=$(play_history_path)
  mkdir -p "$(dirname "$path")"
  tmp=$(mktemp)
  printf '%s\t%s\t%s\t%s\n' "$(date -Is)" "$type" "$title" "$url" >"$tmp"
  if [[ -f $path ]]; then
    awk -F '\t' -v url="$url" '$4 != url' "$path" >>"$tmp"
  fi
  mv "$tmp" "$path"
  play_limit_lines 50 "$path"
}

play_last_history() {
  local path
  path=$(play_history_path)
  [[ -f $path ]] || return 1
  sed -n '1p' "$path"
}

play_clear_history() {
  rm -f "$(play_history_path)"
  printf 'Cleared playback history: %s\n' "$(play_history_path)"
}

play_select_history() {
  local path tmp line
  path=$(play_history_path)
  [[ -s $path ]] || return 1
  tmp=$(mktemp)
  awk -F '\t' '{print $2 "\t" $3 "\t" $4 "\t-\t-\t-"}' "$path" >"$tmp"
  line=$(play_pick_result 'Playback History' "$tmp") || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"
  printf '%s\n' "$line"
}
