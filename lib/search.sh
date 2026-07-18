#!/usr/bin/env bash

play_normalize_type() {
  case "${1,,}" in
    v|video|videos) printf 'Video\n' ;;
    p|pl|playlist|playlists) printf 'Playlist\n' ;;
    c|ch|channel|channels) printf 'Channel\n' ;;
    '') printf '\n' ;;
    *) return 1 ;;
  esac
}

play_search_type() {
  local id=$1 ie=$2 url=$3
  if [[ $url =~ /playlist\?list= ]] || [[ $id == PL* ]] || [[ $id == UU* ]]; then printf 'Playlist\n'; return; fi
  if [[ $url =~ /(channel|c|user|@) ]] || [[ $id == UC* ]] || [[ $ie == YoutubeTab ]]; then printf 'Channel\n'; return; fi
  printf 'Video\n'
}

play_search_count_label() {
  local result_type=$1 playlist_count=$2 channel_video_count=$3
  case "$result_type" in
    Playlist)
      if [[ -n $playlist_count && $playlist_count != NA ]]; then
        [[ $playlist_count == 1 ]] && printf '1 video\n' || printf '%s videos\n' "$playlist_count"
      else
        printf 'unknown\n'
      fi
      ;;
    Channel)
      if [[ -n $channel_video_count && $channel_video_count != NA ]]; then
        [[ $channel_video_count == 1 ]] && printf '1 video\n' || printf '%s videos\n' "$channel_video_count"
      else
        printf 'unknown\n'
      fi
      ;;
    *)
      printf '\n'
      ;;
  esac
}

