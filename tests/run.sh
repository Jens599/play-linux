#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
XDG_CONFIG_HOME=$(mktemp -d)
XDG_STATE_HOME=$(mktemp -d)
export XDG_CONFIG_HOME XDG_STATE_HOME
trap 'rm -rf "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"' EXIT

assert_contains() {
  local haystack=$1 needle=$2
  [[ $haystack == *"$needle"* ]] || { printf 'Expected output to contain: %s\nActual: %s\n' "$needle" "$haystack" >&2; exit 1; }
}

config_path=$("$ROOT/bin/play" --config-path)
[[ -f $config_path ]] || { printf 'Config was not created.\n' >&2; exit 1; }

"$ROOT/bin/play" --set YTDL_FORMAT=720p
value=$("$ROOT/bin/play" --get YTDL_FORMAT)
[[ $value == 720p ]] || { printf 'Expected YTDL_FORMAT=720p, got %s\n' "$value" >&2; exit 1; }

"$ROOT/bin/play" --set SUBTITLE_LANGUAGE='en,ja'
subtitle_language=$("$ROOT/bin/play" --get SUBTITLE_LANGUAGE)
[[ $subtitle_language == 'en,ja' ]] || { printf 'Expected SUBTITLE_LANGUAGE=en,ja, got %s\n' "$subtitle_language" >&2; exit 1; }

"$ROOT/bin/play" --set TEST_VALUE='value with spaces & symbols'
test_value=$("$ROOT/bin/play" --get TEST_VALUE)
[[ $test_value == 'value with spaces & symbols' ]] || { printf 'Expected TEST_VALUE to round-trip, got %s\n' "$test_value" >&2; exit 1; }

invalid_get=$( "$ROOT/bin/play" --get 'A;date' 2>&1 ) && { printf 'Expected invalid --get to fail.\n' >&2; exit 1; }
assert_contains "$invalid_get" 'Invalid config key: A;date'

"$ROOT/bin/play" --set COMMAND_APPEND_ARGUMENT='--speed=1.25 --no-border'
append_dry=$("$ROOT/bin/play" 'https://example.test/video' --dry-run --pass-thru)
assert_contains "$append_dry" '--speed=1.25'
assert_contains "$append_dry" '--no-border'
"$ROOT/bin/play" --set COMMAND_APPEND_ARGUMENT=

dry=$("$ROOT/bin/play" 'https://example.test/video' --dry-run --pass-thru --format 720p --size small --audio-only --mpv-arg '--speed=1.25')
assert_contains "$dry" '--ytdl-format=bestvideo\[height\<=720\]\[fps\<=30\]+bestaudio/best'
assert_contains "$dry" '--no-video'
assert_contains "$dry" '--speed=1.25'

debug_log=$(mktemp)
debug_stderr=$("$ROOT/bin/play" 'https://example.test/video' --dry-run --debug-log "$debug_log" 2>&1 >/dev/null)
assert_contains "$debug_stderr" "Debug log: $debug_log"
[[ -s $debug_log ]] || { printf 'Expected debug log to be written.\n' >&2; exit 1; }
debug_content=$(<"$debug_log")
assert_contains "$debug_content" 'Debug logging enabled.'
assert_contains "$debug_content" 'argv: play https://example.test/video --dry-run --debug-log'
assert_contains "$debug_content" 'Config loaded.'
assert_contains "$debug_content" 'player command:'
assert_contains "$debug_content" 'launch command:'
rm -f "$debug_log"

browser_cookie_dry=$("$ROOT/bin/play" 'https://example.test/video' --dry-run --pass-thru --cookies-from-browser firefox)
assert_contains "$browser_cookie_dry" '--ytdl-raw-options=cookies-from-browser=firefox'
assert_contains "$browser_cookie_dry" 'cookies-from-browser=firefox\,no-download-archive='

"$ROOT/bin/play" --set YTDL_MAX_FPS=60
fps_dry=$("$ROOT/bin/play" 'https://example.test/video' --dry-run --pass-thru)
assert_contains "$fps_dry" '\[fps\<=60\]'

reverse_dry=$("$ROOT/bin/play" 'https://example.test/1' 'https://example.test/2' 'https://example.test/3' --reverse --dry-run --pass-thru)
assert_contains "$reverse_dry" 'https://example.test/3 https://example.test/2 https://example.test/1'

selected=$("$ROOT/bin/play" 'https://example.test/video' --select-only)
assert_contains "$selected" $'Direct\thttps://example.test/video\thttps://example.test/video'

escaped_selected=$("$ROOT/bin/play" 'https://example.test/watch\?v=abc\&list=PL123' --select-only)
assert_contains "$escaped_selected" $'Direct\thttps://example.test/watch\\?v=abc\\&list=PL123\thttps://example.test/watch?v=abc&list=PL123'

invalid_playlist_results=$( "$ROOT/bin/play" 'https://example.test/video' --playlist-results nope --select-only 2>&1 ) && { printf 'Expected invalid --playlist-results to fail.\n' >&2; exit 1; }
assert_contains "$invalid_playlist_results" '--playlist-results requires a positive integer.'

missing_format=$( "$ROOT/bin/play" -s 'backlogs' -t channel -f 2>&1 ) && { printf 'Expected missing --format to fail.\n' >&2; exit 1; }
assert_contains "$missing_format" 'Error: -f requires a format such as 480p, 720p, 1080p, best, or audio.'
assert_contains "$missing_format" 'Hint: Example: play -s "backlogs" -t channel --format 720p'

