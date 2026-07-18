#!/usr/bin/env bash

play_doctor() {
  play_log info 'play doctor'
  for cmd in "${PLAYER:-mpv}" yt-dlp socat fzf xdg-open wl-paste wl-copy xclip xsel; do
    if play_has "$cmd"; then
      printf '  %s %-12s %s\n' "$(play_color 32 OK)" "$cmd" "$(command -v "$cmd")"
    else
      case "$cmd" in
        socat|fzf|xdg-open|wl-paste|wl-copy|xclip|xsel) printf '  %s %-12s missing\n' "$(play_color 33 Optional)" "$cmd" ;;
        *) printf '  %s  %-12s missing\n' "$(play_color 31 Missing)" "$cmd" ;;
      esac
    fi
  done
  printf '  Config   %s\n' "$(play_config_path)"
  if play_validate_config_file "$(play_config_path)" >/dev/null 2>&1; then
    printf '  %s %-12s safe\n' "$(play_color 32 OK)" config
  else
    printf '  %s %-12s unsafe\n' "$(play_color 31 Missing)" config
  fi
  printf '  History  %s\n' "$(play_history_path)"
}
