#!/usr/bin/env bash
# Measure one run of the installed debug APK on the connected phone (B5).
#
# Usage: scripts/android_perf.sh NAME SECONDS [GAME_FLAGS...]
#   e.g. scripts/android_perf.sh stress-mobile 40 --autoplay --stress --perf
# Env:
#   (the renderer is whatever the installed APK was built with: build_android.sh --renderer)
#   CLIP=1       also screen-record the first min(SECONDS,30) s to captures/NAME.mp4
#
# GAME_FLAGS reach the game through user://launch_args.txt (LaunchArgs: Godot 4.7's activity
# drops intent extras), written with `adb run-as` and always deleted on exit, so hand-played
# runs afterwards see no flags. Launches cold (force-stop first) with `am start -W`, waits
# SECONDS, then
# collects the game's PERF lines from logcat, memory (dumpsys meminfo), thermal status and the
# device identity into captures/perf/NAME.txt (git-ignored), and prints a short summary.
# Install the APK first: scripts/build_android.sh --install.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/android_env.sh"
[[ $# -ge 2 ]] || { sed -n 2,16p "$0"; exit 2; }
NAME="$1"; SECONDS_TO_RUN="$2"; shift 2
PACKAGE="dev.holdthegate.debug"
OUT_DIR="$ROOT/captures/perf"
OUT="$OUT_DIR/$NAME.txt"
mkdir -p "$OUT_DIR"

PARAMS="$*"

adb_ensure || { echo "no device: pair and connect first (plan.md § setup)" >&2; exit 2; }
"$ADB" shell am force-stop "$PACKAGE"
"$ADB" shell "run-as $PACKAGE sh -c 'mkdir -p files && echo \"$PARAMS\" > files/launch_args.txt'"
# If the phone drops off (screen lock, Wi-Fi), the rm can't run and the next hand launch would
# replay these flags: say so loudly (fix: adb connect, then run-as … rm -f files/launch_args.txt).
trap '"$ADB" shell "run-as $PACKAGE rm -f files/launch_args.txt" 2>/dev/null \
  || echo "WARNING: launch_args.txt is still on the phone; remove it before playing" >&2' EXIT
"$ADB" logcat -c
START="$("$ADB" shell am start -W -n "$PACKAGE/com.godot.game.GodotAppLauncher")"
if [[ "${CLIP:-0}" == 1 ]]; then
  CLIP_S=$(( SECONDS_TO_RUN < 30 ? SECONDS_TO_RUN : 30 ))
  "$ADB" shell screenrecord --time-limit "$CLIP_S" "/sdcard/Download/$NAME.mp4" &
  REC_PID=$!
fi
sleep "$SECONDS_TO_RUN"
if [[ "${CLIP:-0}" == 1 ]]; then
  wait "$REC_PID" || true
  "$ADB" pull "/sdcard/Download/$NAME.mp4" "$ROOT/captures/$NAME.mp4" >/dev/null
  "$ADB" shell rm "/sdcard/Download/$NAME.mp4"
fi
MEM="$("$ADB" shell dumpsys meminfo "$PACKAGE")"
{
  echo "# $NAME — $(date -Iseconds)"
  echo "params: $PARAMS"
  echo "device: $("$ADB" shell getprop ro.product.model) / soc $("$ADB" shell getprop ro.soc.model) / android $("$ADB" shell getprop ro.build.version.release)"
  echo "display: $("$ADB" shell dumpsys display | grep -m1 -o 'renderFrameRate [0-9.]*' || true)"
  echo
  echo "## start"
  echo "$START" | grep -E "Status|TotalTime|WaitTime" || true
  echo
  echo "## perf (logcat)"
  "$ADB" logcat -d -s godot:I | grep -E "PERF|run seed|ERROR|Vulkan|OpenGL|Rendering" || true
  echo
  echo "## memory"
  echo "$MEM" | grep -E "TOTAL PSS|TOTAL RSS|Native Heap|Graphics|GL mtrack|EGL mtrack" || true
  echo
  echo "## thermal"
  "$ADB" shell dumpsys thermalservice | grep -E "Thermal Status|mType=3" | head -6 || true
} > "$OUT"
"$ADB" shell am force-stop "$PACKAGE"
echo "wrote $OUT"
grep -E "TotalTime|PERF|TOTAL PSS" "$OUT" | tail -8
