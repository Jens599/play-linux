#!/usr/bin/env bash

play_pick_result() {
  local title=$1 input_file=$2 allow_multi=${3:-false} allow_more=${4:-false} append_more_cmd=${5:-} line picked key selected keys header preview_file preview_cmd display_cmd display_file order_file order_helper expect_keys load_more_action fzf_args=()
  if [[ ${MENU_PROVIDER:-fzf} == fzf ]] && play_has fzf; then
    printf -v preview_file '%q' "$input_file"
    display_file=$(mktemp)
    play_register_cleanup_file "$display_file"
    cat >"$display_file" <<EOF
#!/usr/bin/env bash
awk -F '\t' 'function fit(s,w) { return length(s) > w ? substr(s, 1, w - 3) "..." : s } {meta=(\$4=="NA"?"":\$4); count=(\$7=="NA"?"":\$7); source=(\$5=="NA"?"":\$5); printf "%02d   %-10s   %-10s   %-12s   %-22s   %s\\n", NR, fit("[" \$1 "]", 10), fit(meta, 10), fit(count, 12), fit(source, 22), \$2}' $preview_file
EOF
    chmod +x "$display_file"
    display_cmd=$(printf '%q' "$display_file")
    preview_cmd="awk -F '\t' -v n={1} 'NR == n { labels[1] = \"Type\"; labels[2] = \"Title\"; labels[3] = \"URL\"; labels[4] = \"Duration\"; labels[5] = \"Source\"; labels[6] = \"Views\"; labels[7] = \"Count\"; for (i = 1; i <= 7; i++) if (\$i != \"\" && \$i != \"NA\") printf \"%-10s %s\\n\", labels[i] \":\", \$i }' $preview_file"
    keys='Ctrl-P playlists  Ctrl-O info'
    header='No   Type         Meta         Count          Source                   Title'
    if play_bool "$allow_multi"; then
      keys='Tab select  Ctrl-A all  Ctrl-P playlists  Ctrl-O info'
      order_file=$(mktemp)
      order_helper=$(mktemp)
      play_register_cleanup_file "$order_file"
      play_register_cleanup_file "$order_helper"
      cat >"$order_helper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
order_file=$1
selected_file=$2
tmp=$(mktemp)
awk '
  NR == FNR { if (match($0, /^[0-9]+/)) selected[substr($0, RSTART, RLENGTH) + 0] = 1; next }
  selected[$1 + 0] && !seen[$1 + 0]++ { print $1 + 0; ordered[$1 + 0] = 1 }
  END {
    for (num in selected) {
      if (!ordered[num]++) print num
    }
  }
' "$selected_file" "$order_file" >"$tmp"
mv "$tmp" "$order_file"
EOF
      chmod +x "$order_helper"
      fzf_args+=(--multi --bind "tab:toggle+execute-silent($(printf '%q' "$order_helper") $(printf '%q' "$order_file") {+f})" --bind "ctrl-a:toggle-all+execute-silent($(printf '%q' "$order_helper") $(printf '%q' "$order_file") {+f})")
    fi
    expect_keys=ctrl-p
    if play_bool "$allow_more"; then
      keys+='  Ctrl-L more'
      if [[ -n $append_more_cmd ]]; then
        load_more_action="reload($append_more_cmd && $display_cmd)"
        fzf_args+=(--bind "ctrl-l:$load_more_action")
      else
        expect_keys+=,ctrl-l
      fi
    fi
    printf '  Keys: %s\n' "$keys" >&2
    fzf_args=(--height '55%' --layout reverse --border --expect="$expect_keys" --prompt 'play > ' --header "$header" --preview "$preview_cmd" --preview-window 'down,45%,border-top,wrap,hidden' --bind ctrl-o:toggle-preview "${fzf_args[@]}")
    if ! picked=$("$display_file" | fzf "${fzf_args[@]}"); then
      play_unregister_cleanup_file "$display_file"
      rm -f "$display_file"
      if [[ -n ${order_file:-} ]]; then
        play_unregister_cleanup_file "$order_file"
        play_unregister_cleanup_file "$order_helper"
        rm -f "$order_file" "$order_helper"
      fi
      return 1
    fi
    play_unregister_cleanup_file "$display_file"
    rm -f "$display_file"
    key=${picked%%$'\n'*}
    picked=${picked#*$'\n'}
    if [[ -n ${order_file:-} && -s $order_file ]]; then
      picked=$(awk '
        NR == FNR { if (match($0, /^[0-9]+/)) picked[substr($0, RSTART, RLENGTH) + 0] = $0; next }
        ($1 + 0) in picked { print picked[$1 + 0]; emitted[$1 + 0] = 1 }
        END { for (num in picked) if (!emitted[num]) print picked[num] }
      ' <(printf '%s\n' "$picked") "$order_file")
      play_unregister_cleanup_file "$order_file"
      play_unregister_cleanup_file "$order_helper"
      rm -f "$order_file" "$order_helper"
    fi
    if [[ $key == ctrl-l ]]; then
      printf '__PLAY_MORE_RESULTS__\n'
      return
    fi
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
