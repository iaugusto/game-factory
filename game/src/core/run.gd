class_name Run
extends RefCounted
## One run of the game, as data: the BUILD → WAVE → CARD loop, the wall, coins and the build
## plots (every unit is fixed on one). Owns a CombatSim for the WAVE phase. Nothing here touches the scene
## tree, so a run plays headless (tests, the balance bot) exactly as it plays on screen.
##
## Flow: the run opens in BUILD (prep) for wave 1. start_wave() → WAVE, driven by step() at
## config.tick_rate. A cleared wave goes to CARD (pick 1 of 3) and then BUILD for the next
## wave, or to WON after the last one. Building, upgrading, selling, masteries and the
## barricade work in BUILD *and* WAVE: coins from crates (broken by tap()) are meant to be spent
## while the fight is on. Moving the barricade and repairing the gate are BUILD-only. A seed replays a
## run exactly (state_hash()).

signal phase_changed(phase: Phase)

enum Phase { BUILD, WAVE, CARD, WON, LOST }

var config: RunConfig
var mods: RunModifiers
var rng: RngStreams
var combat: CombatSim
var plots: Array[CombatSim.Plot] = []

var phase: Phase = Phase.BUILD
## 0-based index of the wave being fought, or the next one during BUILD and CARD.
var wave_index: int = 0
var waves_cleared: int = 0
## Coins (shown as coins; named gold in code and data).
var gold: int = 0
var wall_damage_taken: float = 0.0
var ticks: int = 0
var cards_taken: Dictionary[StringName, int] = {}
var card_offer: Array[CardDef] = []


## `meta_mods`: starting modifiers from meta progress (MetaProgress.to_modifiers). Copied, so
## the run's cards never leak back into it.
func _init(run_config: RunConfig, run_seed: int, meta_mods: RunModifiers = null) -> void:
	config = run_config
	mods = meta_mods.duplicate_mods() if meta_mods != null else RunModifiers.new()
	rng = RngStreams.new(run_seed)
	gold = config.start_gold + int(mods.start_gold_bonus)
	for i: int in config.plot_count():
		var plot := CombatSim.Plot.new()
		plot.index = i
		plot.position = config.map.plots[i]
		plot.unlock_wave = config.map.plot_unlock_wave(i)
		plots.append(plot)
	combat = CombatSim.new(config, mods, rng, plots)


func dt() -> float:
	return 1.0 / config.tick_rate


func wall_max() -> float:
	return config.wall_hp + mods.wall_hp_bonus


func wall_hp() -> float:
	return wall_max() - wall_damage_taken


func is_over() -> bool:
	return phase == Phase.WON or phase == Phase.LOST


## True while coins can be spent (BUILD, or mid-WAVE).
func can_spend() -> bool:
	return phase == Phase.BUILD or phase == Phase.WAVE


func wave_count() -> int:
	return config.waves.size()


## Bricks this run is worth, by waves cleared so far (final once is_over()).
func bricks() -> int:
	return Economy.bricks_for_run(waves_cleared, phase == Phase.WON, config.win_brick_bonus)


## Input: the player tapped field point `field_pos` during a wave. A crate under it takes a
## tap's damage. True if a crate was hit.
func tap(field_pos: Vector2) -> bool:
	if phase != Phase.WAVE:
		return false
	return combat.tap_crate_at(field_pos, config.tap_damage)


## BUILD → WAVE: the next wave begins.
func start_wave() -> bool:
	if phase != Phase.BUILD:
		return false
	combat.begin_wave(config.waves[wave_index], wave_index + 1)
	_set_phase(Phase.WAVE)
	return true


## Advance one fixed tick of the WAVE phase. Ignored in other phases.
func step() -> void:
	if phase != Phase.WAVE:
		return
	var delta: float = dt()
	combat.step(delta)
	ticks += 1
	gold += combat.pending_gold
	combat.pending_gold = 0
	wall_damage_taken += combat.pending_wall_damage
	combat.pending_wall_damage = 0.0
	wall_damage_taken = maxf(0.0, wall_damage_taken - mods.wall_regen * delta)
	if wall_hp() <= 0.0:
		_set_phase(Phase.LOST)
	elif combat.wave_done():
		combat.end_wave()
		waves_cleared = wave_index + 1
		if waves_cleared >= wave_count():
			_set_phase(Phase.WON)
			return
		wave_index += 1
		card_offer = CardPool.draw(config.cards, cards_taken, config.cards_per_offer,
				rng.stream(&"cards"))
		_set_phase(Phase.BUILD if card_offer.is_empty() else Phase.CARD)


# --- building (BUILD and WAVE) ------------------------------------------------------------

func unit_cost(unit_id: StringName) -> int:
	var def: UnitDef = config.unit_by_id(unit_id)
	return Economy.unit_cost(def, mods) if def != null else -1


