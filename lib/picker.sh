#!/usr/bin/env bash

play_pick_result() {
  local title=$1 input_file=$2 allow_multi=${3:-false} line picked key selected header preview_file preview_cmd fzf_args=()
  if [[ ${MENU_PROVIDER:-fzf} == fzf ]] && play_has fzf; then
    printf -v preview_file '%q' "$input_file"
    preview_cmd="awk -F '\t' -v n={1} 'NR == n { labels[1] = \"Type\"; labels[2] = \"Title\"; labels[3] = \"URL\"; labels[4] = \"Duration\"; labels[5] = \"Source\"; labels[6] = \"Views\"; labels[7] = \"Count\"; for (i = 1; i <= 7; i++) if (\$i != \"\" && \$i != \"NA\") printf \"%-10s %s\\n\", labels[i] \":\", \$i }' $preview_file"
    header="No   Type         Meta         Count          Source                   Title    ctrl-o: info  ctrl-p: channel playlists"
    if play_bool "$allow_multi"; then
      header="No   Type         Meta         Count          Source                   Title    tab: select  ctrl-a: toggle all  ctrl-o: info  ctrl-p: channel playlists"
      fzf_args+=(--multi --bind ctrl-a:toggle-all,ctrl-d:deselect-all)
    fi
    fzf_args=(--height 55% --layout reverse --border --expect=ctrl-p --prompt 'play > ' --header "$header" --preview "$preview_cmd" --preview-window down,45%,border-top,wrap,hidden --bind ctrl-o:toggle-preview "${fzf_args[@]}")
    picked=$(awk -F '\t' 'function fit(s,w) { return length(s) > w ? substr(s, 1, w - 3) "..." : s } {meta=($4=="NA"?"":$4); count=($7=="NA"?"":$7); source=($5=="NA"?"":$5); printf "%02d   %-10s   %-10s   %-12s   %-22s   %s\n", NR, fit("[" $1 "]", 10), fit(meta, 10), fit(count, 12), fit(source, 22), $2}' "$input_file" | fzf "${fzf_args[@]}") || return 1
    key=${picked%%$'\n'*}
    picked=${picked#*$'\n'}
    if [[ $key == ctrl-p && $picked == *$'\n'* ]]; then return 1; fi
    while IFS= read -r line; do
      [[ $line =~ ^([0-9]+) ]] || return 1
      selected=$(sed -n "$((10#${BASH_REMATCH[1]}))p" "$input_file")
      if [[ $key == ctrl-p && $selected == Channel$'\t'* ]]; then
        printf 'ChannelPlaylists\t%s\n' "${selected#*$'\t'}"
      else
        printf '%s\n' "$selected"
      fi
    done <<<"$picked"
    [[ -n $picked ]] || return 1
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
