class_name DesktopWindow
extends RefCounted
## Fits the desktop window to the monitor (E9). The design is a tall 540×1170 portrait screen,
## which overflows a 1080p monitor, so a desktop launch shrinks the window to 90% of the usable
## screen height (keeping the aspect, even pixel sizes) and centres it. Phones, headless runs,
## Movie Maker captures and launches with an explicit `--resolution` keep the size they asked
## for: a project-wide window override would have won over `--resolution` and broken the clip
## scripts.
##
## Side effects: resizes and moves the main window. Called once from Session._ready.

const FILL: float = 0.9


static func fit(window: Window) -> void:
	# Movie Maker is detected by its flag: Engine.is_movie_maker_enabled() exists only in editor
	# builds, and an exported game failed to compile with it (B5/E9, 2026-10-01).
	var cmd: PackedStringArray = OS.get_cmdline_args()
	if not OS.has_feature("pc") or DisplayServer.get_name() == "headless" \
			or cmd.has("--write-movie") or cmd.has("--resolution"):
		return
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	if usable.size.y <= 0 or window.size.y <= usable.size.y * FILL:
		return
	var k: float = usable.size.y * FILL / window.size.y
	var size := Vector2i(roundi(window.size.x * k / 2.0) * 2, roundi(window.size.y * k / 2.0) * 2)
	window.size = size
	window.position = usable.position + (usable.size - size) / 2
