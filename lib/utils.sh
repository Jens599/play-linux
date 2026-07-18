#!/usr/bin/env bash

play_has() {
  command -v "$1" >/dev/null 2>&1
}

play_color_enabled() {
  [[ -n ${NO_COLOR:-} ]] && return 1
  case "${PLAY_COLOR:-auto}" in
    always) return 0 ;;
    never|false|off|no) return 1 ;;
    *) [[ -t 1 || -t 2 ]] ;;
  esac
}

play_color() {
  local code=$1 text=$2
  if play_color_enabled; then
    printf '\033[%sm%s\033[0m' "$code" "$text"
  else
    printf '%s' "$text"
  fi
}

play_log() {
  local level=$1 message=$2 label color
  case "$level" in
    ok) label=' DONE '; color='1;30;42' ;;
    warn) label=' WARN '; color='1;30;43' ;;
    error) label=' FAIL '; color='1;37;41' ;;
    step) label=' NEXT '; color='1;30;46' ;;
    info|*) label=' INFO '; color='1;37;44' ;;
  esac
  printf '  %s  %s\n' "$(play_color "$color" "$label")" "$message"
}

play_section() {
  local title=$1 rule
  printf -v rule '%*s' 48 ''
  rule=${rule// /-}
  printf '\n%s\n' "$(play_color '1;36' "$title")"
  printf '%s\n' "$(play_color 90 "$rule")"
}

play_detail() {
  local label=$1 value=$2
  printf '  %s %s\n' "$(play_color 90 "$(printf '%-10s' "$label")")" "$value"
}

play_log_command() {
  local command_text=$1
  play_log step 'Launch command:'
  printf '  %s\n' "$(play_color 33 "$command_text")"
}

play_debug_enabled() {
  play_bool "${PLAY_DEBUG:-false}" && [[ -n ${PLAY_DEBUG_LOG_PATH:-} ]]
}

play_debug_log() {
  play_debug_enabled || return 0
  local message=$1 timestamp
  timestamp=$(date -Is 2>/dev/null || date)
  printf '[%s] %s\n' "$timestamp" "$message" >>"$PLAY_DEBUG_LOG_PATH"
}

play_debug_command() {
  play_debug_enabled || return 0
  local label=$1
  shift
  play_debug_log "$label: $(play_join_command "$@")"
}

play_debug_init() {
  local requested_path=${1:-} path
  if [[ -n $requested_path ]]; then
    path=$requested_path
  else
    mkdir -p "$(play_state_dir)"
    path="$(play_state_dir)/debug-$(date +%Y%m%d-%H%M%S)-$$.log"
  fi
  mkdir -p "$(dirname "$path")"
  : >"$path"
  PLAY_DEBUG=true
  PLAY_DEBUG_LOG_PATH=$path
  play_debug_log 'Debug logging enabled.'
  play_debug_log "Log path: $PLAY_DEBUG_LOG_PATH"
  printf 'Debug log: %s\n' "$PLAY_DEBUG_LOG_PATH" >&2
}

play_register_cleanup_file() {
  PLAY_CLEANUP_FILES+=("$1")
}

play_unregister_cleanup_file() {
  local remove=$1 item
  local remaining=()
  for item in "${PLAY_CLEANUP_FILES[@]}"; do
    [[ $item == "$remove" ]] || remaining+=("$item")
  done
  PLAY_CLEANUP_FILES=("${remaining[@]}")
}

play_register_cleanup_pid() {
  PLAY_CLEANUP_PIDS+=("$1")
}

play_unregister_cleanup_pid() {
  local remove=$1 item
  local remaining=()
  for item in "${PLAY_CLEANUP_PIDS[@]}"; do
    [[ $item == "$remove" ]] || remaining+=("$item")
  done
  PLAY_CLEANUP_PIDS=("${remaining[@]}")
}

play_cleanup() {
  local pid file
  for pid in "${PLAY_CLEANUP_PIDS[@]}"; do
    kill "$pid" >/dev/null 2>&1 || true
  done
  for file in "${PLAY_CLEANUP_FILES[@]}"; do
    rm -f "$file"
  done
  PLAY_CLEANUP_PIDS=()
  PLAY_CLEANUP_FILES=()
}

play_interrupt() {
  trap - INT TERM
  play_cleanup
  printf '\nInterrupted.\n' >&2
  exit 130
}

play_json_string() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '"%s"' "$value"
}

play_join_command() {
  local out='' arg
  for arg in "$@"; do
    printf -v arg '%q' "$arg"
    out+="${out:+ }$arg"
  done
  printf '%s\n' "$out"
}

play_urlencode() {
  local input=$1 length=${#1} i char out=
  for ((i = 0; i < length; i++)); do
    char=${input:i:1}
    case "$char" in
      [a-zA-Z0-9.~_-]) out+="$char" ;;
      ' ') out+='%20' ;;
      *) printf -v char '%%%02X' "'${char}"; out+="$char" ;;
    esac
  done
  printf '%s\n' "$out"
}

play_is_url() {
  [[ $1 =~ ^https?:// ]]
}

play_normalize_url() {
  local value=$1 amp_placeholder=$'\001'
  value=${value//\\&/$amp_placeholder}
  value=${value//\\\?/\?}
  value=${value//\\=/=}
  value=${value//\\%/%}
  value=${value//\\#/#}
  printf '%s\n' "$value" | tr "$amp_placeholder" '&'
}

play_limit_lines() {
  local limit=$1 file=$2 tmp
  [[ -f $file ]] || return 0
  tmp=$(mktemp)
  sed -n "1,${limit}p" "$file" >"$tmp"
  mv "$tmp" "$file"
}
