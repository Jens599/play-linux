#!/usr/bin/env bash

play_clipboard_get() {
  if play_has wl-paste; then wl-paste --no-newline; return; fi
  if play_has xclip; then xclip -selection clipboard -o; return; fi
  if play_has xsel; then xsel --clipboard --output; return; fi
  printf 'No clipboard reader found: install wl-clipboard, xclip, or xsel.\n' >&2
  return 1
}

play_clipboard_set() {
  local value=$1
  if play_has wl-copy; then printf '%s' "$value" | wl-copy; return; fi
  if play_has xclip; then printf '%s' "$value" | xclip -selection clipboard; return; fi
  if play_has xsel; then printf '%s' "$value" | xsel --clipboard --input; return; fi
  printf 'No clipboard writer found: install wl-clipboard, xclip, or xsel.\n' >&2
  return 1
}
