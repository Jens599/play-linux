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

max_results=$($ROOT/bin/play --get MAX_RESULTS)
[[ $max_results == 40 ]] || { printf 'Expected MAX_RESULTS=40, got %s\n' "$max_results" >&2; exit 1; }

dry=$($ROOT/bin/play 'https://example.test/video' --dry-run --pass-thru --format 720p --size small --audio-only --mpv-arg '--speed=1.25')
assert_contains "$dry" '--ytdl-format=bestvideo\[height\<=720\]\[fps\<=30\]+bestaudio/best'
assert_contains "$dry" '--no-video'
assert_contains "$dry" '--speed=1.25'

browser_cookie_dry=$($ROOT/bin/play 'https://example.test/video' --dry-run --pass-thru --cookies-from-browser firefox)
assert_contains "$browser_cookie_dry" '--ytdl-raw-options=cookies-from-browser=firefox'
assert_contains "$browser_cookie_dry" 'cookies-from-browser=firefox\,no-download-archive='

$ROOT/bin/play --set YTDL_MAX_FPS=60
fps_dry=$($ROOT/bin/play 'https://example.test/video' --dry-run --pass-thru)
assert_contains "$fps_dry" '\[fps\<=60\]'

reverse_dry=$($ROOT/bin/play 'https://example.test/1' 'https://example.test/2' 'https://example.test/3' --reverse --dry-run --pass-thru)
assert_contains "$reverse_dry" 'https://example.test/3 https://example.test/2 https://example.test/1'

selected=$($ROOT/bin/play 'https://example.test/video' --select-only)
assert_contains "$selected" $'Direct\thttps://example.test/video\thttps://example.test/video'

escaped_selected=$($ROOT/bin/play 'https://example.test/watch\?v=abc\&list=PL123' --select-only)
assert_contains "$escaped_selected" $'Direct\thttps://example.test/watch\\?v=abc\\&list=PL123\thttps://example.test/watch?v=abc&list=PL123'

playlist_count_label=$(bash -c "source '$ROOT/lib/search.sh'; play_search_count_label Playlist 42 NA")
[[ $playlist_count_label == '42 videos' ]] || { printf 'Expected playlist count label, got %s\n' "$playlist_count_label" >&2; exit 1; }

single_playlist_count_label=$(bash -c "source '$ROOT/lib/search.sh'; play_search_count_label Playlist 1 NA")
[[ $single_playlist_count_label == '1 video' ]] || { printf 'Expected singular playlist count label, got %s\n' "$single_playlist_count_label" >&2; exit 1; }

channel_count_label=$(bash -c "source '$ROOT/lib/search.sh'; play_search_count_label Channel NA 123")
[[ $channel_count_label == '123 videos' ]] || { printf 'Expected channel count label, got %s\n' "$channel_count_label" >&2; exit 1; }

unknown_channel_count_label=$(bash -c "source '$ROOT/lib/search.sh'; play_search_count_label Channel NA NA")
[[ $unknown_channel_count_label == 'unknown' ]] || { printf 'Expected unknown channel count label, got %s\n' "$unknown_channel_count_label" >&2; exit 1; }

source_label=$(bash -c "source '$ROOT/lib/search.sh'; play_search_source_label NA '' Atrios Creator")
[[ $source_label == 'Atrios' ]] || { printf 'Expected source label, got %s\n' "$source_label" >&2; exit 1; }

printf 'All tests passed.\n'
