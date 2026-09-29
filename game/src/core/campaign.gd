class_name Campaign
extends RefCounted
## Campaign progress across sectors (the maps of RunConfig.maps, in order): the best stars per
## sector, which sectors were won, and which gave their one consolation star.
##
## Stars (docs/2026-09-27-sectors-and-skill-tree/): 1 for a win, +1 per threshold of
## RunConfig.star_thresholds the gate's remaining HP fraction reaches (≥ 50%, ≥ 90%). A loss
## that cleared config.consolation_waves waves of a sector never won grants that sector's first
## star, once, so a player is never hard-stuck; it doesn't unlock the next sector.

## map id -> best stars earned there (0..3).
var best: Dictionary[StringName, int] = {}
## map ids won at least once (unlocks the next sector).
var cleared: Dictionary[StringName, bool] = {}
## map ids whose consolation star was granted.
var consoled: Dictionary[StringName, bool] = {}


## Stars a finished run is worth: 0 for a loss; for a win 1 + one per threshold met.
static func stars_for(won: bool, gate_fraction: float, thresholds: PackedFloat32Array) -> int:
	if not won:
		return 0
	var stars: int = 1
	for t: float in thresholds:
		if gate_fraction >= t - 1e-6:
			stars += 1
	return stars


func stars_at(map_id: StringName) -> int:
	return best.get(map_id, 0)


func stars_total() -> int:
	var n: int = 0
	for id: StringName in best:
		n += best[id]
	return n


## Sector `index` of `maps` is open: the first always, then each once the one before is won.
func is_unlocked(maps: Array[MapDef], index: int) -> bool:
	if index <= 0:
		return true
	if index >= maps.size():
		return false
	return cleared.has(maps[index - 1].id)


## Special attacks unlock with sectors: `a` is available once the map it names
## (AbilityDef.unlocked_by) has been won, or from the start if it names none.
func ability_unlocked(a: AbilityDef) -> bool:
	return a.unlocked_by == &"" or cleared.has(a.unlocked_by)


## The special attacks of `cfg` the player can pick, in the config's order.
func abilities_unlocked(cfg: RunConfig) -> Array[AbilityDef]:
	var out: Array[AbilityDef] = []
	for a: AbilityDef in cfg.abilities:
		if ability_unlocked(a):
			out.append(a)
	return out


## Record a finished run on `map_id`. Returns {stars (this run), gained (new stars in total),
## new_best, consolation}.
func record(map_id: StringName, won: bool, waves_cleared: int, gate_fraction: float,
		cfg: RunConfig) -> Dictionary:
	var stars: int = stars_for(won, gate_fraction, cfg.star_thresholds)
	var consolation: bool = false
	if not won and not cleared.has(map_id) and not consoled.has(map_id) \
			and waves_cleared >= cfg.consolation_waves:
		consoled[map_id] = true
		consolation = true
		stars = 1
	var before: int = stars_at(map_id)
	if won:
		cleared[map_id] = true
	if stars > before:
		best[map_id] = stars
	return {"stars": stars, "gained": maxi(0, stars - before), "new_best": stars > before,
			"consolation": consolation}
