class_name Autoplay
extends RefCounted
## A scripted player. Plays a Run to the end with no input device: the determinism test uses
## it, the scene uses it for --autoplay and fast-forwards, and the balance bot compares
## variants of it (build orders, tapping crates or not).
##
## The policy is deliberately simple and fully deterministic: it reads only run state. Like a
## player, it has two verbs during a wave: tap loot, and spend coins on plots.

## Tap crates at all (the income decision).
var chase_crates: bool = true
## Taps per second, spread evenly over ticks: a human-like rate that leaves time for building.
var taps_per_second: float = 3.0
## Pick each new unit to counter the wave being fought (the counter chart, weighted by count ×
## threat), like a player who reads the wave preview. Off: `build_order`, cycling.
var counter_pick: bool = true
## Units to build, in order, cycling (when counter_pick is off).
var build_order: Array[StringName] = [&"rifleman", &"mortar", &"mg", &"sniper", &"frost",
		&"rail"]
## Raise the barricade (where it blocks the most threat) once this many units stand; -1: never.
var barricade_after_units: int = 3
## Patch the gate between waves while it is below this fraction.
var repair_gate_below: float = 0.7
## Stop building new units after this many (then only upgrade). The default fills every plot:
## with the squad gone, units are the only coin sink.
var max_units: int = 99
## Which card of the offer to take.
var card_choice: int = 0
## During a wave, try to spend every this many ticks.
var build_every_ticks: int = 30
## Plots are filled nearest this point first (the middle of the field).
var plot_focus: Vector2 = Vector2(270, 560)


## The crate nearest the gate (least distance left on its path; the most urgent loot), or null.
func most_urgent_crate(run: Run) -> CombatSim.Crate:
	var best: CombatSim.Crate = null
	for i: int in run.combat.path_crates.size():
		var group: Array = run.combat.path_crates[i]
		if not group.is_empty() and (best == null or run.combat.geos[i].length - group[0].d
				< run.combat.geos[best.path].length - best.d):
			best = group[0]
	return best


## Spend coins: repairs first, then fill plots (countering the wave), the barricade, then the
## cheapest upgrade (unit level, mastery or barricade level).
func play_build(run: Run) -> void:
	if run.phase == Run.Phase.BUILD:
		while run.wall_hp() < run.wall_max() * repair_gate_below and run.repair_gate():
			pass
		_place_barricade(run)
	while run.can_spend():
		var b: CombatSim.Barricade = run.barricade()
		if b.is_built() and not b.is_standing() and run.repair_barricade():
			continue
		if _repair_worst_unit(run):
			continue
		var built: int = _units_built(run)
		if barricade_after_units >= 0 and built >= barricade_after_units \
				and not b.is_built() and run.barricade_cost() >= 0:
			if run.build_barricade(_best_barricade_slot(run)):
				continue
			return  # save up for it
		var empty: int = _plot_for_threat(run)
		if built < max_units and empty >= 0:
			var id: StringName = _choose_unit(run, built)
			if run.build(empty, id):
				continue
			return  # save up for the next unit
		if not _buy_cheapest_upgrade(run):
			return


## The unit to build next, or build_order when counter_pick is off. It fills the biggest gap:
## the enemy type in the wave at hand that the units already built counter worst (their kills
## per second against it, relative to its count × threat), then the most cost-effective unit
## against that type. It saves for that unit unless enemies are already at
## the gate; then it takes the best one it can afford now.
func _choose_unit(run: Run, built: int) -> StringName:
	if not counter_pick:
		return build_order[built % build_order.size()]
	var wave: WaveDef = run.config.waves[mini(run.wave_index, run.wave_count() - 1)]
	var counts: Dictionary = WaveSchedule.enemy_counts(wave)
	var gap: EnemyDef = null
	var gap_score: float = -1.0
	for e: EnemyDef in counts:
		# Coverage as kills per second (damage per second over its HP), so types compare.
		var cover: float = 0.0
		for plot: CombatSim.Plot in run.plots:
			if not plot.is_empty():
				cover += _dps_against(run, plot.def, e, plot.level) / maxf(1.0, e.hp)
		var need: float = counts[e] * e.threat
		var score: float = need / (1.0 + 4.0 * cover)
		if score > gap_score:
			gap_score = score
			gap = e
	var pool: Array[UnitDef] = run.config.units
	if _under_siege(run):
		var affordable: Array[UnitDef] = []
		for u: UnitDef in run.config.units:
			if run.unit_cost(u.id) <= run.gold:
				affordable.append(u)
		if not affordable.is_empty():
			pool = affordable
	var best: StringName = build_order[0]
	var best_score: float = -1.0
	for u: UnitDef in pool:
		var score: float = _dps_against(run, u, gap, 1) / run.unit_cost(u.id)
		if score > best_score:
			best_score = score
			best = u.id
	return best


## A unit's damage per second against `e` at `level` through the chart, with splash counted as
## hitting ~2 more of a pack and a beam ~0.3 more.
func _dps_against(run: Run, u: UnitDef, e: EnemyDef, level: int) -> float:
	var hit: float = CombatSim.effective_damage(run.config, e, u.damage_at(level), u.damage_type)
	var pack: float = 1.0
	if u.splash_radius > 0.0:
		pack = 3.0
	elif u.attack == UnitDef.Attack.BEAM:
		pack = 1.3  # a lined-up pair now and then; a lone armoured target usually
	return hit / u.reload_at(level) * pack


## Between waves, keep the barricade where it blocks the most threat of the coming wave.
func _place_barricade(run: Run) -> void:
	var b: CombatSim.Barricade = run.barricade()
	if b.is_built():
		run.build_barricade(_best_barricade_slot(run))


