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
  local out= arg
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

play_limit_lines() {
  local limit=$1 file=$2 tmp
  [[ -f $file ]] || return 0
  tmp=$(mktemp)
  sed -n "1,${limit}p" "$file" >"$tmp"
  mv "$tmp" "$file"
}