play_search_source_label() {
  local value
  for value in "$@"; do
    if [[ -n $value && $value != NA ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done
  printf 'NA\n'
}

play_search_lookup_count() {
  local url=$1 result_type=$2 cookie=$3 browser=${4:-} lookup_url count args
  lookup_url=$url
  if [[ $result_type == Channel && $lookup_url != */videos ]]; then
    lookup_url=${lookup_url%/}/videos
  fi

  if [[ $result_type == Playlist ]]; then
    args=("$lookup_url" --flat-playlist --playlist-items 1- --print '%(id)s')
    [[ -n $cookie ]] && args+=(--cookies "$cookie")
    [[ -z $cookie && -n $browser ]] && args+=(--cookies-from-browser "$browser")
    play_debug_command 'yt-dlp playlist count' yt-dlp "${args[@]}"
    if play_debug_enabled; then
      count=$(yt-dlp "${args[@]}" 2>>"$PLAY_DEBUG_LOG_PATH" | wc -l) || return 1
    elif ! count=$(yt-dlp "${args[@]}" 2>/dev/null | wc -l); then
      return 1
    fi
    [[ $count =~ ^[0-9]+$ && $count != 0 ]] || return 1
    printf '%s\n' "$count"
    return 0
  fi

  args=("$lookup_url" --flat-playlist --playlist-end 1 --print $'%(playlist_count)s\t%(channel_video_count)s')
  [[ -n $cookie ]] && args+=(--cookies "$cookie")
  [[ -z $cookie && -n $browser ]] && args+=(--cookies-from-browser "$browser")

  play_debug_command 'yt-dlp channel count' yt-dlp "${args[@]}"
  if play_debug_enabled; then
    count=$(yt-dlp "${args[@]}" 2>>"$PLAY_DEBUG_LOG_PATH" | awk -F '\t' 'NR == 1 { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit } }') || return 1
  elif ! count=$(yt-dlp "${args[@]}" 2>/dev/null | awk -F '\t' 'NR == 1 { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit } }'); then
    return 1
  fi
  [[ -n $count ]] || return 1
  printf '%s\n' "$count"
}

play_search_lookup_source() {
  local url=$1 cookie=$2 browser=${3:-} source args
  args=("$url" --flat-playlist --playlist-end 1 --print $'%(playlist_uploader)s\t%(channel)s\t%(uploader)s\t%(creator)s')
  [[ -n $cookie ]] && args+=(--cookies "$cookie")
  [[ -z $cookie && -n $browser ]] && args+=(--cookies-from-browser "$browser")

  play_debug_command 'yt-dlp source lookup' yt-dlp "${args[@]}"
  if play_debug_enabled; then
    source=$(yt-dlp "${args[@]}" 2>>"$PLAY_DEBUG_LOG_PATH" | awk -F '\t' 'NR == 1 { for (i = 1; i <= NF; i++) if ($i != "" && $i != "NA") { print $i; exit } }') || return 1
  elif ! source=$(yt-dlp "${args[@]}" 2>/dev/null | awk -F '\t' 'NR == 1 { for (i = 1; i <= NF; i++) if ($i != "" && $i != "NA") { print $i; exit } }'); then
    return 1
  fi
  [[ -n $source ]] || return 1
  printf '%s\n' "$source"
}

play_search_youtube() {
  local query=$1 home=$2 playlist=$3 max=$4 cookie=$5 type=$6 browser=${7:-} start=${8:-1} encoded search_url row title id ie url duration uploader channel creator playlist_uploader views playlist_count channel_video_count result_type source count_label
  if play_bool "$home"; then
    search_url='https://www.youtube.com/'
  else
    encoded=$(play_urlencode "$query")
    search_url="https://www.youtube.com/results?search_query=$encoded"
    if play_bool "$playlist" || [[ $type == Playlist ]]; then
      search_url+='&sp=EgIQAw%3D%3D'
    elif [[ $type == Channel ]]; then
      search_url+='&sp=EgIQAg%3D%3D'
    fi
  fi

  local args=("$search_url" --print $'%(title)s\t%(id)s\t%(ie_key)s\t%(webpage_url)s\t%(duration_string)s\t%(channel)s\t%(uploader)s\t%(creator)s\t%(playlist_uploader)s\t%(view_count)s\t%(playlist_count)s\t%(channel_video_count)s' --flat-playlist --playlist-items "$start:$max")
  [[ -n $cookie ]] && args+=(--cookies "$cookie")
  [[ -z $cookie && -n $browser ]] && args+=(--cookies-from-browser "$browser")
  play_debug_log "search url: $search_url"
  play_debug_command 'yt-dlp search' yt-dlp "${args[@]}"

  while IFS= read -r row; do
    IFS=$'\t' read -r title id ie url duration channel uploader creator playlist_uploader views playlist_count channel_video_count <<<"$row"
    [[ -z $title || -z $id || -z $url ]] && continue
    result_type=$(play_search_type "$id" "$ie" "$url")
    [[ -n $type && $type != "$result_type" ]] && continue
    source=$(play_search_source_label "$channel" "$uploader" "$creator" "$playlist_uploader")
    if [[ $result_type == Playlist && ( -z $playlist_count || $playlist_count == NA ) ]]; then
      playlist_count=$(play_search_lookup_count "$url" "$result_type" "$cookie" "$browser" || printf 'NA')
    elif [[ $result_type == Channel && ( -z $channel_video_count || $channel_video_count == NA ) ]]; then
      channel_video_count=$(play_search_lookup_count "$url" "$result_type" "$cookie" "$browser" || printf 'NA')
    fi
    if [[ $result_type == Playlist && $source == NA ]]; then
      source=$(play_search_lookup_source "$url" "$cookie" "$browser" || printf 'NA')
    fi
    count_label=$(play_search_count_label "$result_type" "$playlist_count" "$channel_video_count")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$result_type" "$title" "$url" "$duration" "$source" "$views" "$count_label"
  done < <(if play_debug_enabled; then yt-dlp "${args[@]}" 2>>"$PLAY_DEBUG_LOG_PATH"; else yt-dlp "${args[@]}" 2>/dev/null; fi)
}

play_search_channel_playlists() {
  local channel_url=$1 max=$2 cookie=$3 browser=${4:-} source=${5:-} start=${6:-1} playlists_url row title id ie url duration channel uploader creator playlist_uploader views playlist_count channel_video_count item_source count_label args
  playlists_url=${channel_url%/}/playlists
  args=("$playlists_url" --print $'%(title)s\t%(id)s\t%(ie_key)s\t%(webpage_url)s\t%(duration_string)s\t%(channel)s\t%(uploader)s\t%(creator)s\t%(playlist_uploader)s\t%(view_count)s\t%(playlist_count)s\t%(channel_video_count)s' --flat-playlist --playlist-items "$start:$max")
  [[ -n $cookie ]] && args+=(--cookies "$cookie")
  [[ -z $cookie && -n $browser ]] && args+=(--cookies-from-browser "$browser")
  play_debug_log "channel playlists url: $playlists_url"
  play_debug_command 'yt-dlp channel playlists' yt-dlp "${args[@]}"

  while IFS= read -r row; do
    IFS=$'\t' read -r title id ie url duration channel uploader creator playlist_uploader views playlist_count channel_video_count <<<"$row"
    [[ -z $title || -z $id || -z $url ]] && continue
    item_source=$(play_search_source_label "$channel" "$uploader" "$creator" "$playlist_uploader" "$source")
    [[ -z $playlist_count || $playlist_count == NA ]] && playlist_count=$(play_search_lookup_count "$url" Playlist "$cookie" "$browser" || printf 'NA')
    count_label=$(play_search_count_label Playlist "$playlist_count" NA)
    printf 'Playlist\t%s\t%s\t%s\t%s\t%s\t%s\n' "$title" "$url" "$duration" "$item_source" "$views" "$count_label"
  done < <(if play_debug_enabled; then yt-dlp "${args[@]}" 2>>"$PLAY_DEBUG_LOG_PATH"; else yt-dlp "${args[@]}" 2>/dev/null; fi)
}