option_after_format=$( "$ROOT/bin/play" 'https://example.test/video' -f --dry-run 2>&1 ) && { printf 'Expected option after --format to fail.\n' >&2; exit 1; }
assert_contains "$option_after_format" 'Error: -f requires a format such as 480p, 720p, 1080p, best, or audio.'

invalid_size=$( "$ROOT/bin/play" 'https://example.test/video' --size huge --select-only 2>&1 ) && { printf 'Expected invalid --size to fail.\n' >&2; exit 1; }
assert_contains "$invalid_size" 'Error: size has invalid value: huge'

invalid_format=$( "$ROOT/bin/play" 'https://example.test/video' --format garbage --select-only 2>&1 ) && { printf 'Expected invalid --format to fail.\n' >&2; exit 1; }
assert_contains "$invalid_format" 'Error: format has invalid value: garbage'

invalid_type=$( "$ROOT/bin/play" -s query --type bogus --select-only 2>&1 ) && { printf 'Expected invalid --type to fail.\n' >&2; exit 1; }
assert_contains "$invalid_type" 'Error: type has invalid value: bogus'

"$ROOT/bin/play" --set AUDIO_ONLY=maybe
invalid_bool=$( "$ROOT/bin/play" 'https://example.test/video' --select-only 2>&1 ) && { printf 'Expected invalid boolean config to fail.\n' >&2; exit 1; }
assert_contains "$invalid_bool" 'Error: AUDIO_ONLY_EFFECTIVE has invalid value: maybe'
"$ROOT/bin/play" --set AUDIO_ONLY=false

unsafe_config=$(mktemp)
# shellcheck disable=SC2016
printf '%s\n' 'PLAYER=$(touch /tmp/play-linux-unsafe)' >"$unsafe_config"
unsafe_import=$( "$ROOT/bin/play" --config-import "$unsafe_config" 2>&1 ) && { printf 'Expected unsafe config import to fail.\n' >&2; exit 1; }
assert_contains "$unsafe_import" 'contains executable shell syntax'
rm -f "$unsafe_config"

doctor_output=$("$ROOT/bin/play" --doctor)
assert_contains "$doctor_output" 'config       safe'

# shellcheck disable=SC2016
printf '%s\n' 'PLAYER=$(touch /tmp/play-linux-unsafe-current)' >"$config_path"
doctor_unsafe=$("$ROOT/bin/play" --doctor)
assert_contains "$doctor_unsafe" 'config       unsafe'
safe_config=$(mktemp)
printf 'PLAYER=mpv\nYTDL_FORMAT=720p\n' >"$safe_config"
"$ROOT/bin/play" --config-import "$safe_config" >/dev/null
repaired_player=$("$ROOT/bin/play" --get PLAYER)
[[ $repaired_player == mpv ]] || { printf 'Expected repaired PLAYER=mpv, got %s\n' "$repaired_player" >&2; exit 1; }
rm -f "$safe_config"

fake_bin=$(mktemp -d)
cat >"$fake_bin/yt-dlp" <<'EOF'
#!/usr/bin/env bash
args=" $* "
[[ $args == *' --playlist-items 1:3 '* ]] || exit 2
printf 'Playlist Three\tPL3\tYoutubeTab\thttps://www.youtube.com/playlist?list=PL3\tNA\tChannel\tUploader\tNA\tView full playlist\tNA\t3\tNA\n'
EOF
cat >"$fake_bin/fzf" <<'EOF'
#!/usr/bin/env bash
IFS= read -r line || exit 1
printf '\n%s\n' "$line"
EOF
chmod +x "$fake_bin/yt-dlp" "$fake_bin/fzf"
playlist_selected=$(PATH="$fake_bin:$PATH" MENU_PROVIDER=fzf "$ROOT/bin/play" 'https://www.youtube.com/channel/example' --channel-playlists --playlist-results 3 --select-only 2>/dev/null)
assert_contains "$playlist_selected" $'Playlist\tPlaylist Three\thttps://www.youtube.com/playlist?list=PL3'
rm -rf "$fake_bin"

completion_home=$(mktemp -d)
printf 'if command -v zsh >/dev/null 2>&1; then\n  exec zsh -l\nfi\n' >"$completion_home/.bashrc"
printf 'compinit\n' >"$completion_home/.zshrc"
HOME=$completion_home XDG_DATA_HOME='' "$ROOT/bin/play" --install-bash-completion >/dev/null
[[ -f $completion_home/.local/share/play/completion.bash ]] || { printf 'Completion file was not created.\n' >&2; exit 1; }
[[ -f $completion_home/.bashrc ]] || { printf '.bashrc was not created.\n' >&2; exit 1; }
completion_script=$(<"$completion_home/.local/share/play/completion.bash")
completion_bashrc=$(<"$completion_home/.bashrc")
completion_zshrc=$(<"$completion_home/.zshrc")
assert_contains "$completion_script" 'complete -F _play_complete play'
assert_contains "$completion_script" '--debug-log'
assert_contains "$completion_bashrc" '# >>> play bash completion >>>'
assert_contains "$completion_zshrc" '# >>> play zsh completion >>>'
assert_contains "$completion_zshrc" 'bashcompinit'
completion_marker_line=$(awk '/# >>> play bash completion >>>/ { print NR; exit }' "$completion_home/.bashrc")
completion_exec_line=$(awk '/exec zsh -l/ { print NR; exit }' "$completion_home/.bashrc")
((completion_marker_line < completion_exec_line)) || { printf 'Completion block was not inserted before exec zsh.\n' >&2; exit 1; }
rm -rf "$completion_home"

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
