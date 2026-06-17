#!/usr/bin/env bash

play_doctor() {
  printf 'play doctor\n'
  for cmd in "${PLAYER:-mpv}" yt-dlp fzf xdg-open wl-paste wl-copy xclip xsel; do
    if play_has "$cmd"; then
      printf '  OK       %-12s %s\n' "$cmd" "$(command -v "$cmd")"
    else
      case "$cmd" in
        fzf|xdg-open|wl-paste|wl-copy|xclip|xsel) printf '  Optional %-12s missing\n' "$cmd" ;;
        *) printf '  Missing  %-12s missing\n' "$cmd" ;;
      esac
    fi
  done
  printf '  Config   %s\n' "$(play_config_path)"
  printf '  History  %s\n' "$(play_history_path)"
}
