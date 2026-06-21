#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export XDG_CONFIG_HOME=$(mktemp -d)
export XDG_STATE_HOME=$(mktemp -d)
trap 'rm -rf "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"' EXIT

assert_contains() {
  local haystack=$1 needle=$2
  [[ $haystack == *"$needle"* ]] || { printf 'Expected output to contain: %s\nActual: %s\n' "$needle" "$haystack" >&2; exit 1; }
}

config_path=$($ROOT/bin/play --config-path)
[[ -f $config_path ]] || { printf 'Config was not created.\n' >&2; exit 1; }

$ROOT/bin/play --set YTDL_FORMAT=720p
value=$($ROOT/bin/play --get YTDL_FORMAT)
[[ $value == 720p ]] || { printf 'Expected YTDL_FORMAT=720p, got %s\n' "$value" >&2; exit 1; }

dry=$($ROOT/bin/play 'https://example.test/video' --dry-run --pass-thru --format 720p --size small --audio-only --mpv-arg '--speed=1.25')
assert_contains "$dry" '--ytdl-format=bestvideo\[height\<=720\]+bestaudio/best'
assert_contains "$dry" '--no-video'
assert_contains "$dry" '--speed=1.25'

browser_cookie_dry=$($ROOT/bin/play 'https://example.test/video' --dry-run --pass-thru --cookies-from-browser firefox)
assert_contains "$browser_cookie_dry" '--ytdl-raw-options=cookies-from-browser=firefox'
assert_contains "$browser_cookie_dry" 'cookies-from-browser=firefox\,no-download-archive='

selected=$($ROOT/bin/play 'https://example.test/video' --select-only)
assert_contains "$selected" $'Direct\thttps://example.test/video\thttps://example.test/video'

printf 'All tests passed.\n'
