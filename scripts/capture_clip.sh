#!/usr/bin/env bash
# Record gameplay with Godot's Movie Maker (every frame rendered at a fixed 60 fps, no real-time
# pressure), then convert to H.264 MP4 if ffmpeg is available.
#
#   scripts/capture_clip.sh NAME SECONDS [game args...]
#   e.g. scripts/capture_clip.sh gate-hook 15 --seed=3 --autoplay --skip=2
#
# Needs a display (WSLg works; headless can't render). Output: captures/NAME.mp4, or
# captures/NAME.avi when no ffmpeg is found. ffmpeg comes from $FFMPEG_BIN, then PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
NAME="${1:?name}"; SECONDS_LONG="${2:?seconds}"; shift 2
FPS=60
OUT_DIR="$ROOT/captures"
mkdir -p "$OUT_DIR"
AVI="$OUT_DIR/$NAME.avi"

"$GODOT_BIN" --path "$ROOT/game" --write-movie "$AVI" --fixed-fps "$FPS" \
  --resolution 540x960 --quit-after $(( SECONDS_LONG * FPS )) -- "$@" >/dev/null

FFMPEG="${FFMPEG_BIN:-$(command -v ffmpeg || true)}"
if [[ -n "$FFMPEG" && -x "$FFMPEG" ]]; then
  "$FFMPEG" -loglevel error -y -i "$AVI" -c:v libx264 -pix_fmt yuv420p -crf 20 -an \
    "$OUT_DIR/$NAME.mp4"
  rm -f "$AVI"
  echo "$OUT_DIR/$NAME.mp4"
else
  echo "$AVI (no ffmpeg found; set FFMPEG_BIN to convert to mp4)"
fi