## Price of upgrading the unit on `plot`, or -1 if the plot is empty, maxed or invalid.
func upgrade_cost(plot: int) -> int:
	if plot < 0 or plot >= plots.size() or plots[plot].is_empty():
		return -1
	return Economy.unit_upgrade_cost(plots[plot].def, plots[plot].level, mods)


## Build `unit_id` on an empty plot. Mid-wave the new unit needs config.build_setup_time
## before its first shot, so swapping a unit is never instant.
func build(plot: int, unit_id: StringName) -> bool:
	if not can_spend() or not plot_open(plot) or not plots[plot].is_empty():
		return false
	var cost: int = unit_cost(unit_id)
	if cost < 0 or gold < cost:
		return false
	gold -= cost
	var p: CombatSim.Plot = plots[plot]
	p.def = config.unit_by_id(unit_id)
	p.level = 1
	p.mastery = null
	p.spent = cost
	p.max_hp = p.def.hp_at(1)
	p.hp = p.max_hp
	p.disabled = 0.0
	p.cooldown = config.build_setup_time if phase == Phase.WAVE else 0.0
	return true


func upgrade(plot: int) -> bool:
	if not can_spend():
		return false
	var cost: int = upgrade_cost(plot)
	if cost < 0 or gold < cost:
		return false
	gold -= cost
	var p: CombatSim.Plot = plots[plot]
	p.level += 1
	p.spent += cost
	var new_max: float = p.def.hp_at(p.level)
	p.hp += new_max - p.max_hp  # an upgrade keeps the damage taken
	p.max_hp = new_max
	return true


## Coins to repair the unit on `plot` to full, or -1 if there is nothing to repair.
func unit_repair_cost(plot: int) -> int:
	if plot < 0 or plot >= plots.size() or plots[plot].is_empty():
		return -1
	var p: CombatSim.Plot = plots[plot]
	if p.hp >= p.max_hp:
		return -1
	return maxi(1, ceili((p.max_hp - p.hp) * config.unit_repair_cost_per_hp))


func repair_unit(plot: int) -> bool:
	var cost: int = unit_repair_cost(plot)
	if not can_spend() or cost < 0 or gold < cost:
		return false
	gold -= cost
	plots[plot].hp = plots[plot].max_hp
	return true


## True if `plot` exists and is unlocked by the wave at hand (MapDef.plot_unlock_waves).
func plot_open(plot: int) -> bool:
	return plot >= 0 and plot < plots.size() and plots[plot].unlock_wave <= wave_index + 1


## The paths open for the wave at hand (their portals open in its build phase).
func open_paths() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in config.map.paths.size():
		if config.map.paths[i].opens_at_wave <= wave_index + 1:
			out.append(i)
	return out


## Paths whose portals open with the wave at hand (to announce in its build phase).
func newly_open_paths() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i: int in config.map.paths.size():
		var w: int = config.map.paths[i].opens_at_wave
		if w > 1 and w == wave_index + 1:
			out.append(i)
	return out


## Coins selling `plot` would return (config.sell_refund of all spent on it), or -1.
func sell_value(plot: int) -> int:
	if plot < 0 or plot >= plots.size() or plots[plot].is_empty():
		return -1
	return floori(plots[plot].spent * config.sell_refund)


## Sell the unit on `plot` (to replace it): refunds sell_value and empties the plot. Returns
## the refund, or -1 if nothing was sold.
func sell(plot: int) -> int:
	if not can_spend():
		return -1
	var refund: int = sell_value(plot)
	if refund < 0:
		return -1
	gold += refund
	var p: CombatSim.Plot = plots[plot]
	p.def = null
	p.level = 0
	p.mastery = null
	p.spent = 0
	p.hp = 0.0
	p.max_hp = 0.0
	p.cooldown = 0.0
	p.disabled = 0.0
	p.target = null
	return refund


## Price of a mastery for the unit on `plot`, or -1 if it isn't at max level, already has one,
## or has none to offer.
func mastery_cost(plot: int) -> int:
	if plot < 0 or plot >= plots.size() or plots[plot].is_empty():
		return -1
	var p: CombatSim.Plot = plots[plot]
	if p.level < p.def.max_level() or p.mastery != null or p.def.masteries.is_empty():
		return -1
	return Economy.discounted(p.def.mastery_cost, mods)


## Buy mastery `index` (of the unit's UnitDef.masteries) for the maxed unit on `plot`.
func buy_mastery(plot: int, index: int) -> bool:
	if not can_spend():
		return false
	var cost: int = mastery_cost(plot)
	if cost < 0 or gold < cost or index < 0 or index >= plots[plot].def.masteries.size():
		return false
	gold -= cost
	plots[plot].mastery = plots[plot].def.masteries[index]
	plots[plot].spent += cost
	return true


# --- the gate and the barricade ------------------------------------------------------------

## Patch the gate between waves: config.gate_repair_hp for config.gate_repair_cost.
func can_repair_gate() -> bool:
	return phase == Phase.BUILD and wall_damage_taken > 0.0 and gold >= config.gate_repair_cost


