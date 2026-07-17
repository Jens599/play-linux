#!/usr/bin/env bash

play_is_none() {
  case "${1,,}" in
    '<none>'|none|null|omit) return 0 ;;
    *) return 1 ;;
  esac
}

play_is_auto_format() {
  [[ -z ${1:-} ]] && return 0
  case "${1,,}" in
    auto|from_quality|from-quality|'from quality') return 0 ;;
    *) return 1 ;;
  esac
}

play_is_auto_command() {
  [[ -z ${1:-} ]] && return 0
  case "${1,,}" in
    auto|from_size|from-size|'from size') return 0 ;;
    *) return 1 ;;
  esac
}

play_enabled_command_value() {
  local value=${1:-} auto_value=${2:-false}
  play_is_none "$value" && return 1
  if play_is_auto_command "$value"; then
    play_bool "$auto_value"
    return
  fi
  play_bool "$value"
}

play_ytdl_format_expression() {
  local format=$1 hardware=$2 video=${3:-bestvideo} codec=${4:-auto} height=${5:-from_quality} fps=${6:-30} audio=${7:-bestaudio} fallback=${8:-best}
  local video_value audio_value fallback_value effective_height= effective_fps= effective_codec filters= fallback_filters= height_fallback= fps_fallback=

  if play_is_auto_format "$video"; then video_value=bestvideo; else video_value=$video; fi
  if play_is_auto_format "$audio"; then audio_value=bestaudio; else audio_value=$audio; fi
  if play_is_none "$fallback"; then fallback_value=; elif play_is_auto_format "$fallback"; then fallback_value=best; else fallback_value=$fallback; fi

  if ! play_is_none "$height"; then
    if ! play_is_auto_format "$height" && [[ $height =~ ^[0-9]+$ ]]; then
      effective_height=$height
    else
      case "$format" in
        480p) effective_height=480 ;;
        720p) effective_height=720 ;;
        1080p) effective_height=1080 ;;
      esac
    fi
  fi

  if ! play_is_none "$fps" && ! play_is_auto_format "$fps"; then
    if [[ $fps =~ ^[0-9]+$ ]]; then
      effective_fps=$fps
    else
      printf 'Invalid YTDL_MAX_FPS: %s\n' "$fps" >&2
      return 1
    fi
  fi

  if play_is_none "$codec"; then
    effective_codec=
  elif play_is_auto_format "$codec" && play_bool "$hardware" && [[ $format != audio ]]; then
    effective_codec='vcodec!*=av01'
  elif play_is_auto_format "$codec"; then
    effective_codec=
  else
    effective_codec=$codec
  fi

  if [[ $format == audio ]]; then
    if [[ -n $fallback_value ]]; then printf '%s/%s\n' "$audio_value" "$fallback_value"; else printf '%s\n' "$audio_value"; fi
    return
  fi

  [[ -n $effective_codec ]] && filters+="[$effective_codec]"
  [[ -n $effective_height ]] && filters+="[height<=$effective_height]"
  [[ -n $effective_fps ]] && filters+="[fps<=$effective_fps]"
  if [[ $video_value == best ]]; then
    printf '%s%s\n' "$video_value" "$filters"
    return
  fi
  local video_format="${video_value}${filters}+${audio_value}"
  if [[ -z $fallback_value ]]; then
    printf '%s\n' "$video_format"
    return
  fi
  if [[ -n $effective_codec ]]; then
    fallback_filters="[$effective_codec]"
    [[ -n $effective_height ]] && fallback_filters+="[height<=$effective_height]" && height_fallback="/${fallback_value}[height<=$effective_height]"
    [[ -n $effective_fps ]] && fallback_filters+="[fps<=$effective_fps]" && fps_fallback="/${fallback_value}[fps<=$effective_fps]"
    printf '%s/%s%s%s%s\n' "$video_format" "$fallback_value" "$fallback_filters" "$height_fallback" "$fps_fallback"
    return
  fi
  printf '%s/%s\n' "$video_format" "$fallback_value"
}

