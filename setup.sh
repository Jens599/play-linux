#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX=${PREFIX:-$HOME/.local}
BIN_DIR=${BIN_DIR:-$PREFIX/bin}

mkdir -p "$BIN_DIR"
ln -sf "$ROOT/bin/play" "$BIN_DIR/play"
"$ROOT/bin/play" --config-path >/dev/null

cat <<EOF
Installed play symlink:
  $BIN_DIR/play -> $ROOT/bin/play

Make sure this directory is in PATH:
  $BIN_DIR

Required runtime dependencies:
  mpv yt-dlp

Optional dependencies:
  socat fzf wl-clipboard xclip xsel xdg-utils

Arch install command:
  sudo pacman -S mpv yt-dlp socat fzf xdg-utils

Clipboard providers:
  sudo pacman -S wl-clipboard  # Wayland
  sudo pacman -S xclip         # X11
EOF
