#!/usr/bin/env bash

play_has() {
  command -v "$1" >/dev/null 2>&1
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