func repair_gate() -> bool:
	if not can_repair_gate():
		return false
	gold -= config.gate_repair_cost
	wall_damage_taken = maxf(0.0, wall_damage_taken - config.gate_repair_hp)
	return true


## The one barricade (its state lives in the sim, which reads it every tick).
func barricade() -> CombatSim.Barricade:
	return combat.barricade


## Price of building the barricade (none yet) or of its next level; -1 when maxed or when the
## map or config has none.
func barricade_cost() -> int:
	var def: BarricadeDef = config.barricade
	if def == null or config.map.barricade_slots.is_empty():
		return -1
	var b: CombatSim.Barricade = barricade()
	if not b.is_built():
		return def.costs[0]
	return def.costs[b.level] if b.level < def.max_level() else -1


## Raise the barricade on `slot`. If one stands elsewhere, it moves there instead (free, level
## and HP kept), but only between waves.
func build_barricade(slot: int) -> bool:
	if not can_spend() or slot < 0 or slot >= config.map.barricade_slots.size():
		return false
	var b: CombatSim.Barricade = barricade()
	if b.is_built():
		if b.slot == slot or phase != Phase.BUILD:
			return false
		_place_barricade(slot)
		return true
	var cost: int = barricade_cost()
	if cost < 0 or gold < cost:
		return false
	gold -= cost
	b.level = 1
	b.max_hp = config.barricade.hp_at(1)
	b.hp = b.max_hp
	_place_barricade(slot)
	return true


func upgrade_barricade() -> bool:
	var b: CombatSim.Barricade = barricade()
	if not can_spend() or not b.is_built():
		return false
	var cost: int = barricade_cost()
	if cost < 0 or gold < cost:
		return false
	gold -= cost
	b.level += 1
	var new_max: float = config.barricade.hp_at(b.level)
	b.hp += new_max - b.max_hp
	b.max_hp = new_max
	return true


## Coins to restore the barricade to full, or -1 if there is nothing to repair.
func barricade_repair_cost() -> int:
	var b: CombatSim.Barricade = barricade()
	if not b.is_built() or b.hp >= b.max_hp:
		return -1
	return maxi(1, ceili((b.max_hp - b.hp) * config.barricade.repair_cost_per_hp))


func repair_barricade() -> bool:
	var cost: int = barricade_repair_cost()
	if not can_spend() or cost < 0 or gold < cost:
		return false
	gold -= cost
	barricade().hp = barricade().max_hp
	return true


func _place_barricade(slot: int) -> void:
	combat.place_barricade(slot, config.map.barricade_slots[slot])


# --- CARD -------------------------------------------------------------------------------

func pick_card(index: int) -> bool:
	if phase != Phase.CARD or index < 0 or index >= card_offer.size():
		return false
	var card: CardDef = card_offer[index]
	mods.add(card.key, card.value)
	cards_taken[card.id] = cards_taken.get(card.id, 0) + 1
	card_offer.clear()
	_set_phase(Phase.BUILD)
	return true


# --- internals --------------------------------------------------------------------------

func _set_phase(p: Phase) -> void:
	phase = p
	phase_changed.emit(p)


## A fingerprint of everything that matters in the run. Two runs with the same seed, config
## and inputs must produce the same hash (the determinism test).
func state_hash() -> String:
	var parts: PackedStringArray = [
		"t%d p%d w%d c%d g%d wall%.4f" % [ticks, phase, wave_index, waves_cleared, gold,
				wall_damage_taken],
		"boost %.4f" % combat.boost_time,
		"barricade %d %d %.4f" % [combat.barricade.slot, combat.barricade.level,
				combat.barricade.hp],
		"kills %d crates %d shots %d" % [combat.kills, combat.crates_broken,
				combat.shots.size()],
	]
	for plot: CombatSim.Plot in plots:
		parts.append("plot %s %d %.4f %.4f %s %d %.4f" % [plot.def.id if plot.def else &"-",
				plot.level, plot.cooldown, plot.disabled,
				plot.mastery.id if plot.mastery else &"-", plot.spent, plot.hp])
	var ids: Array = cards_taken.keys()
	ids.sort()
	for id: StringName in ids:
		parts.append("card %s %d" % [id, cards_taken[id]])
	for group: Array in combat.path_enemies:
		for e: CombatSim.Enemy in group:
			parts.append("e%d %d %.4f %.4f %.4f %.4f %s" % [e.id, e.path, e.d, e.hp, e.strike_timer,
					e.spit_timer, e.elite.id if e.elite else &"-"])
	for sp: CombatSim.Spit in combat.spits:
		parts.append("s%d %.4f %.4f" % [sp.id, sp.pos.x, sp.pos.y])
	for group: Array in combat.path_crates:
		for c: CombatSim.Crate in group:
			parts.append("c%d %d %.4f %.4f" % [c.id, c.path, c.d, c.hp])
	return "\n".join(parts).sha256_text()
