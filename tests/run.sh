#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
XDG_CONFIG_HOME=$(mktemp -d)
XDG_STATE_HOME=$(mktemp -d)
XDG_CACHE_HOME=$(mktemp -d)
export XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME
trap 'rm -rf "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"' EXIT

assert_contains() {
  local haystack=$1 needle=$2
  [[ $haystack == *"$needle"* ]] || { printf 'Expected output to contain: %s\nActual: %s\n' "$needle" "$haystack" >&2; exit 1; }
}

config_path=$("$ROOT/bin/play" --config-path)
[[ -f $config_path ]] || { printf 'Config was not created.\n' >&2; exit 1; }

help_output=$("$ROOT/bin/play" --help)
assert_contains "$help_output" "--from/-fr searches videos only"
assert_contains "$help_output" "--refresh and --no-cache currently affect --from/-fr channel resolution."
assert_contains "$help_output" "play -s 'terraria' --from 'CarlPlayin42' -f 720p"

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

unused_playlist_results=$( "$ROOT/bin/play" 'https://example.test/video' --playlist-results 3 --select-only 2>&1 ) && { printf 'Expected --playlist-results without --channel-playlists to fail.\n' >&2; exit 1; }
assert_contains "$unused_playlist_results" '--playlist-results requires --channel-playlists.'

pass_thru_without_dry_run=$( "$ROOT/bin/play" 'https://example.test/video' --pass-thru 2>&1 ) && { printf 'Expected --pass-thru without --dry-run to fail.\n' >&2; exit 1; }
assert_contains "$pass_thru_without_dry_run" '--pass-thru requires --dry-run.'

conflicting_actions=$( "$ROOT/bin/play" 'https://example.test/video' --select-only --copy-url 2>&1 ) && { printf 'Expected conflicting action flags to fail.\n' >&2; exit 1; }
assert_contains "$conflicting_actions" 'Choose only one action'

cache_flag_conflict=$( "$ROOT/bin/play" 'https://example.test/video' --refresh --no-cache --select-only 2>&1 ) && { printf 'Expected --refresh with --no-cache to fail.\n' >&2; exit 1; }
assert_contains "$cache_flag_conflict" '--refresh cannot be combined with --no-cache.'

search_home_conflict=$( "$ROOT/bin/play" -s query --home --select-only 2>&1 ) && { printf 'Expected --search with --home to fail.\n' >&2; exit 1; }
assert_contains "$search_home_conflict" '--search cannot be combined with --home.'

playlist_type_conflict=$( "$ROOT/bin/play" -s query --playlist --type video --select-only 2>&1 ) && { printf 'Expected --playlist with --type video to fail.\n' >&2; exit 1; }
assert_contains "$playlist_type_conflict" '--playlist cannot be combined with --type video or --type channel.'

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
playlist_dry=$(PATH="$fake_bin:$PATH" MENU_PROVIDER=fzf "$ROOT/bin/play" 'https://www.youtube.com/channel/example' --channel-playlists --playlist-results 3 -f 720p --dry-run --pass-thru 2>/dev/null)
assert_contains "$playlist_dry" '--ytdl-format=bestvideo\[height\<=720\]'
assert_contains "$playlist_dry" 'https://www.youtube.com/playlist\?list=PL3'
rm -rf "$fake_bin"

