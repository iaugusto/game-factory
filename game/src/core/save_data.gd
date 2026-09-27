class_name SaveData
extends RefCounted
## The player's persistent data, versioned. Old saves are migrated forward one version at a
## time; they are never silently reset (CLAUDE.md §4). A save that cannot be read is moved
## aside as "<path>.bad" before a fresh one is started, so nothing is lost without a trace.
##
## Schema history:
##   v1 — {version, bricks, meta: {upgrade_id: level}}. Synthetic: defined in B1 only so the
##        migration chain is exercised by a real test before anything ships.
##   v2 — {version, meta: {bricks, levels}, stats: {runs, wins, best_wave}}.
##   v3 — same shape. The gates were removed (2026-09-25 build-spots work item), and with them
##        the meta upgrades "gate_lore" and "fifth_slot". Their levels are refunded as the
##        bricks they cost (REMOVED_META_COSTS), never silently dropped.
##   v4 — same shape. The aimed squad was removed (2026-09-26 fixed-units work item), and with
##        it the meta upgrade "recruits" (+1 starting shooter). Refunded the same way
##        (REMOVED_META_COSTS_V4).

const CURRENT_VERSION: int = 4
## Brick prices per level of meta upgrades that no longer exist, for the v3 refund. Historical
## data: never edit an entry once a version that shipped it exists.
const REMOVED_META_COSTS: Dictionary = {
	"gate_lore": [15, 35, 70],
	"fifth_slot": [60],
}
## The same, for the v4 refund.
const REMOVED_META_COSTS_V4: Dictionary = {
	"recruits": [5, 10, 20, 35, 55],
}
const DEFAULT_PATH: String = "user://save.json"

var meta := MetaProgress.new()
var runs: int = 0
var wins: int = 0
var best_wave: int = 0
## Set by load_from() when the file existed but could not be used; empty otherwise.
var load_warning: String = ""


## Record a finished run and bank its bricks.
func record_run(waves_cleared: int, won: bool, bricks: int) -> void:
	runs += 1
	wins += 1 if won else 0
	best_wave = maxi(best_wave, waves_cleared)
	meta.bricks += bricks


func to_dict() -> Dictionary:
	var levels: Dictionary = {}
	for key: StringName in meta.levels:
		levels[String(key)] = meta.levels[key]
	return {
		"version": CURRENT_VERSION,
		"meta": {"bricks": meta.bricks, "levels": levels},
		"stats": {"runs": runs, "wins": wins, "best_wave": best_wave},
	}


## Build from a dictionary of any known version. Returns null if the version is unknown or
## newer than this build understands.
static func from_dict(data: Dictionary) -> SaveData:
	var migrated: Variant = migrate(data)
	if migrated == null:
		return null
	var d: Dictionary = migrated
	var save := SaveData.new()
	var meta_d: Dictionary = d.get("meta", {})
	save.meta.bricks = int(meta_d.get("bricks", 0))
	var levels: Dictionary = meta_d.get("levels", {})
	for key: String in levels:
		save.meta.levels[StringName(key)] = int(levels[key])
	var stats: Dictionary = d.get("stats", {})
	save.runs = int(stats.get("runs", 0))
	save.wins = int(stats.get("wins", 0))
	save.best_wave = int(stats.get("best_wave", 0))
	return save


## Walk `data` forward to CURRENT_VERSION. Returns null for a missing, unknown or future
## version.
static func migrate(data: Dictionary) -> Variant:
	if not data.has("version"):
		return null
	var d: Dictionary = data.duplicate(true)
	var version: int = int(d["version"])
	if version < 1 or version > CURRENT_VERSION:
		return null
	while version < CURRENT_VERSION:
		match version:
			1:
				d = _v1_to_v2(d)
			2:
				d = _v2_to_v3(d)
			3:
				d = _refund_removed(d, REMOVED_META_COSTS_V4, 4)
		version = int(d["version"])
	return d


static func _v1_to_v2(d: Dictionary) -> Dictionary:
	return {
		"version": 2,
		"meta": {"bricks": int(d.get("bricks", 0)), "levels": d.get("meta", {})},
		"stats": {"runs": 0, "wins": 0, "best_wave": 0},
	}


static func _v2_to_v3(d: Dictionary) -> Dictionary:
	return _refund_removed(d, REMOVED_META_COSTS, 3)


## Refund the levels of removed meta upgrades (`removed`: id -> brick price per level) as
## bricks, drop them, and stamp `new_version`.
static func _refund_removed(d: Dictionary, removed: Dictionary, new_version: int) -> Dictionary:
	var meta_d: Dictionary = d.get("meta", {})
	var levels: Dictionary = meta_d.get("levels", {})
	var bricks: int = int(meta_d.get("bricks", 0))
	for id: String in removed:
		if not levels.has(id):
			continue
		var costs: Array = removed[id]
		for i: int in mini(int(levels[id]), costs.size()):
			bricks += int(costs[i])
		levels.erase(id)
	meta_d["bricks"] = bricks
	meta_d["levels"] = levels
	d["meta"] = meta_d
	d["version"] = new_version
	return d


## Write atomically: a temp file first, then a rename, so a crash mid-write never leaves a
## truncated save behind.
func save_to(path: String = DEFAULT_PATH) -> Error:
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t", true))
	f.close()
	return DirAccess.rename_absolute(tmp, path)


## Load `path`. A missing file gives a fresh save (first launch). An unreadable one is moved
## to "<path>.bad" and a fresh save is returned with `load_warning` set.
static func load_from(path: String = DEFAULT_PATH) -> SaveData:
	if not FileAccess.file_exists(path):
		return SaveData.new()
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	var save: SaveData = null
	if parsed is Dictionary:
		save = from_dict(parsed)
	if save != null:
		return save
	DirAccess.rename_absolute(path, path + ".bad")
	var fresh := SaveData.new()
	fresh.load_warning = "Save at %s was unreadable; moved to %s.bad" % [path, path]
	push_warning(fresh.load_warning)
	return fresh
