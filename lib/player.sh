#!/usr/bin/env bash

play_launch() {
  local command_text
  command_text=$(play_join_command "$PLAY_PLAYER" "${PLAY_MPV_ARGS[@]}" "${PLAY_TARGET_URLS[@]}")

  if play_bool "${DRY_RUN:-false}"; then
    play_log_command "$command_text"
    play_log info 'Dry run: player was not started.'
    if play_bool "${PASS_THRU:-false}"; then
      printf 'PLAYER=%s\nURL=%s\nCOMMAND=%s\n' "$PLAY_PLAYER" "$PLAY_TARGET_URL" "$command_text"
    fi
    return 0
  fi

  if ((${#PLAY_TARGET_URLS[@]} == 1)); then
    play_add_history "$PLAY_HISTORY_TYPE" "$PLAY_HISTORY_TITLE" "$PLAY_TARGET_URL"
  else
    local i target_title
    for i in "${!PLAY_TARGET_URLS[@]}"; do
      target_title=${PLAY_TARGET_TITLES[i]:-${PLAY_TARGET_URLS[i]}}
      play_add_history "$PLAY_HISTORY_TYPE" "$target_title" "${PLAY_TARGET_URLS[i]}"
    done
  fi
  play_section 'Playback'
  play_detail 'Title' "$PLAY_HISTORY_TITLE"
  play_detail 'Type' "$PLAY_HISTORY_TYPE"
  [[ -n ${PLAY_HISTORY_SOURCE:-} && ${PLAY_HISTORY_SOURCE:-} != NA ]] && play_detail 'Source' "$PLAY_HISTORY_SOURCE"
  [[ -n ${PLAY_HISTORY_DURATION:-} && ${PLAY_HISTORY_DURATION:-} != NA ]] && play_detail 'Duration' "$PLAY_HISTORY_DURATION"
  [[ -n ${PLAY_HISTORY_VIEWS:-} && ${PLAY_HISTORY_VIEWS:-} != NA ]] && play_detail 'Views' "$PLAY_HISTORY_VIEWS"
  [[ -n ${PLAY_HISTORY_COUNT:-} && ${PLAY_HISTORY_COUNT:-} != NA ]] && play_detail 'Items' "$PLAY_HISTORY_COUNT"
  play_detail 'URL' "$PLAY_TARGET_URL"
  if ((${#PLAY_TARGET_URLS[@]} > 1)); then
    play_detail 'Count' "${#PLAY_TARGET_URLS[@]}"
  fi
  play_detail 'Player' "$PLAY_PLAYER"
  play_detail 'Size' "${SIZE_EFFECTIVE:-${SIZE:-pip}}"
  play_detail 'Format' "${YTDL_FORMAT_EFFECTIVE:-${YTDL_FORMAT:-480p}}"
  play_detail 'Max FPS' "${YTDL_MAX_FPS:-30}"
  play_detail 'Audio' "${AUDIO_ONLY_EFFECTIVE:-false}"
  play_detail 'Background' "${BACKGROUND_EFFECTIVE:-false}"
  play_detail 'Loop' "${LOOP_EFFECTIVE:-false}"
  play_detail 'Hardware' "${HARDWARE_ACCEL_EFFECTIVE:-false}"
  play_detail 'Subtitles' "$([[ ${NO_SUBTITLES_EFFECTIVE:-false} == true ]] && printf off || printf '%s' "${SUBTITLE_LANGUAGE_EFFECTIVE:-${SUBTITLE_LANGUAGE:-en}}")"
  play_detail 'YTDL' "${PLAY_YTDL_FORMAT_EXPR:-}"
  if play_start_mpv_ipc; then
    return 0
  fi

  play_log warn 'IPC startup unavailable; launching player directly.'
  if play_bool "${BACKGROUND_EFFECTIVE:-false}"; then
    nohup "$PLAY_PLAYER" "${PLAY_MPV_ARGS[@]}" "${PLAY_TARGET_URLS[@]}" >/dev/null 2>&1 &
    play_log ok 'Player started in background.'
  else
    "$PLAY_PLAYER" "${PLAY_MPV_ARGS[@]}" "${PLAY_TARGET_URLS[@]}"
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
  local socket=$1 target_url=$2 mode=$3 title=${4:-} url_json title_json payload
  url_json=$(play_json_string "$target_url")
  if [[ -n $title ]]; then
    title_json=$(play_json_string "$title")
    payload='{"command":["loadfile",'"$url_json"',"'"$mode"'",-1,{"force-media-title":'"$title_json"'}]}'
  else
    payload='{"command":["loadfile",'"$url_json"',"'"$mode"'"]}'
  fi
  printf '%s\n' "$payload" | socat - "UNIX-CONNECT:$socket" >/dev/null 2>&1
}

play_write_mpv_playlist() {
  local playlist_file=$1 i title
  printf '#EXTM3U\n' >"$playlist_file"
  for i in "${!PLAY_TARGET_URLS[@]}"; do
    title=${PLAY_TARGET_TITLES[i]:-${PLAY_TARGET_URLS[i]}}
    title=${title//$'\r'/ }
    title=${title//$'\n'/ }
    printf '#EXTINF:-1,%s\n%s\n' "$title" "${PLAY_TARGET_URLS[i]}" >>"$playlist_file"
  done
}

play_send_mpv_loadlist() {
  local socket=$1 playlist_file=$2 file_json payload
  file_json=$(play_json_string "$playlist_file")
  payload='{"command":["loadlist",'"$file_json"',"replace"]}'
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

  nohup "$PLAY_PLAYER" "${startup_args[@]}" >/dev/null 2>&1 &
  process_pid=$!
  play_register_cleanup_pid "$process_pid"
  play_register_cleanup_file "$socket"

  if ! play_wait_for_socket "$socket"; then
    play_log warn 'mpv IPC socket did not become ready.'
    play_unregister_cleanup_pid "$process_pid"
    play_unregister_cleanup_file "$socket"
    kill "$process_pid" >/dev/null 2>&1 || true
    rm -f "$socket"
    return 1
  fi

  play_log step 'Loading stream.'
  if ((${#PLAY_TARGET_URLS[@]} > 1)); then
    local playlist_file
    playlist_file=$(mktemp)
    play_write_mpv_playlist "$playlist_file"
    if ! play_send_mpv_loadlist "$socket" "$playlist_file"; then
      rm -f "$playlist_file"
      play_log warn 'Failed to send playlist to mpv IPC socket.'
      play_unregister_cleanup_pid "$process_pid"
      play_unregister_cleanup_file "$socket"
      kill "$process_pid" >/dev/null 2>&1 || true
      rm -f "$socket"
      return 1
    fi
    rm -f "$playlist_file"
    disown "$process_pid" >/dev/null 2>&1 || true
    play_unregister_cleanup_pid "$process_pid"
    play_unregister_cleanup_file "$socket"
    play_log ok 'Player started.'
    return 0
  fi

  if ! play_send_mpv_loadfile "$socket" "${PLAY_TARGET_URLS[0]}" replace "${PLAY_TARGET_TITLES[0]:-}"; then
    play_log warn 'Failed to send URL to mpv IPC socket.'
    play_unregister_cleanup_pid "$process_pid"
    play_unregister_cleanup_file "$socket"
    kill "$process_pid" >/dev/null 2>&1 || true
    rm -f "$socket"
    return 1
  fi

  disown "$process_pid" >/dev/null 2>&1 || true
  play_unregister_cleanup_pid "$process_pid"
  play_unregister_cleanup_file "$socket"
  play_log ok 'Player started.'
  return 0
}
