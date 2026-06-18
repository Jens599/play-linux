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
      [[ -n $playlist_count && $playlist_count != NA ]] && printf '%s items\n' "$playlist_count" || printf '\n'
      ;;
    Channel)
      [[ -n $channel_video_count && $channel_video_count != NA ]] && printf '%s videos\n' "$channel_video_count" || printf '\n'
      ;;
    *)
      printf '\n'
      ;;
  esac
}

play_search_youtube() {
  local query=$1 home=$2 playlist=$3 max=$4 cookie=$5 type=$6 encoded search_url row title id ie url duration uploader views playlist_count channel_video_count result_type count_label
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

  local args=("$search_url" --print $'%(title)s\t%(id)s\t%(ie_key)s\t%(webpage_url)s\t%(duration_string)s\t%(uploader)s\t%(view_count)s\t%(playlist_count)s\t%(channel_video_count)s' --flat-playlist --playlist-items "1:$max")
  [[ -n $cookie ]] && args+=(--cookies "$cookie")

  while IFS= read -r row; do
    IFS=$'\t' read -r title id ie url duration uploader views playlist_count channel_video_count <<<"$row"
    [[ -z $title || -z $id || -z $url ]] && continue
    result_type=$(play_search_type "$id" "$ie" "$url")
    [[ -n $type && $type != "$result_type" ]] && continue
    count_label=$(play_search_count_label "$result_type" "$playlist_count" "$channel_video_count")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$result_type" "$title" "$url" "$duration" "$uploader" "$views" "$count_label"
  done < <(yt-dlp "${args[@]}")
}
