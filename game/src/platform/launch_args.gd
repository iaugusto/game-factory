class_name LaunchArgs
extends RefCounted
## The game's launch flags (the user args after `--`), from wherever the platform delivers them.
##
## Desktop: OS.get_cmdline_user_args(). Android debug builds: Godot 4.7's activity drops the
## launch intent's `command_line_params` extra (B5, 2026-10-01), so dev runs on a phone (perf
## captures, autoplay) put their flags, whitespace-separated, in user://launch_args.txt instead;
## scripts/android_perf.sh writes it with `adb run-as` and deletes it afterwards. Release builds
## never read the file, so a player can't hit DEV ONLY flags.
##
## Output: the flags as a PackedStringArray (empty when there are none). No side effects.

const ANDROID_FILE: String = "user://launch_args.txt"


static func get_args() -> PackedStringArray:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() and OS.has_feature("android") and OS.is_debug_build() \
			and FileAccess.file_exists(ANDROID_FILE):
		args = parse(FileAccess.get_file_as_string(ANDROID_FILE))
	return args


## Splits a launch_args.txt body into flags (spaces, tabs and newlines separate them).
static func parse(text: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for part: String in text.replace("\n", " ").replace("\t", " ").split(" ", false):
		out.append(part)
	return out
