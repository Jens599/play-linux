# play-linux

A fast, resource-light Linux Bash port of the `play` portion of `Start-MPVStream`.

It plays direct URLs with `mpv`, searches YouTube with `yt-dlp`, keeps persistent config, and stores lightweight playback history.

## Requirements

Required:

- `bash`
- `mpv`
- `yt-dlp`

Optional:

- `fzf` for interactive selection
- `wl-clipboard`, `xclip`, or `xsel` for clipboard support
- `xdg-open` for `--open`

## Install

```bash
./setup.sh
```

This symlinks `bin/play` into `${HOME}/.local/bin/play` by default.

## Config

Config is stored at:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/play/config
```

History is stored at:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/play/history.tsv
```

Commands:

```bash
play --config
play --config-path
play --set YTDL_FORMAT=720p
play --get YTDL_FORMAT
play --config-export backup.conf
play --config-import backup.conf
```

## Examples

```bash
play 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
play -s 'never gonna give you up'
play -s 'lofi beats' --first --format audio
play -s 'live coding' --type playlist
play --clipboard
play --history
play --last
play --dry-run --pass-thru 'https://example.test/video'
play --doctor
```

## Preserved Configuration

The config keeps the important mpv and `yt-dlp` knobs from the original project:

- player command
- menu provider
- cookie path
- size and format presets
- audio/background/loop/hardware acceleration flags
- subtitle preferences
- reverse playlist handling
- `yt-dlp` video selector, codec filter, max height, audio selector, fallback selector
- generated mpv command overrides

Windows-only behavior from the original project is intentionally omitted.
