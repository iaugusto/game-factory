# Source this (don't run it): `source scripts/android_env.sh`.
#
# Points the Android toolchain at the repo-local, git-ignored .tools/ (B5). Nothing writes to
# $HOME: the SDK's and adb's state (adb's pairing keys included) go to .tools/android-home, and
# Java's user prefs to .tools/java-prefs. Godot exports through the self-contained copy in
# .tools/godot-export (its `_sc_` marker keeps editor settings and export templates beside it,
# not in ~/.config or ~/.local). Debug signing comes from the env vars Godot reads, so the
# export preset carries no keystore path or password.
#
# adb ignores ANDROID_USER_HOME and always keeps its key pair in $HOME/.android, so $ADB is a
# wrapper (.tools/bin/adb) that runs it with HOME=.tools/android-home; build_android.sh does the
# same for the Godot export, whose device probe starts adb.
#
# Exports: ROOT, JAVA_HOME, ANDROID_HOME, ANDROID_USER_HOME, JAVA_TOOL_OPTIONS,
# GODOT_EXPORT_BIN, ADB, GODOT_ANDROID_KEYSTORE_DEBUG_{PATH,USER,PASSWORD}; prepends .tools/bin (the adb wrapper)
# and the JDK to PATH.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
export JAVA_HOME="$ROOT/.tools/jdk"
export ANDROID_HOME="$ROOT/.tools/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$ROOT/.tools/android-home"
export JAVA_TOOL_OPTIONS="-Duser.home=$ROOT/.tools/android-home -Djava.util.prefs.userRoot=$ROOT/.tools/java-prefs"
export GODOT_EXPORT_BIN="$ROOT/.tools/godot-export/godot"
export ADB="$ROOT/.tools/bin/adb"
# Android's standard debug key (androiddebugkey / android): a throwaway, never a release key.
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$ROOT/.tools/keystores/debug.keystore"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
export PATH="$ROOT/.tools/bin:$JAVA_HOME/bin:$PATH"
mkdir -p "$ANDROID_USER_HOME" "$ROOT/.tools/java-prefs" "$ROOT/.tools/bin"
if [[ ! -x "$ADB" ]]; then
  printf '#!/usr/bin/env bash\nHOME="%s" exec "%s" "$@"\n' "$ANDROID_USER_HOME" \
    "$ANDROID_HOME/platform-tools/adb" > "$ADB"
  chmod +x "$ADB"
fi

# Make sure a phone is connected: a Godot export restarts the adb server, which drops a
# wireless connection, so reconnect to the last address (`adb connect IP:PORT` once, then
# save it: echo IP:PORT > .tools/android-home/last_device). Returns nonzero with no device.
adb_ensure() {
  "$ADB" get-state >/dev/null 2>&1 && return 0
  local last="$ANDROID_USER_HOME/last_device"
  [[ -f "$last" ]] && "$ADB" connect "$(cat "$last")" >/dev/null 2>&1
  "$ADB" get-state >/dev/null 2>&1
}
