class_name Synergies
extends RefCounted
## Unit links: two built units whose pads are within RunConfig.synergy_range of each other
## boost each other, with one named effect per pair of unit types (SynergyDef). Recomputed
## when a unit is built, sold or destroyed, never per tick: CombatSim reads each plot's summed
## `syn` in its stat functions (docs/2026-09-27-artillery-and-synergies/).


## The synergy between unit types `a` and `b` (either order), or null.
static func find(cfg: RunConfig, a: StringName, b: StringName) -> SynergyDef:
	for s: SynergyDef in cfg.synergies:
		if s.involves(a, b):
			return s
	return null


## Refill every plot's `syn` (summed bonuses) and `links` ([other plot index, SynergyDef]).
## A plot gets each distinct synergy once, however many partners of that type are in range.
static func compute(plots: Array[CombatSim.Plot], cfg: RunConfig) -> void:
	var got: Array[Dictionary] = []
	for p: CombatSim.Plot in plots:
		p.syn = StatBonus.new()
		p.links = []
		got.append({})
	var r2: float = cfg.synergy_range * cfg.synergy_range
	for i: int in plots.size():
		var a: CombatSim.Plot = plots[i]
		if a.is_empty():
			continue
		for j: int in range(i + 1, plots.size()):
			var b: CombatSim.Plot = plots[j]
			if b.is_empty() or a.position.distance_squared_to(b.position) > r2:
				continue
			var s: SynergyDef = find(cfg, a.def.id, b.def.id)
			if s == null:
				continue
			a.links.append([j, s])
			b.links.append([i, s])
			for pair: Array in [[i, a], [j, b]]:
				var seen: Dictionary = got[pair[0]]
				if not seen.has(s.id):
					seen[s.id] = true
					var p: CombatSim.Plot = pair[1]
					p.syn.accumulate(s.bonus_for(p.def.id))


## The distinct synergies a `unit_id` built on plot `index` would form with the units already
## built in range (for the build menu's preview and the bot's placement).
static func preview(plots: Array[CombatSim.Plot], cfg: RunConfig, index: int,
		unit_id: StringName) -> Array[SynergyDef]:
	var out: Array[SynergyDef] = []
	var r2: float = cfg.synergy_range * cfg.synergy_range
	var at: Vector2 = plots[index].position
	for p: CombatSim.Plot in plots:
		if p.index == index or p.is_empty() or at.distance_squared_to(p.position) > r2:
			continue
		var s: SynergyDef = find(cfg, unit_id, p.def.id)
		if s != null and not out.has(s):
			out.append(s)
	return out