## The barricade slot blocking the most threat in the coming wave: each slot is worth the
## threat of the paths through it (fixed-path spawns count on their path; random ones spread
## over the open paths). Ties go to the lower index.
func _best_barricade_slot(run: Run) -> int:
	var slots: PackedVector2Array = run.config.map.barricade_slots
	var wave: WaveDef = run.config.waves[mini(run.wave_index, run.wave_count() - 1)]
	var open: PackedInt32Array = run.open_paths()
	var path_threat: Array[float] = []
	path_threat.resize(run.combat.geos.size())
	path_threat.fill(0.0)
	for entry: SpawnEntry in wave.spawns:
		var t: float = entry.count * entry.enemy.threat
		if entry.path >= 0:
			path_threat[entry.path] += t
		else:
			for i: int in open:
				path_threat[i] += t / open.size()
	var best: int = 0
	var best_t: float = -1.0
	for s: int in slots.size():
		var t: float = 0.0
		for i: int in run.combat.geos.size():
			if run.combat.geos[i].nearest(slots[s]).y <= CombatSim.BARRICADE_REACH:
				t += path_threat[i]
		if t > best_t:
			best_t = t
			best = s
	return best


## Repair the most damaged unit (below 60% HP) if affordable. True if one was repaired.
func _repair_worst_unit(run: Run) -> bool:
	var worst: int = -1
	var worst_ratio: float = 0.6
	for plot: CombatSim.Plot in run.plots:
		if not plot.is_empty() and plot.max_hp > 0.0 and plot.hp / plot.max_hp < worst_ratio:
			worst_ratio = plot.hp / plot.max_hp
			worst = plot.index
	return worst >= 0 and run.repair_unit(worst)


func _units_built(run: Run) -> int:
	var n: int = 0
	for plot: CombatSim.Plot in run.plots:
		n += 0 if plot.is_empty() else 1
	return n


func _under_siege(run: Run) -> bool:
	for group: Array in run.combat.path_enemies:
		for e: CombatSim.Enemy in group:
			if e.sieging:
				return true
	return false


## Where to build: the open plot nearest the enemies at the gate (or the barricade) if any are
## there, else the open plot nearest `plot_focus`. -1 if none is free.
func _plot_for_threat(run: Run) -> int:
	var sieger: CombatSim.Enemy = null
	for group: Array in run.combat.path_enemies:
		for e: CombatSim.Enemy in group:
			if e.sieging and (sieger == null or e.y > sieger.y):
				sieger = e
	if sieger == null:
		return _next_empty_plot(run)
	var best: int = -1
	var best_d: float = INF
	for plot: CombatSim.Plot in run.plots:
		var d: float = plot.position.distance_squared_to(sieger.pos())
		if plot.is_empty() and run.plot_open(plot.index) and d < best_d:
			best_d = d
			best = plot.index
	return best


## The open empty plot nearest `plot_focus`, or -1.
func _next_empty_plot(run: Run) -> int:
	var best: int = -1
	var best_d: float = INF
	for plot: CombatSim.Plot in run.plots:
		var d: float = plot.position.distance_squared_to(plot_focus)
		if plot.is_empty() and run.plot_open(plot.index) and d < best_d:
			best_d = d
			best = plot.index
	return best


## Buy the cheapest upgrade if it is affordable: a unit level, a mastery (Overcharge, the
## first offered) or a barricade level. True if one was bought.
func _buy_cheapest_upgrade(run: Run) -> bool:
	var best_cost: int = -1
	var best: Callable
	for plot: CombatSim.Plot in run.plots:
		var c: int = run.upgrade_cost(plot.index)
		var i: int = plot.index
		if c >= 0 and (best_cost < 0 or c < best_cost):
			best_cost = c
			best = func() -> bool: return run.upgrade(i)
		c = run.mastery_cost(plot.index)
		if c >= 0 and (best_cost < 0 or c < best_cost):
			best_cost = c
			best = func() -> bool: return run.buy_mastery(i, 0)
	if run.barricade().is_built():
		var c: int = run.barricade_cost()
		if c >= 0 and (best_cost < 0 or c < best_cost):
			best_cost = c
			best = func() -> bool: return run.upgrade_barricade()
	if best_cost < 0 or run.gold < best_cost:
		return false
	return best.call()


## Play `run` until it ends or `max_ticks` wave ticks have passed. Returns the run.
func play(run: Run, max_ticks: int = 60 * 60 * 30) -> Run:
	while not run.is_over() and run.ticks < max_ticks:
		match run.phase:
			Run.Phase.BUILD:
				play_build(run)
				run.start_wave()
			Run.Phase.WAVE:
				step_wave(run)
			Run.Phase.CARD:
				run.pick_card(mini(card_choice, run.card_offer.size() - 1))
	return run


## One WAVE tick as the bot plays it: tap loot on its rhythm, spend now and then, step.
func step_wave(run: Run) -> void:
	if chase_crates and taps_per_second > 0.0 and _tap_due(run):
		var crate: CombatSim.Crate = most_urgent_crate(run)
		if crate != null:
			run.tap(crate.pos())
	if build_every_ticks > 0 and run.ticks % build_every_ticks == 0:
		play_build(run)
	run.step()


## True on the ticks where a tap falls, `taps_per_second` spread evenly (tick-based, so it is
## deterministic and independent of frame rate).
func _tap_due(run: Run) -> bool:
	var rate: float = taps_per_second / run.config.tick_rate
	return floori((run.ticks + 1) * rate) > floori(run.ticks * rate)
