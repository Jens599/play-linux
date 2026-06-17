#!/usr/bin/env bash

play_launch() {
  local command_text
  command_text=$(play_join_command "$PLAY_PLAYER" "${PLAY_MPV_ARGS[@]}" "$PLAY_TARGET_URL")
  printf 'Launching:\n  %s\n' "$command_text"

  if play_bool "${DRY_RUN:-false}"; then
    printf 'Dry run: player was not started.\n'
    if play_bool "${PASS_THRU:-false}"; then
      printf 'PLAYER=%s\nURL=%s\nCOMMAND=%s\n' "$PLAY_PLAYER" "$PLAY_TARGET_URL" "$command_text"
    fi
    return 0
  fi

  play_add_history "$PLAY_HISTORY_TYPE" "$PLAY_HISTORY_TITLE" "$PLAY_TARGET_URL"
  if play_bool "${BACKGROUND_EFFECTIVE:-false}"; then
    nohup "$PLAY_PLAYER" "${PLAY_MPV_ARGS[@]}" "$PLAY_TARGET_URL" >/dev/null 2>&1 &
    printf 'Player started in background.\n'
  else
    "$PLAY_PLAYER" "${PLAY_MPV_ARGS[@]}" "$PLAY_TARGET_URL"
  fi
}
