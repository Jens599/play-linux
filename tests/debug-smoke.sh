#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PLAY="$ROOT/bin/play"
OUT_DIR="$ROOT/.tmp/debug-smoke"
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-45}
REAL_URL=${REAL_URL:-https://www.youtube.com/watch?v=dQw4w9WgXcQ}
SEARCH_QUERY=${SEARCH_QUERY:-backlogs}

mkdir -p "$OUT_DIR"

run_case() {
  local name=$1
  shift
  local stdout_file="$OUT_DIR/$name.stdout"
  local stderr_file="$OUT_DIR/$name.stderr"

  printf '\n== %s ==\n' "$name"
  printf 'Command: timeout %ss %q' "$TIMEOUT_SECONDS" "$PLAY"
  printf ' %q' "$@"
  printf '\n'

  if timeout "${TIMEOUT_SECONDS}s" "$PLAY" "$@" >"$stdout_file" 2>"$stderr_file"; then
    printf 'Status: ok\n'
  else
    local status=$?
    printf 'Status: failed (%s)\n' "$status"
  fi

  printf 'Stdout: %s\n' "$stdout_file"
  printf 'Stderr: %s\n' "$stderr_file"
}

printf 'Writing debug smoke output to: %s\n' "$OUT_DIR"
printf 'Timeout per command: %ss\n' "$TIMEOUT_SECONDS"
printf 'URL: %s\n' "$REAL_URL"
printf 'Search query: %s\n' "$SEARCH_QUERY"

run_case direct-dry-run \
  "$REAL_URL" \
  --dry-run \
  --pass-thru \
  --debug-log "$OUT_DIR/direct-dry-run.log"

run_case direct-select-only \
  "$REAL_URL" \
  --select-only \
  --debug-log "$OUT_DIR/direct-select-only.log"

run_case search-channel-first \
  -s "$SEARCH_QUERY" \
  --type channel \
  --first \
  --select-only \
  --debug-log "$OUT_DIR/search-channel-first.log"

run_case invalid-format \
  "$REAL_URL" \
  --format garbage \
  --select-only \
  --debug-log "$OUT_DIR/invalid-format.log"

printf '\nDebug logs:\n'
for log in "$OUT_DIR"/*.log; do
  [[ -e $log ]] || continue
  printf '  %s\n' "$log"
done

printf '\nInspect with, for example:\n'
printf '  less %q\n' "$OUT_DIR/direct-dry-run.log"
