#!/usr/bin/env bash
# Export a debug APK of the game (B5) and, with --install, put it on the paired phone.
#
# Usage: scripts/build_android.sh [--renderer=compat] [--install] [--launch]
#   --renderer=compat  build with the Compatibility (GLES3) renderer instead of the project's
#                    Mobile one (the B5 A/B): a game/override.cfg is written for the export
#                    only (the preset includes it) and deleted afterwards
#   --install        adb install -r the APK on the one connected device (pair it first:
#                    `source scripts/android_env.sh && adb pair IP:PORT CODE && adb connect IP:PORT`)
#   --launch         then start the game as a player would (no flags; for measured runs with
#                    flags use scripts/android_perf.sh)
#
# Uses the repo-local toolchain only (scripts/android_env.sh). Output:
# builds/android/hold-the-gate-debug.apk (git-ignored). Exit code is nonzero on failure.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/android_env.sh"
PACKAGE="dev.holdthegate.debug"
APK="$ROOT/builds/android/hold-the-gate-debug.apk"
INSTALL=0
LAUNCH=0
RENDERER=""
for a in "$@"; do
  case "$a" in
    --install) INSTALL=1 ;;
    --launch) LAUNCH=1 ;;
    --renderer=compat) RENDERER=compat ;;
    *) echo "unknown argument: $a" >&2; exit 2 ;;
  esac
done

for f in "$GODOT_EXPORT_BIN" "$JAVA_HOME/bin/java" "$ANDROID_HOME/platform-tools/adb" "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH"; do
  [[ -e "$f" ]] || { echo "missing $f (see docs/2026-10-01-b5-android-build/plan.md § setup)" >&2; exit 2; }
done

# The export editor is self-contained, so point its settings at the repo-local SDK and JDK.
SETTINGS_DIR="$ROOT/.tools/godot-export/editor_data"
SETTINGS="$SETTINGS_DIR/editor_settings-4.7.tres"
mkdir -p "$SETTINGS_DIR"
if [[ ! -f "$SETTINGS" ]] || ! grep -q "android_sdk_path" "$SETTINGS"; then
  cat > "$SETTINGS" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "$JAVA_HOME"
export/android/android_sdk_path = "$ANDROID_HOME"
EOF
fi

mkdir -p "$(dirname "$APK")"
cd "$ROOT/game"
if [[ "$RENDERER" == compat ]]; then
  trap 'rm -f "$ROOT/game/override.cfg"' EXIT
  printf '[rendering]\n\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n' \
    > "$ROOT/game/override.cfg"
fi
HOME="$ANDROID_USER_HOME" "$GODOT_EXPORT_BIN" --headless --path . --import >/dev/null 2>&1 || true
HOME="$ANDROID_USER_HOME" "$GODOT_EXPORT_BIN" --headless --path . --export-debug "Android" "$APK"
[[ -f "$APK" ]] || { echo "export produced no APK" >&2; exit 1; }
echo "APK: $APK ($(du -h "$APK" | cut -f1))"

if [[ $INSTALL == 1 || $LAUNCH == 1 ]]; then
  adb_ensure || { echo "no device: pair and connect first (plan.md § setup)" >&2; exit 2; }
fi
if [[ $INSTALL == 1 ]]; then
  "$ADB" install -r "$APK"
fi
if [[ $LAUNCH == 1 ]]; then
  "$ADB" shell am force-stop "$PACKAGE" || true
  "$ADB" shell am start -n "$PACKAGE/com.godot.game.GodotAppLauncher"
fi