fake_bin=$(mktemp -d)
cat >"$fake_bin/yt-dlp" <<'EOF'
#!/usr/bin/env bash
printf 'Playlist One\tPL1\tYoutubeTab\thttps://www.youtube.com/playlist?list=PL1\tNA\tChannel\tUploader\tNA\tView full playlist\tNA\t2\tNA\n'
EOF
cat >"$fake_bin/fzf" <<'EOF'
#!/usr/bin/env bash
args=" $* "
[[ $args == *'ctrl-o:execute-silent('* ]] || { printf 'missing ctrl-o playlist binding\n' >&2; exit 2; }
[[ $args == *'ctrl-b:execute-silent('* ]] || { printf 'missing ctrl-b back binding\n' >&2; exit 2; }
[[ $args == *'ctrl-r:execute-silent('* ]] || { printf 'missing ctrl-r reverse binding\n' >&2; exit 2; }
[[ $args == *'alt-i:toggle-preview'* ]] || { printf 'missing alt-i info binding\n' >&2; exit 2; }
IFS= read -r line || exit 1
printf '\n%s\n' "$line"
EOF
chmod +x "$fake_bin/yt-dlp" "$fake_bin/fzf"
picker_shortcuts=$(PATH="$fake_bin:$PATH" MENU_PROVIDER=fzf "$ROOT/bin/play" -s playlists --type playlist --select-only 2>/dev/null)
assert_contains "$picker_shortcuts" $'Playlist\tPlaylist One\thttps://www.youtube.com/playlist?list=PL1'
rm -rf "$fake_bin"

fake_bin=$(mktemp -d)
cat >"$fake_bin/yt-dlp" <<'EOF'
#!/usr/bin/env bash
args=" $* "
if [[ $args == *'/playlists '* ]]; then
  printf 'Cached Playlist\tPL9\tYoutubeTab\thttps://www.youtube.com/playlist?list=PL9\tNA\tCache Channel\tCache Channel\tNA\tView full playlist\tNA\t9\tNA\n'
else
  [[ ${FAIL_CHANNEL_SEARCH:-false} != true ]] || { printf 'channel lookup disabled\n' >&2; exit 3; }
  [[ $args == *'sp=EgIQAg%3D%3D'* ]] || { printf 'expected channel search\n' >&2; exit 2; }
  printf 'Cache Channel\tUC999\tYoutubeTab\thttps://www.youtube.com/@cachechannel\tNA\tCache Channel\tCache Channel\tNA\tNA\tNA\tNA\t9\n'
fi
EOF
cat >"$fake_bin/fzf" <<'EOF'
#!/usr/bin/env bash
IFS= read -r line || exit 1
printf '\n%s\n' "$line"
EOF
chmod +x "$fake_bin/yt-dlp" "$fake_bin/fzf"
channel_playlist_cached_first=$(PATH="$fake_bin:$PATH" MENU_PROVIDER=fzf "$ROOT/bin/play" -s 'Cache Channel' --channel-playlists --playlist-results 9 --select-only 2>/dev/null)
assert_contains "$channel_playlist_cached_first" $'Playlist\tCached Playlist\thttps://www.youtube.com/playlist?list=PL9'
channel_playlist_cached_second=$(FAIL_CHANNEL_SEARCH=true PATH="$fake_bin:$PATH" MENU_PROVIDER=fzf "$ROOT/bin/play" -s 'Cache Channel' --channel-playlists --playlist-results 9 --select-only 2>/dev/null)
assert_contains "$channel_playlist_cached_second" $'Playlist\tCached Playlist\thttps://www.youtube.com/playlist?list=PL9'
channel_playlist_refresh=$(FAIL_CHANNEL_SEARCH=true PATH="$fake_bin:$PATH" MENU_PROVIDER=fzf "$ROOT/bin/play" -s 'Cache Channel' --channel-playlists --playlist-results 9 --refresh --select-only 2>&1) && { printf 'Expected --refresh to bypass cached channel playlist lookup.\n' >&2; exit 1; }
assert_contains "$channel_playlist_refresh" 'No results found.'
rm -rf "$fake_bin"

fake_bin=$(mktemp -d)
cat >"$fake_bin/yt-dlp" <<'EOF'
#!/usr/bin/env bash
args=" $* "
if [[ $args == *'search_query=Linux%20Channel%20install'* || $args == *'search_query=Linux+Channel+install'* ]]; then
  printf 'Install tour\tVID1\tYoutube\thttps://www.youtube.com/watch?v=VID1\t12:00\tLinux Channel\tLinux Channel\tNA\tNA\t100\tNA\tNA\n'
  printf 'Install tour\tVID2\tYoutube\thttps://www.youtube.com/watch?v=VID2\t08:00\tOther Channel\tOther Channel\tNA\tNA\t200\tNA\tNA\n'
