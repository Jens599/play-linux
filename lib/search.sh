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

play_search_youtube() {
  local query=$1 home=$2 playlist=$3 max=$4 cookie=$5 type=$6 encoded search_url row title id ie url duration uploader views result_type
  if play_bool "$home"; then
    search_url='https://www.youtube.com/'
  else
    encoded=$(play_urlencode "$query")
    search_url="https://www.youtube.com/results?search_query=$encoded"
    play_bool "$playlist" && search_url+='&sp=EgIQAw%3D%3D'
  fi

  local args=("$search_url" --print $'%(title)s\t%(id)s\t%(ie_key)s\t%(webpage_url)s\t%(duration_string)s\t%(uploader)s\t%(view_count)s' --flat-playlist --playlist-items "1:$max")
  [[ -n $cookie ]] && args+=(--cookies "$cookie")

  while IFS= read -r row; do
    IFS=$'\t' read -r title id ie url duration uploader views <<<"$row"
    [[ -z $title || -z $id || -z $url ]] && continue
    result_type=$(play_search_type "$id" "$ie" "$url")
    [[ -n $type && $type != "$result_type" ]] && continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$result_type" "$title" "$url" "$duration" "$uploader" "$views"
  done < <(yt-dlp "${args[@]}")
}
