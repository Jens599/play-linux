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

play_config_key_valid() {
  [[ $1 =~ ^[A-Z][A-Z0-9_]*$ ]]
}

play_config_value_has_unsafe_shell() {
  local value=$1 char quote='' escaped=false i
  for ((i = 0; i < ${#value}; i++)); do
    char=${value:i:1}
    if [[ $escaped == true ]]; then
      escaped=false
      continue
    fi
    if [[ $quote != "'" && $char == "\\" ]]; then
      escaped=true
      continue
    fi
    if [[ $quote != '"' && $char == "'" ]]; then
      if [[ $quote == "'" ]]; then quote=; else quote="'"; fi
      continue
    fi
    if [[ $quote != "'" && $char == '"' ]]; then
      if [[ $quote == '"' ]]; then quote=; else quote='"'; fi
      continue
    fi
    if [[ $quote == "'" ]]; then
      continue
    fi
    if [[ $char == '$' || $char == '`' ]]; then
      return 0
    fi
    if [[ -z $quote ]]; then
      case "$char" in
        ' '|$'\t'|';'|'&'|'|'|'<'|'>'|'('|')') return 0 ;;
      esac
    fi
  done
  [[ $escaped == true || -n $quote ]]
}

play_validate_config_file() {
  local file=$1 line key value lineno=0
  if ! bash -n "$file" >/dev/null 2>&1; then
    printf 'Invalid config syntax: %s\n' "$file" >&2
    return 1
  fi
  while IFS= read -r line || [[ -n $line ]]; do
    lineno=$((lineno + 1))
    [[ -z $line || $line == \#* ]] && continue
    if [[ $line != *=* ]]; then
      printf 'Unsafe config line %d: expected KEY=VALUE assignment.\n' "$lineno" >&2
      return 1
    fi
    key=${line%%=*}
    value=${line#*=}
    if ! play_config_key_valid "$key"; then
      printf 'Unsafe config line %d: invalid key %s.\n' "$lineno" "$key" >&2
      return 1
    fi
    if play_config_value_has_unsafe_shell "$value"; then
      printf 'Unsafe config line %d: value for %s contains executable shell syntax.\n' "$lineno" "$key" >&2
      return 1
    fi
  done <"$file"
}

play_load_config() {
  play_ensure_config
  play_validate_config_file "$(play_config_path)"
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
  play_validate_config_file "$src" || return 1
  mkdir -p "$(play_config_dir)"
  cp "$src" "$(play_config_path)"
  printf 'Imported config: %s\n' "$(play_config_path)"
}

play_set_config_value() {
  local key=$1 value=$2 path quoted tmp found=false line
  path=$(play_config_path)
  play_ensure_config
  if ! play_config_key_valid "$key"; then
    printf 'Invalid config key: %s\n' "$key" >&2
    return 1
  fi
  printf -v quoted '%q' "$value"
  tmp=$(mktemp)
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line == "$key="* ]]; then
      printf '%s=%s\n' "$key" "$quoted" >>"$tmp"
      found=true
    else
      printf '%s\n' "$line" >>"$tmp"
    fi
  done <"$path"
  if [[ $found == false ]]; then
    printf '%s=%s\n' "$key" "$quoted" >>"$tmp"
  fi
  mv "$tmp" "$path"
}

play_get_config_value() {
  local key=$1
  if ! play_config_key_valid "$key"; then
    printf 'Invalid config key: %s\n' "$key" >&2
    return 1
  fi
  printf '%s\n' "${!key:-}"
}

play_bool() {
  case "${1,,}" in
    true|t|yes|y|1|on) return 0 ;;
    *) return 1 ;;
  esac
}
