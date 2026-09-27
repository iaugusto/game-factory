#!/usr/bin/env bash
# Run the whole GdUnit4 suite headless. Exit code is nonzero on any failure.
#
# Godot comes from $GODOT_BIN, falling back to the repo-local .tools/godot binary (ROADMAP B0).
# An import pass runs first so the global class cache (class_name, GdUnit4) exists on a fresh
# checkout, where .godot/ is absent.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot not found at $GODOT_BIN (set GODOT_BIN or see ROADMAP.md B0)." >&2
  exit 2
fi

cd "$ROOT/game"
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT_BIN" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests "$@"