else
  [[ ${FAIL_CHANNEL_SEARCH:-false} != true ]] || { printf 'channel lookup disabled\n' >&2; exit 3; }
  [[ $args == *'sp=EgIQAg%3D%3D'* ]] || { printf 'expected channel search\n' >&2; exit 2; }
  printf 'Linux Channel\tUC123\tYoutubeTab\thttps://www.youtube.com/@linuxchannel\tNA\tLinux Channel\tLinux Channel\tNA\tNA\tNA\tNA\t42\n'
fi
EOF
chmod +x "$fake_bin/yt-dlp"
from_selected=$(PATH="$fake_bin:$PATH" "$ROOT/bin/play" -s install -fr 'Linux Channel' --first --select-only 2>/dev/null)
assert_contains "$from_selected" $'Video\tInstall tour\thttps://www.youtube.com/watch?v=VID1'
[[ $from_selected != *'VID2'* ]] || { printf 'Expected --from query to filter other channels.\n' >&2; exit 1; }
from_cached=$(FAIL_CHANNEL_SEARCH=true PATH="$fake_bin:$PATH" "$ROOT/bin/play" -s install -fr 'Linux Channel' --first --select-only 2>/dev/null)
assert_contains "$from_cached" $'Video\tInstall tour\thttps://www.youtube.com/watch?v=VID1'
from_refresh=$(FAIL_CHANNEL_SEARCH=true PATH="$fake_bin:$PATH" "$ROOT/bin/play" -s install -fr 'Linux Channel' --refresh --first --select-only 2>&1) && { printf 'Expected --refresh to bypass cached channel lookup.\n' >&2; exit 1; }
assert_contains "$from_refresh" 'Channel not found: Linux Channel'
from_no_cache=$(FAIL_CHANNEL_SEARCH=true PATH="$fake_bin:$PATH" "$ROOT/bin/play" -s install -fr 'Linux Channel' --no-cache --first --select-only 2>&1) && { printf 'Expected --no-cache to bypass cached channel lookup.\n' >&2; exit 1; }
assert_contains "$from_no_cache" 'Channel not found: Linux Channel'
from_without_search=$(PATH="$fake_bin:$PATH" "$ROOT/bin/play" install --from 'Linux Channel' --first --select-only 2>/dev/null)
assert_contains "$from_without_search" $'Video\tInstall tour\thttps://www.youtube.com/watch?v=VID1'
from_playlist_conflict=$(PATH="$fake_bin:$PATH" "$ROOT/bin/play" -s install -p -fr 'Linux Channel' --first --select-only 2>&1) && { printf 'Expected --from with --playlist to fail.\n' >&2; exit 1; }
assert_contains "$from_playlist_conflict" '--from searches channel videos only.'
from_type_conflict=$(PATH="$fake_bin:$PATH" "$ROOT/bin/play" -s install -fr 'Linux Channel' --type channel --first --select-only 2>&1) && { printf 'Expected --from with --type channel to fail.\n' >&2; exit 1; }
assert_contains "$from_type_conflict" '--from searches channel videos only.'
from_channel_playlists_conflict=$(PATH="$fake_bin:$PATH" "$ROOT/bin/play" -s install -fr 'Linux Channel' --channel-playlists --first --select-only 2>&1) && { printf 'Expected --from with --channel-playlists to fail.\n' >&2; exit 1; }
assert_contains "$from_channel_playlists_conflict" '--from searches channel videos only.'
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
assert_contains "$completion_script" '--from'
assert_contains "$completion_script" '-fr'
assert_contains "$completion_script" '--refresh'
assert_contains "$completion_script" '--no-cache'
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
