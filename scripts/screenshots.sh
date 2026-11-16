#!/usr/bin/env bash
# Take one screenshot of the bar per preset into .github/assets/<preset>.png.
#
# Needs KDE Plasma (spectacle) and wezterm; oxipng is used when installed.
# Run it from a session you leave alone: each shot opens a window that must
# keep the focus until it is captured.
#
#   scripts/screenshots.sh                 # every preset
#   scripts/screenshots.sh pure bubbles    # only these
#
# Settings (environment): MOSAIC_SCHEME (default "Catppuccin Mocha"),
# MOSAIC_FONT_SIZE (16), MOSAIC_COLS (140), MOSAIC_CWD (home), MOSAIC_DELAY (seconds to wait for the window, default 5)
# the window, default 3).
#
# The shot is the bar row of the window at its real pixel size (the window is
# the bar plus one row, so the bar is its top half). Large text keeps it sharp when
# the readme shows it at half width (`<img width="830">`).
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
out="$repo/.github/assets"
delay=${MOSAIC_DELAY:-5}

for tool in wezterm spectacle; do
  command -v "$tool" >/dev/null || { echo "missing: $tool" >&2; exit 1; }
done

if [ $# -gt 0 ]; then
  presets=("$@")
else
  mapfile -t presets < <(cd "$repo/plugin/mosaic/presets" && ls -- *.lua | sed 's/\.lua$//')
fi

mkdir -p "$out"
export MOSAIC_REPO="$repo"

for preset in "${presets[@]}"; do
  export MOSAIC_PRESET="$preset"
  tmp=$(mktemp --suffix=.png)
  trap 'rm -f "$tmp"' EXIT
  ok=
  for attempt in 1 2 3; do
    wezterm --config-file "$repo/scripts/screenshot.lua" start --always-new-process &
    pid=$!
    sleep "$delay"
    spectacle --activewindow --background --nonotify --output "$tmp"
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    # The window is the bar plus one row: a wide strip. Anything taller is some
    # other window that had the focus (KDE may refuse it to the new one), so
    # it is dropped without being kept.
    read -r w h <<<"$(magick identify -format '%w %h' "$tmp")"
    if [ $((h * 20)) -lt "$w" ]; then
      ok=1
      break
    fi
    echo "$preset: wrong window captured (attempt $attempt), retrying" >&2
  done
  [ -n "$ok" ] || { echo "$preset: never got the focus; click away and rerun" >&2; exit 1; }
  magick "$tmp" -gravity North -crop 100%x50%+0+0 +repage "$out/$preset.png"
  command -v oxipng >/dev/null && oxipng -q -o4 --strip all "$out/$preset.png"
  echo "$out/$preset.png"
done
