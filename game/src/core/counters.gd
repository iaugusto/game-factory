class_name Counters
extends RefCounted
## Reads the counter chart for the UI (intel cards, "strong vs" on units, the wave preview) and
## tests: which units an enemy is weak to or resists, and which enemies a unit is strong
## against. Pure queries over content; the damage math itself is CombatSim.effective_damage.


static func is_weak(e: EnemyDef, type: UnitDef.DamageType) -> bool:
	return e.weak_to & (1 << type) != 0


static func resists(e: EnemyDef, type: UnitDef.DamageType) -> bool:
	return e.resists & (1 << type) != 0


## Units in `cfg` whose damage `e` is weak to.
static func units_strong_vs(cfg: RunConfig, e: EnemyDef) -> Array[UnitDef]:
	var out: Array[UnitDef] = []
	for u: UnitDef in cfg.units:
		if is_weak(e, u.damage_type):
			out.append(u)
	return out


## Units in `cfg` whose damage `e` resists, plus light hitters its armour blunts (a hit under
## twice the armour loses more than half).
static func units_weak_vs(cfg: RunConfig, e: EnemyDef) -> Array[UnitDef]:
	var out: Array[UnitDef] = []
	for u: UnitDef in cfg.units:
		if resists(e, u.damage_type) or (e.armor > 0.0 and u.damage < e.armor * 2.0):
			out.append(u)
	return out


## Enemy types across `cfg`'s waves that `u` is strong against, in first-appearance order.
static func enemies_countered_by(cfg: RunConfig, u: UnitDef) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	for w: WaveDef in cfg.waves:
		for s: SpawnEntry in w.spawns:
			if is_weak(s.enemy, u.damage_type) and not out.has(s.enemy):
				out.append(s.enemy)
	return out
