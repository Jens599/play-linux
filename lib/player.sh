#!/usr/bin/env bash

play_launch() {
  local command_text
  command_text=$(play_join_command "$PLAY_PLAYER" "${PLAY_MPV_ARGS[@]}" "$PLAY_TARGET_URL")

  if play_bool "${DRY_RUN:-false}"; then
    play_log_command "$command_text"
    play_log info 'Dry run: player was not started.'
    if play_bool "${PASS_THRU:-false}"; then
      printf 'PLAYER=%s\nURL=%s\nCOMMAND=%s\n' "$PLAY_PLAYER" "$PLAY_TARGET_URL" "$command_text"
    fi
    return 0
  fi

  play_add_history "$PLAY_HISTORY_TYPE" "$PLAY_HISTORY_TITLE" "$PLAY_TARGET_URL"
  play_section 'Playback'
  play_detail 'Title' "$PLAY_HISTORY_TITLE"
  play_detail 'Type' "$PLAY_HISTORY_TYPE"
  play_detail 'URL' "$PLAY_TARGET_URL"
  if play_start_mpv_ipc; then
    return 0
  fi

  play_log warn 'IPC startup unavailable; launching player directly.'
  if play_bool "${BACKGROUND_EFFECTIVE:-false}"; then
    nohup "$PLAY_PLAYER" "${PLAY_MPV_ARGS[@]}" "$PLAY_TARGET_URL" >/dev/null 2>&1 &
    play_log ok 'Player started in background.'
  else
    "$PLAY_PLAYER" "${PLAY_MPV_ARGS[@]}" "$PLAY_TARGET_URL"
  fi
}

play_is_mpv_player() {
  local name
  name=$(basename "$PLAY_PLAYER")
  [[ $name == mpv || $name == mpv-* || $name == mpv.* ]]
}

play_wait_for_socket() {
  local socket=$1 i
  for ((i = 0; i < 100; i++)); do
    [[ -S $socket ]] && return 0
    sleep 0.05
  done
  return 1
}

play_send_mpv_loadfile() {
  local socket=$1 url_json payload
  url_json=$(play_json_string "$PLAY_TARGET_URL")
  payload='{"command":["loadfile",'"$url_json"',"replace"]}'
  printf '%s\n' "$payload" | socat - "UNIX-CONNECT:$socket" >/dev/null 2>&1
}

play_start_mpv_ipc() {
  play_is_mpv_player || return 1
  play_has socat || return 1

  local socket runtime_dir process_pid
  runtime_dir=${XDG_RUNTIME_DIR:-/tmp}
  socket="$runtime_dir/play-mpv-${USER:-user}-$BASHPID.sock"
  rm -f "$socket"

  local startup_args=("${PLAY_MPV_ARGS[@]}" --force-window=immediate --idle=once --terminal=no "--input-ipc-server=$socket")
  play_log step 'Opening mpv window.'

  if play_bool "${BACKGROUND_EFFECTIVE:-false}"; then
    nohup "$PLAY_PLAYER" "${startup_args[@]}" >/dev/null 2>&1 &
    process_pid=$!
  else
    "$PLAY_PLAYER" "${startup_args[@]}" &
    process_pid=$!
  fi

  if ! play_wait_for_socket "$socket"; then
    play_log warn 'mpv IPC socket did not become ready.'
    kill "$process_pid" >/dev/null 2>&1 || true
    rm -f "$socket"
    return 1
  fi

  play_log step 'Loading stream.'
  if ! play_send_mpv_loadfile "$socket"; then
    play_log warn 'Failed to send URL to mpv IPC socket.'
    kill "$process_pid" >/dev/null 2>&1 || true
    rm -f "$socket"
    return 1
  fi

  if play_bool "${BACKGROUND_EFFECTIVE:-false}"; then
    play_log ok 'Player started in background.'
    return 0
  fi

  wait "$process_pid" || true
  rm -f "$socket"
  return 0
}
