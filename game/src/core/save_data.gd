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
##   v5 — {version, campaign: {best: {map: stars}, cleared: [maps], consoled: [maps]},
##        tree: {owned: [skill ids]}, stats, legacy: {bricks, levels}}. Bricks and the six
##        brick upgrades were retired for the campaign's stars and skill tree (2026-09-27
##        sectors work item). Their balance and levels move to `legacy` verbatim: kept on file,
##        not converted, because tree nodes have prerequisites and star prices with no brick
##        equivalent. (No v4 save was ever written by a shipped build: nothing called save_to.)
##   v6 — v5 plus tips: {seen: [tip keys], off: bool}. Contextual tips (2026-09-27 style and
##        tutorials work item) remember which ones the player has read. A v5 save starts with
##        none seen, so an existing player sees each tip once.
##   v7 — v6 plus abilities: {last: ability id}. The special attack picked when a map starts
##        (2026-09-27 content expansion) is remembered as the next default. Which attacks are
##        unlocked is not stored: it follows from campaign.cleared (Campaign.ability_unlocked),
##        so it can't drift. A v6 save starts on the strike, the only attack it knew.

const CURRENT_VERSION: int = 7
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

var campaign := Campaign.new()
var tree := SkillTree.new()
## The retired brick meta, as found in a v4 save ({bricks, levels}); empty for new saves.
var legacy: Dictionary = {}
var runs: int = 0
var wins: int = 0
var best_wave: int = 0
## Tips read (TipDirector.Pending.key -> true), and whether the player turned tips off.
var tips_seen: Dictionary = {}
var tips_off: bool = false
## The special attack picked last (the pick panel's default next time).
var last_ability: StringName = &"strike"
## Set by load_from() when the file existed but could not be used; empty otherwise.
var load_warning: String = ""


## Record a finished run on `map_id` (stats and campaign stars). Returns Campaign.record's
## result.
func record_result(map_id: StringName, won: bool, waves_cleared: int, gate_fraction: float,
		cfg: RunConfig) -> Dictionary:
	runs += 1
	wins += 1 if won else 0
	best_wave = maxi(best_wave, waves_cleared)
	return campaign.record(map_id, won, waves_cleared, gate_fraction, cfg)


## Stars left to spend in the tree.
func stars_free(skill_tree: SkillTreeDef) -> int:
	return campaign.stars_total() - tree.spent(skill_tree)


func to_dict() -> Dictionary:
	var best: Dictionary = {}
	for key: StringName in campaign.best:
		best[String(key)] = campaign.best[key]
	var d: Dictionary = {
		"version": CURRENT_VERSION,
		"campaign": {"best": best, "cleared": _ids(campaign.cleared),
				"consoled": _ids(campaign.consoled)},
		"tree": {"owned": _ids(tree.owned)},
		"stats": {"runs": runs, "wins": wins, "best_wave": best_wave},
		"tips": {"seen": _keys(tips_seen), "off": tips_off},
		"abilities": {"last": String(last_ability)},
	}
	if not legacy.is_empty():
		d["legacy"] = legacy.duplicate(true)
	return d


static func _keys(key_set: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: Variant in key_set:
		out.append(str(key))
	out.sort()
	return out


static func _ids(id_set: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: StringName in id_set:
		out.append(String(key))
	out.sort()
	return out


## Build from a dictionary of any known version. Returns null if the version is unknown or
## newer than this build understands.
static func from_dict(data: Dictionary) -> SaveData:
	var migrated: Variant = migrate(data)
	if migrated == null:
		return null
	var d: Dictionary = migrated
	var save := SaveData.new()
	var camp: Dictionary = d.get("campaign", {})
	var best: Dictionary = camp.get("best", {})
	for key: String in best:
		save.campaign.best[StringName(key)] = int(best[key])
	for id: Variant in camp.get("cleared", []):
		save.campaign.cleared[StringName(str(id))] = true
	for id: Variant in camp.get("consoled", []):
		save.campaign.consoled[StringName(str(id))] = true
	for id: Variant in d.get("tree", {}).get("owned", []):
		save.tree.owned[StringName(str(id))] = true
	var stats: Dictionary = d.get("stats", {})
	save.runs = int(stats.get("runs", 0))
	save.wins = int(stats.get("wins", 0))
	save.best_wave = int(stats.get("best_wave", 0))
	save.legacy = d.get("legacy", {})
	var tips: Dictionary = d.get("tips", {})
	for key: Variant in tips.get("seen", []):
		save.tips_seen[str(key)] = true
	save.tips_off = bool(tips.get("off", false))
	save.last_ability = StringName(str(d.get("abilities", {}).get("last", "strike")))
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
			4:
				d = _v4_to_v5(d)
			5:
				d["tips"] = {"seen": [], "off": false}
				d["version"] = 6
			6:
				d["abilities"] = {"last": "strike"}
				d["version"] = 7
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


## Bricks are retired: the old meta moves to `legacy` verbatim; campaign and tree start empty.
static func _v4_to_v5(d: Dictionary) -> Dictionary:
	var meta_d: Dictionary = d.get("meta", {})
	return {
		"version": 5,
		"campaign": {"best": {}, "cleared": [], "consoled": []},
		"tree": {"owned": []},
		"stats": d.get("stats", {"runs": 0, "wins": 0, "best_wave": 0}),
		"legacy": {"bricks": int(meta_d.get("bricks", 0)), "levels": meta_d.get("levels", {})},
	}


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