play_build_mpv_args() {
  PLAY_MPV_ARGS=()
  local geometry= autofit= format_expr ytdl_raw_options=()
  if play_enabled_command_value "${COMMAND_TERMINAL:-auto}" "$([[ ${BACKGROUND_EFFECTIVE:-false} == true ]] && printf false || printf true)"; then
    PLAY_MPV_ARGS+=(--terminal=yes)
  fi

  case "${SIZE_EFFECTIVE:-${SIZE:-pip}}" in
    pip)
      geometry=320x180-10-10; autofit=320x180
      play_enabled_command_value "${COMMAND_NO_BORDER:-auto}" true && PLAY_MPV_ARGS+=(--no-border)
      play_enabled_command_value "${COMMAND_ONTOP:-auto}" true && PLAY_MPV_ARGS+=(--ontop)
      ;;
    small) geometry=854x480-10-10; autofit=854x480 ;;
    medium) geometry=1280x720-10-10; autofit=1280x720 ;;
    max) PLAY_MPV_ARGS+=(--fullscreen) ;;
  esac

  if [[ -n $geometry ]] && ! play_is_none "${COMMAND_GEOMETRY:-from_size}"; then
    if ! play_is_auto_command "${COMMAND_GEOMETRY:-from_size}"; then geometry=$COMMAND_GEOMETRY; fi
    PLAY_MPV_ARGS+=("--geometry=$geometry")
  fi
  if [[ -n $autofit ]] && ! play_is_none "${COMMAND_AUTOFIT:-from_size}"; then
    if ! play_is_auto_command "${COMMAND_AUTOFIT:-from_size}"; then autofit=$COMMAND_AUTOFIT; fi
    PLAY_MPV_ARGS+=("--autofit=$autofit")
  fi

  play_bool "${AUDIO_ONLY_EFFECTIVE:-false}" && PLAY_MPV_ARGS+=(--no-video)
  play_bool "${LOOP_EFFECTIVE:-false}" && PLAY_MPV_ARGS+=(--loop=inf)

  if ! play_is_none "${COMMAND_HWDEC:-auto}"; then
    if play_is_auto_command "${COMMAND_HWDEC:-auto}"; then
      play_bool "${HARDWARE_ACCEL_EFFECTIVE:-false}" && PLAY_MPV_ARGS+=(--hwdec=auto-safe)
    elif [[ $COMMAND_HWDEC != no ]]; then
      PLAY_MPV_ARGS+=("--hwdec=$COMMAND_HWDEC")
    fi
  fi

  if play_enabled_command_value "${COMMAND_SAVE_POSITION:-auto}" "${REMEMBER_PLAYBACK_SPEED:-true}"; then
    PLAY_MPV_ARGS+=(--save-position-on-quit)
  fi
  if ! play_is_none "${COMMAND_WATCH_LATER_OPTIONS:-start,speed}"; then
    PLAY_MPV_ARGS+=("--watch-later-options=${COMMAND_WATCH_LATER_OPTIONS:-start,speed}")
  fi
  if play_bool "${REVERSE_PLAYLIST_EFFECTIVE:-false}"; then
    ytdl_raw_options+=(playlist-items=1- playlist-reverse=)
  fi

  format_expr=$(play_ytdl_format_expression "${YTDL_FORMAT_EFFECTIVE:-${YTDL_FORMAT:-480p}}" "${HARDWARE_ACCEL_EFFECTIVE:-false}" "${YTDL_VIDEO_SELECTOR:-bestvideo}" "${YTDL_VIDEO_CODEC_FILTER:-auto}" "${YTDL_MAX_HEIGHT:-from_quality}" "${YTDL_MAX_FPS:-30}" "${YTDL_AUDIO_SELECTOR:-bestaudio}" "${YTDL_FALLBACK_SELECTOR:-best}")
  PLAY_YTDL_FORMAT_EXPR=$format_expr
  PLAY_MPV_ARGS+=("--ytdl-format=$format_expr")
  [[ -n ${COOKIE_PATH_EFFECTIVE:-} ]] && ytdl_raw_options+=("cookies=${COOKIE_PATH_EFFECTIVE}")
  [[ -z ${COOKIE_PATH_EFFECTIVE:-} && -n ${COOKIE_BROWSER_EFFECTIVE:-} ]] && ytdl_raw_options+=("cookies-from-browser=${COOKIE_BROWSER_EFFECTIVE}")
  play_bool "${YTDL_NO_DOWNLOAD_ARCHIVE:-true}" && ytdl_raw_options+=(no-download-archive=)
  if ((${#ytdl_raw_options[@]} > 0)); then
    local IFS=,
    PLAY_MPV_ARGS+=("--ytdl-raw-options=${ytdl_raw_options[*]}")
  fi
  if ! play_bool "${NO_SUBTITLES_EFFECTIVE:-false}"; then
    PLAY_MPV_ARGS+=("--slang=${SUBTITLE_LANGUAGE_EFFECTIVE:-${SUBTITLE_LANGUAGE:-en}}")
  fi
  if ((${#MPV_EXTRA_ARGS[@]} > 0)); then
    PLAY_MPV_ARGS+=("${MPV_EXTRA_ARGS[@]}")
  fi
}

play_apply_command_overrides() {
  PLAY_PLAYER=${COMMAND_PLAYER:-${PLAYER:-mpv}}
  PLAY_TARGET_URL=${COMMAND_URL:-$PLAY_TARGET_URL}
  if [[ -n ${COMMAND_URL:-} ]]; then
    PLAY_TARGET_URLS=("$COMMAND_URL")
  fi
  if [[ -n ${COMMAND_BACKGROUND:-} ]]; then BACKGROUND_EFFECTIVE=$COMMAND_BACKGROUND; fi

  if [[ -n ${COMMAND_REPLACE_ARGUMENT:-} ]]; then
    # shellcheck disable=SC2206
    PLAY_MPV_ARGS=($COMMAND_REPLACE_ARGUMENT)
  else
    if [[ -n ${COMMAND_PREPEND_ARGUMENT:-} ]]; then
      # shellcheck disable=SC2206
      local prepend=($COMMAND_PREPEND_ARGUMENT)
      PLAY_MPV_ARGS=("${prepend[@]}" "${PLAY_MPV_ARGS[@]}")
    fi
    if [[ -n ${COMMAND_APPEND_ARGUMENT:-} ]]; then
      # shellcheck disable=SC2206
      local append=($COMMAND_APPEND_ARGUMENT)
      PLAY_MPV_ARGS+=("${append[@]}")
    fi
  fi
}
