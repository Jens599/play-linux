#!/usr/bin/env bash

play_config_dir() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/play"
}

play_config_path() {
  printf '%s\n' "$(play_config_dir)/config"
}

play_state_dir() {
  printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/play"
}

play_history_path() {
  printf '%s\n' "$(play_state_dir)/history.tsv"
}

play_write_default_config() {
  mkdir -p "$(play_config_dir)"
  cat >"$(play_config_path)" <<'EOF'
# Linux play configuration. Values are shell assignments.
PLAYER=mpv
MENU_PROVIDER=fzf
COOKIE_PATH=
COOKIE_BROWSER=

SIZE=pip
YTDL_FORMAT=480p
MAX_RESULTS=10
PLAY_COLOR=auto

AUDIO_ONLY=false
BACKGROUND=false
LOOP=false
HARDWARE_ACCEL=false
REVERSE_PLAYLIST=false
NO_SUBTITLES=false
SUBTITLE_LANGUAGE=en
REMEMBER_PLAYBACK_SPEED=true

YTDL_VIDEO_SELECTOR=bestvideo
YTDL_VIDEO_CODEC_FILTER=auto
YTDL_MAX_HEIGHT=from_quality
YTDL_MAX_FPS=30
YTDL_AUDIO_SELECTOR=bestaudio
YTDL_FALLBACK_SELECTOR=best
YTDL_NO_DOWNLOAD_ARCHIVE=true

COMMAND_TERMINAL=auto
COMMAND_GEOMETRY=from_size
COMMAND_AUTOFIT=from_size
COMMAND_NO_BORDER=auto
COMMAND_ONTOP=auto
COMMAND_HWDEC=auto
COMMAND_SAVE_POSITION=auto
COMMAND_WATCH_LATER_OPTIONS=start,speed

COMMAND_PLAYER=
COMMAND_PREPEND_ARGUMENT=
COMMAND_REPLACE_ARGUMENT=
COMMAND_APPEND_ARGUMENT=
COMMAND_URL=
COMMAND_BACKGROUND=
EOF
}

play_ensure_config() {
  if [[ ! -f "$(play_config_path)" ]]; then
    play_write_default_config
  fi
}

play_load_config() {
  play_ensure_config
  # shellcheck source=/dev/null
  source "$(play_config_path)"
}

play_open_config() {
  play_ensure_config
  "${EDITOR:-nano}" "$(play_config_path)"
}

play_export_config() {
  local dest=$1
  play_ensure_config
  mkdir -p "$(dirname "$dest")"
  cp "$(play_config_path)" "$dest"
  printf 'Exported config: %s\n' "$dest"
}

play_import_config() {
  local src=$1
  if [[ ! -f $src ]]; then
    printf 'Config import file not found: %s\n' "$src" >&2
    return 1
  fi
  mkdir -p "$(play_config_dir)"
  cp "$src" "$(play_config_path)"
  printf 'Imported config: %s\n' "$(play_config_path)"
}

play_set_config_value() {
  local key=$1 value=$2 path
  path=$(play_config_path)
  play_ensure_config
  if ! [[ $key =~ ^[A-Z][A-Z0-9_]*$ ]]; then
    printf 'Invalid config key: %s\n' "$key" >&2
    return 1
  fi
  if grep -q "^${key}=" "$path"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$path"
  else
    printf '%s=%s\n' "$key" "$value" >>"$path"
  fi
}

play_bool() {
  case "${1,,}" in
    true|t|yes|y|1|on) return 0 ;;
    *) return 1 ;;
  esac
}
