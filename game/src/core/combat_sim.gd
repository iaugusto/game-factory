class_name CombatSim
extends RefCounted
## The WAVE phase, simulated on a fixed tick with no scene tree.
##
## - **Units** are fixed on build plots (the wall's spots included) and fire on their own at the
##   enemy nearest the wall within reach, once per reload. How the shot travels depends on
##   UnitDef.Attack. Nothing the player owns moves (docs/2026-09-26-fixed-units-wall-spots/).
## - **Loot crates** drift down the paths and are broken by the player's taps (tap_crate_at),
##   never by units: tapping loot vs tapping a plot to build is the player's live decision.
## - **Paths** (MapDef.paths, geometry in PathGeo) lead from portals to the gate; enemies and
##   crates move by `d`, their distance along their path. Each path keeps them sorted by d,
##   furthest along first, which makes unit targeting a binary search (first_in_reach).
##   "Nearest the gate" is the least distance remaining, so paths of any length compare.
## - **The gate siege:** an enemy that reaches the wall stops there and strikes the gate every
##   EnemyDef.attack_interval for its wall_damage, until it is killed. The run owns the gate's
##   HP and loses when it breaks (docs/2026-09-26-gate-siege/).
## - **Spitters** (EnemyDef.spit_interval > 0) spit at the nearest working unit in range while
##   they walk; the glob always lands (plots don't move) and disables that unit for a while.
## - **The counter chart:** every hit goes through effective_damage (weakness ×2, resistance
##   ×0.5, flat armour with a floor), so each enemy has a right and a wrong weapon
##   (docs/2026-09-26-counters-and-coin-sinks/).
## - **The barricade** (one, owned by Run): enemies on every path through its slot stop in front
##   of it and strike it instead of the gate until it breaks, then walk on.
## - **Terrain** (MapDef.zones): mud slows enemies inside it; high ground adds reach to plots.
## - **Units can be destroyed**, by the few enemies that attack them (EnemyDef.unit_reach, the
##   Ravager): priority barricade > a unit in reach > the gate
##   (docs/2026-09-26-new-enemies-and-destroyable-units/). Splitters burst into a brood on
##   death, Menders heal their neighbours, and elites (EliteDef) change one property.
## - **Skill-tree rules** (docs/2026-09-27-sectors-and-skill-tree/): a destroyed unit may explode
##   (RunModifiers.death_blast), and the gate may bite back at its attackers (gate_thorns).
##   Both happen during the enemy move pass, which can't remove enemies from the path lists it
##   walks, so their damage is queued and applied right after it (_resolve_queued).
## - **Special attacks** (AbilityDef, called through Run.call_ability): a Cast lands after its
##   delay, then acts by kind: a blast (STRIKE), a freeze (FREEZE: Enemy.stun), a burning strip
##   (BURN: a Hazard that burns for a while), mines on a path (MINES: each a Mine that waits for
##   an enemy), or repairs (REPAIR). Like the queued damage, they resolve after the move pass.
## - **Stage 2 enemies** (docs/2026-09-27-content-expansion/): Wasps fly (over the barricade,
##   mud and escorts; ground effects miss them), Wardens shield everyone near them
##   (Enemy.shield soaks damage first), Burrowers dive underground (untargetable, under the
##   barricade), and Bombardiers stop short of the gate and lob globs at it (Lob).
## - **Bosses** (EnemyDef.is_boss, Stage 3): each BossPhase fires once, in order, as the boss's
##   HP falls past its threshold (_check_phases, from _apply_damage; 1.0 fires on arrival). A
##   phase spawns a brood or an escort just ahead of it (inserted sorted, like a Splitter's
##   brood), changes its armour or speed, or stops it for a moment (Enemy.pause). Guards (a
##   phase's spawns with BossPhase.guard) make it take no damage while any of them lives.
##
## Coins earned and wall damage dealt are accumulated in `pending_gold` / `pending_wall_damage`
## and drained by Run every tick: the run, not the sim, owns the wall and the purse.

signal enemy_spawned(enemy: Enemy)
signal enemy_killed(enemy: Enemy, gold: int)
## An enemy at the gate struck it for `damage` (its first strike lands on arrival).
signal enemy_struck(enemy: Enemy, damage: float)
## A spitter spat at a unit; the glob is in `spits`.
signal spit_fired(spit: Spit)
## A glob landed: `plot` is disabled for `duration` seconds.
signal unit_disabled(plot: Plot, duration: float)
signal crate_spawned(crate: Crate)
signal crate_broken(crate: Crate, coins: int)
## A crate reached the wall unbroken: its loot is lost.
signal crate_lost(crate: Crate)
## A unit fired at `target` (the enemy's position when fired). Hitscan and beam damage has
## already been dealt; bullets and shells are in `shots`.
signal unit_fired(plot: Plot, target: Vector2)
signal shell_landed(shot: Shot)
## A tap hit a crate without breaking it (breaking emits crate_broken).
signal crate_tapped(crate: Crate)
signal boost_started(crate: Crate)
## A hit that the chart changed: `effect` is +1 (weak) or -1 (resisted or armour-blunted).
## Neutral hits emit nothing (there are hundreds a second).
signal enemy_hit(enemy: Enemy, amount: float, effect: int)
## An enemy stopped at the barricade struck it; it broke.
signal barricade_struck(enemy: Enemy, damage: float)
signal barricade_broken
## An enemy mauled the unit on `plot`; it fell (the plot is empty again).
signal unit_struck(plot: Plot, enemy: Enemy, damage: float)
signal unit_destroyed(plot: Plot, def: UnitDef)
## A Mender's heal pulse (once a second while it heals someone), for the view.
signal mender_pulse(enemy: Enemy)
## A fallen unit exploded (the tree's Last Stand) at `pos`, hitting everything within `radius`.
signal unit_blast(pos: Vector2, radius: float)
## Unit links were recomputed (Synergies.compute).
signal synergies_changed
## A special attack was called; it lands when cast.t runs out (it is in `casts` until then).
signal ability_called(cast: Cast)
## It landed: its effect has been applied (a burn's Hazard or MINES' Mines now exist).
signal ability_landed(cast: Cast)
## A mine went off under an enemy (its damage has been dealt).
signal mine_exploded(mine: Mine)
## A Bombardier lobbed a glob at the gate (it is in `lobs` until it lands).
signal enemy_lobbed(lob: Lob)
## It landed: the gate took its damage (enemy_struck was emitted too, for the tallies).
signal lob_landed(lob: Lob)
## An enemy dived underground, or surfaced.
signal enemy_burrowed(enemy: Enemy)
signal enemy_surfaced(enemy: Enemy)
## A Warden's shield soaked (part of) a hit.
signal shield_hit(enemy: Enemy, absorbed: float)
## A boss's phase fired (its spawns have been spawned; phase is boss.def.phases[index]).
signal boss_phase(boss: Enemy, index: int)

## Reload countdowns within this of zero count as ready, so float drift in `cooldown - dt`
## never delays a shot by a tick (a 0.5 s reload fires every 30 ticks at 60 Hz, exactly).
const READY_EPSILON: float = 1e-6
## Half the barricade's depth along a path (enemies stop just in front of it), and how close a
## path's centre line must pass to a slot to be blocked by a barricade there.
const BARRICADE_HALF_DEPTH: float = 16.0
const BARRICADE_REACH: float = 40.0
## Escorts: how many enemies ahead are checked, and how much bigger (radius) one must be to
## block a smaller one.
const ESCORT_LOOKAHEAD: int = 4
const ESCORT_SIZE_GAP: float = 5.0
## How often Wardens' auras are refreshed (seconds; see _shield).
const SHIELD_PERIOD: float = 0.1


class Enemy:
	var id: int
	var def: EnemyDef
	var path: int
	## Distance along its path from the portal; `offset` is its sideways spread from the centre
	## line. x, y are derived from both every move.
	var d: float = 0.0
	var offset: float = 0.0
	## The path segment it is on (a cache for PathGeo.segment_from).
	var seg: int = 0
	var x: float = 0.0
	var y: float = 0.0
	var hp: float
	## Spawn hp and base speed after the wave's scaling (EnemyDef values × WaveDef scales).
	var max_hp: float
	var speed: float
	var slow_timer: float = 0.0
	var slow_factor: float = 1.0
	var alive: bool = true
	## Stopped and striking every def.attack_interval: the gate, or the barricade if
	## `at_barricade`.
	var sieging: bool = false
	var at_barricade: bool = false
	## The unit it is mauling while stopped (unit attackers only).
	var target_plot: Plot = null
	var elite: EliteDef = null
	var pulse_timer: float = 0.0
	## Seconds until the next strike (while sieging).
	var strike_timer: float = 0.0
	## Seconds until it may spit again (spitters only).
	var spit_timer: float = 0.0
	## Seconds left frozen solid (a FREEZE ability): it neither moves nor acts.
	var stun: float = 0.0
	## Shield HP from a Warden's aura (soaks damage before hp), and the cap of the strongest
	## aura it stands in this tick (0: none; the shield then holds but doesn't refill).
	var shield: float = 0.0
	var shield_max: float = 0.0
	## Burrowers: underground until `d` reaches `surface_d` (-1: on the surface), and seconds
	## of surface walking left before the next dive.
	var surface_d: float = -1.0
	var burrow_timer: float = 0.0
	## Bombardiers: stopped at siege range, lobbing at the gate (also `sieging`).
	var lobbing: bool = false
	## Bosses: the next phase to fire (an index into def.phases), armour added by phases, seconds
	## left stopped by a phase (like stun, but not frozen), and how many of its guards live.
	var next_phase: int = 0
	var armor_bonus: float = 0.0
	var pause: float = 0.0
	var guards: int = 0
	## The boss this enemy guards (null: none).
	var guarding: Enemy = null

	func pos() -> Vector2:
		return Vector2(x, y)

	func burrowed() -> bool:
		return surface_d >= 0.0

	## Units and every effect can reach it (alive and not underground).
	func hittable() -> bool:
		return alive and surface_d < 0.0

	## Ground effects (shells, mines, fire, mud, the barricade) reach it: not underground and
	## not flying.
	func on_ground() -> bool:
		return surface_d < 0.0 and not def.flying

	## A boss's guards live: every hit on it is void.
	func guarded() -> bool:
		return guards > 0

	## Armour on top of its def's: an elite's and its boss phases'.
	func extra_armor() -> float:
		return armor_bonus + (elite.armor_bonus if elite != null else 0.0)


class Crate:
	var id: int
	var def: CrateDef
	var path: int
	var d: float = 0.0
	var x: float = 0.0
	var y: float = 0.0
	var hp: float
	var alive: bool = true

	func pos() -> Vector2:
		return Vector2(x, y)


## A build plot and whatever stands on it. Plots live in Run for the whole run; the sim fires
## the occupied ones.
class Plot:
	var index: int
	var position: Vector2
	var def: UnitDef = null
	var level: int = 0
	var cooldown: float = 0.0
	## The enemy it is aiming at (null when idle).
	var target: Enemy = null
	## Where it last aimed (cosmetic: the view turns the unit's head toward it).
	var aim: Vector2 = Vector2.ZERO
	var shots_fired: int = 0
	## Seconds left disabled by a spitter's glob: it can't fire and its reload is paused.
	var disabled: float = 0.0
	## The unit's health (UnitDef.hp_at its level); Run sets it on build and upgrade.
	var hp: float = 0.0
	var max_hp: float = 0.0
	## Bought at max level (null until then).
	var mastery: MasteryDef = null
	## Coins spent on this plot's unit (build, upgrades, mastery): selling refunds a fraction.
	var spent: int = 0
	## The wave (1-based) from which it can be built on (MapDef.plot_unlock_waves).
	var unlock_wave: int = 1
	## Extra reach from standing on high ground (a fraction).
	var terrain_reach: float = 0.0
	## Distance from the plot to each path's centre line (static; targeting skips far paths).
	var path_dist: PackedFloat32Array = PackedFloat32Array()
	## Summed synergy bonuses, and the links behind them ([other plot index, SynergyDef]).
	## Set by Synergies.compute when units are built, sold or destroyed.
	var syn: StatBonus = StatBonus.new()
	var links: Array = []

	func is_empty() -> bool:
		return def == null

	func is_disabled() -> bool:
		return disabled > 0.0


## The one barricade: which slot it stands on (-1: none built), its level and HP. Run owns it
## for the whole run; the sim reads and damages it.
class Barricade:
	var slot: int = -1
	var position: Vector2 = Vector2.ZERO
	## Per path: where enemies stop in front of it (distance along the path, before their
	## radius), or -1 if it doesn't stand on that path. Set by CombatSim.place_barricade.
	var stop_d: PackedFloat32Array = PackedFloat32Array()
	var level: int = 0
	var hp: float = 0.0
	var max_hp: float = 0.0

	func is_built() -> bool:
		return slot >= 0 and level > 0

	## Built and not broken: it blocks the paths through its slot.
	func is_standing() -> bool:
		return is_built() and hp > 0.0

	func blocks(path: int) -> bool:
		return path < stop_d.size() and stop_d[path] >= 0.0


## A spitter's acid glob in flight toward a plot (it always lands: plots don't move).
class Spit:
	var id: int
	var pos: Vector2
	var start: Vector2
	var plot: Plot
	var speed: float
	var duration: float


## A called special attack on its way: it lands at `pos` when `t` runs out. `power` scales its
## damage (the wave's hp_scale when it was called).
class Cast:
	var id: int
	var ability: AbilityDef
	var pos: Vector2
	var t: float
	var power: float = 1.0


## A stretch of one path's centre line: from `d_lo` to `d_hi` along path `path` (`points`).
class Stretch:
	var path: int
	var d_lo: float
	var d_hi: float
	var points: PackedVector2Array


## A burning stretch of road (a BURN ability) for `t` more seconds: `stretches` (one per path
## through the tapped spot, see burn_layout), `half_width` to each side. Every enemy on it takes
## `dps` a second, whichever path it walks, so where paths merge the fire burns for all of them
## and at a fork it runs down every branch.
class Hazard:
	var id: int
	var stretches: Array[Stretch]
	var half_width: float
	## The stretches grown by half_width: a cheap first test before the distance to them.
	var bounds: Rect2
	var t: float
	var duration: float
	var dps: float


## A mine (a MINES ability) at distance `d` along `path`: it goes off when an enemy reaches it,
## dealing `damage` within `radius` of `pos`.
class Mine:
	var id: int
	var path: int
	var d: float
	var pos: Vector2
	var damage: float
	var radius: float


## A Bombardier's glob on its way to the gate: it lands at `dest` when `t` reaches `duration`,
## for `damage` (it lands even if the thrower dies meanwhile).
class Lob:
	var id: int
	var enemy: Enemy
	var start: Vector2
	var dest: Vector2
	var pos: Vector2
	var t: float = 0.0
	var duration: float
	var damage: float


## A unit's projectile in flight (BULLET or SHELL; hitscan and beams have none).
class Shot:
	var id: int
	var plot: int
	var attack: UnitDef.Attack
	var pos: Vector2
	var start: Vector2
	var dest: Vector2
	var target: Enemy
	var speed: float
	var damage: float
	var damage_type: UnitDef.DamageType
	var armor_pierce: float
	var splash: float
	var slow: float
	var slow_time: float
	## SHELL: time in flight and total flight time.
	var t: float = 0.0
	var duration: float = 0.0


var config: RunConfig
var mods: RunModifiers
var rng: RngStreams
var plots: Array[Plot]
var barricade := Barricade.new()
## One per MapDef.paths entry.
var geos: Array[PathGeo] = []
## The paths open this wave (their portals have opened).
var open_paths: PackedInt32Array = PackedInt32Array()
var _mud: Array[ZoneDef] = []

## Per path: Array of Enemy / Crate, sorted by d descending (furthest along first).
var path_enemies: Array[Array] = []
var path_crates: Array[Array] = []
var shots: Array[Shot] = []
var spits: Array[Spit] = []
var casts: Array[Cast] = []
var hazards: Array[Hazard] = []
var mines: Array[Mine] = []
var lobs: Array[Lob] = []
## Wardens on the field (kept by spawn and kill), so the shield pass costs nothing without them.
var _wardens: int = 0
var _shield_clock: float = 0.0
## Bosses on the field, in spawn order (kept by spawn and kill; the HUD's boss bar reads it).
var bosses: Array[Enemy] = []

var time: float = 0.0
## Unit fire-rate boost from a boost crate: multiplier and seconds left.
var boost_mult: float = 1.0
var boost_time: float = 0.0

var pending_gold: int = 0
var pending_wall_damage: float = 0.0
## Gate HP restored this tick (a REPAIR ability), drained by Run like the damage.
var pending_gate_heal: float = 0.0
var kills: int = 0
var crates_broken: int = 0

var _wave: WaveDef
var _events: Array[WaveSchedule.Event] = []
var _cursor: int = 0
var _next_id: int = 1
## Ids of casts and mines: a counter of their own, so calling an ability never shifts enemy ids
## (which seed their sideways spread).
var _cast_ids: int = 0
## Damage queued during the enemy move pass: blasts as (x, y, damage), thorns per enemy.
var _queued_blasts: Array[Vector3] = []
var _queued_thorns: Array[Enemy] = []
var _queued_thorn_damage: PackedFloat32Array = PackedFloat32Array()


func _init(run_config: RunConfig, run_mods: RunModifiers, streams: RngStreams,
		run_plots: Array[Plot]) -> void:
	config = run_config
	mods = run_mods
	rng = streams
	plots = run_plots
	for path: PathDef in config.map.paths:
		geos.append(PathGeo.new(path.points))
		path_enemies.append([])
		path_crates.append([])
	for zone: ZoneDef in config.map.zones:
		if zone.kind == ZoneDef.Kind.MUD:
			_mud.append(zone)
	for plot: Plot in plots:
		plot.path_dist.resize(geos.size())
		for i: int in geos.size():
			plot.path_dist[i] = geos[i].nearest(plot.position).y
		for zone: ZoneDef in config.map.zones:
			if zone.kind == ZoneDef.Kind.HIGH_GROUND and zone.contains(plot.position):
				plot.terrain_reach += zone.value
	barricade.stop_d.resize(geos.size())
	barricade.stop_d.fill(-1.0)
	set_open_paths(1)


## Open the portals of every path whose opens_at_wave <= `wave_number` (1-based).
func set_open_paths(wave_number: int) -> void:
	open_paths.clear()
	for i: int in config.map.paths.size():
		if config.map.paths[i].opens_at_wave <= wave_number:
			open_paths.append(i)


## Stand the barricade at `pos` (or take it down with slot -1): every path whose centre line
## passes within BARRICADE_REACH of it is blocked there.
func place_barricade(slot: int, pos: Vector2) -> void:
	barricade.slot = slot
	barricade.position = pos
	for i: int in geos.size():
		var near: Vector2 = geos[i].nearest(pos)
		barricade.stop_d[i] = maxf(0.0, near.x - BARRICADE_HALF_DEPTH) \
				if slot >= 0 and near.y <= BARRICADE_REACH else -1.0


## Reset the field for wave `wave_number` (1-based) and schedule its events.
func begin_wave(wave: WaveDef, wave_number: int = 1) -> void:
	_wave = wave
	set_open_paths(wave_number)
	_events = WaveSchedule.build(wave, open_paths, rng.stream(&"spawn"))
	_cursor = 0
	time = 0.0
	boost_time = 0.0
	boost_mult = 1.0
	for i: int in geos.size():
		path_enemies[i].clear()
		path_crates[i].clear()
	shots.clear()
	spits.clear()
	lobs.clear()
	_wardens = 0
	_shield_clock = 0.0
	bosses.clear()
	_clear_abilities()
	for plot: Plot in plots:
		plot.cooldown = 0.0
		plot.target = null
		plot.disabled = 0.0


## The wave is over (cleared): leftover crates are lost with it (crate_lost, so views can show
## it), and shots, shells and the boost are cleared so nothing hangs mid-air between waves.
func end_wave() -> void:
	for group: Array in path_crates:
		var crates: Array = group.duplicate()
		group.clear()
		for c: Crate in crates:
			c.alive = false
			crate_lost.emit(c)
	shots.clear()
	spits.clear()
	lobs.clear()
	_clear_abilities()
	boost_time = 0.0
	boost_mult = 1.0
	for plot: Plot in plots:
		plot.target = null
		plot.disabled = 0.0


## Every event spawned and every enemy dead. Leftover crates don't hold the wave open (their
## loot is lost with the wave).
func wave_done() -> bool:
	return _cursor >= _events.size() and enemy_count() == 0


func enemy_count() -> int:
	var total: int = 0
	for group: Array in path_enemies:
		total += group.size()
	return total


func crate_count() -> int:
	var total: int = 0
	for group: Array in path_crates:
		total += group.size()
	return total


## The units' fire-rate multiplier from an active boost crate (1.0 when none).
func boost_rate_mult() -> float:
	return boost_mult if boost_time > 0.0 else 1.0


## A unit's effective reload at `level` with `mastery`, after the run's modifiers and any
## active boost.
func reload_for(def: UnitDef, level: int, mastery: MasteryDef = null,
		syn: StatBonus = null) -> float:
	var bonus: float = mods.unit_rate_bonus + (mastery.reload_bonus if mastery else 0.0) \
			+ (syn.reload if syn else 0.0)
	return def.reload_at(level) / ((1.0 + bonus) * boost_rate_mult())


## A unit's damage per shot at `level` with `mastery`, after the run's modifiers (before the
## chart and crits).
func damage_for(def: UnitDef, level: int, mastery: MasteryDef = null,
		syn: StatBonus = null) -> float:
	return def.damage_at(level) * (1.0 + mods.unit_damage_bonus
			+ (mastery.damage_bonus if mastery else 0.0) + (syn.damage if syn else 0.0))


## A unit's targeting radius with `mastery` (and `terrain`, a high-ground bonus), after the
## run's modifiers.
func reach_for(def: UnitDef, mastery: MasteryDef = null, terrain: float = 0.0,
		syn: StatBonus = null) -> float:
	return def.reach * (1.0 + mods.unit_reach_bonus + terrain
			+ (mastery.reach_bonus if mastery else 0.0) + (syn.reach if syn else 0.0))


func reload_of(def: UnitDef, level: int) -> float:
	return reload_for(def, level)


func damage_of(def: UnitDef, level: int) -> float:
	return damage_for(def, level)


func reach_of(def: UnitDef) -> float:
	return reach_for(def)


## The stats of what stands on `plot` right now.
func plot_reload(plot: Plot) -> float:
	return reload_for(plot.def, plot.level, plot.mastery, plot.syn)


func plot_damage(plot: Plot) -> float:
	return damage_for(plot.def, plot.level, plot.mastery, plot.syn)


func plot_reach(plot: Plot) -> float:
	return reach_for(plot.def, plot.mastery, plot.terrain_reach, plot.syn)


## Recompute every plot's links and synergy bonuses (after a build, sell or destruction).
func refresh_synergies() -> void:
	Synergies.compute(plots, config)
	synergies_changed.emit()


## Damage a hit of `raw` of `type` really deals to `e`: armour first (reduced by `pierce`, never
## below config.armor_floor of the hit), then the weakness or resistance multiplier.
static func effective_damage(cfg: RunConfig, e: EnemyDef, raw: float,
		type: UnitDef.DamageType, pierce: float = 0.0, extra_armor: float = 0.0) -> float:
	var armor: float = (e.armor + extra_armor) * (1.0 - clampf(pierce, 0.0, 1.0))
	var dmg: float = maxf(raw - armor, raw * cfg.armor_floor)
	return dmg * chart_multiplier(cfg, e, type)


## ×weak, ×resist or ×1 for `type` against `e`.
static func chart_multiplier(cfg: RunConfig, e: EnemyDef, type: UnitDef.DamageType) -> float:
	var bit: int = 1 << type
	if e.weak_to & bit:
		return cfg.weak_multiplier
	if e.resists & bit:
		return cfg.resist_multiplier
	return 1.0


## Advance one fixed tick.
func step(dt: float) -> void:
	time += dt
	if boost_time > 0.0:
		boost_time = maxf(0.0, boost_time - dt)
	_spawn_due()
	_move_enemies(dt)
	_resolve_queued()
	_land_casts(dt)
	_burn(dt)
	_trip_mines()
	_move_crates(dt)
	_spit_enemies(dt)
	_heal(dt)
	_shield(dt)
	_fire_plots(dt)
	_move_shots(dt)
	_move_spits(dt)
	_move_lobs(dt)


# --- spawning ---------------------------------------------------------------------------

func _spawn_due() -> void:
	while _cursor < _events.size() and _events[_cursor].time <= time:
		var ev: WaveSchedule.Event = _events[_cursor]
		_cursor += 1
		if ev.type == WaveSchedule.EventType.ENEMY:
			var e := Enemy.new()
			e.id = _take_id()
			e.def = ev.enemy
			e.path = ev.path
			e.elite = ev.elite
			e.max_hp = ev.enemy.hp * _wave.hp_scale * (e.elite.hp_mult if e.elite else 1.0)
			e.hp = e.max_hp
			e.speed = ev.enemy.speed * _wave.speed_scale * (e.elite.speed_mult if e.elite else 1.0)
			e.offset = _spread(ev.path, e.id, ev.enemy.radius)
			_arrive(e)
			_place_enemy(e)
			path_enemies[e.path].append(e)
			enemy_spawned.emit(e)
			_check_phases(e)
		else:
			var c := Crate.new()
			c.id = _take_id()
			c.def = ev.crate
			c.path = ev.path
			c.hp = ev.crate.hp
			_place_crate(c)
			path_crates[c.path].append(c)
			crate_spawned.emit(c)


## Set up a new enemy's own clocks (spawns and a Splitter's brood alike).
func _arrive(e: Enemy) -> void:
	e.burrow_timer = e.def.burrow_every
	if _is_warden(e.def):
		_wardens += 1
	if e.def.is_boss:
		bosses.append(e)


static func _is_warden(def: EnemyDef) -> bool:
	return def.shield_radius > 0.0 and def.shield_amount > 0.0


## Deterministic spread around the path's centre line, so its enemies don't walk in one file.
func _spread(path: int, id: int, radius: float) -> float:
	var k: float = float((id * 37) % 61) / 30.0 - 1.0
	return k * RunConfig.jitter_for(config.map.paths[path].spread, radius)


## x, y from the path at the enemy's d, pushed sideways by its offset (its segment is cached:
## this runs for every walking enemy every tick).
func _place_enemy(e: Enemy) -> void:
	var geo: PathGeo = geos[e.path]
	e.seg = geo.segment_from(e.seg, e.d)
	var p: Vector2 = geo.point_on(e.seg, e.d, e.offset)
	e.x = p.x
	e.y = p.y


func _place_crate(c: Crate) -> void:
	var p: Vector2 = geos[c.path].point_at(c.d)
	c.x = p.x
	c.y = p.y


func _take_id() -> int:
	_next_id += 1
	return _next_id - 1


# --- movement ---------------------------------------------------------------------------

func _move_enemies(dt: float) -> void:
	for path: int in geos.size():
		var geo: PathGeo = geos[path]
		var enemies: Array = path_enemies[path]
		# Escort checks only matter if the path holds something big enough to block anyone.
		var biggest: float = 0.0
		for e: Enemy in enemies:
			biggest = maxf(biggest, e.def.radius)
		for i: int in enemies.size():
			var e: Enemy = enemies[i]
			if e.slow_timer > 0.0:
				e.slow_timer = maxf(0.0, e.slow_timer - dt)
				if e.slow_timer == 0.0:
					e.slow_factor = 1.0
			if e.elite != null and e.elite.regen > 0.0:
				e.hp = minf(e.max_hp, e.hp + e.max_hp * e.elite.regen * dt)
			if e.stun > 0.0:
				e.stun = maxf(0.0, e.stun - dt)
				continue  # frozen solid: no walking, no striking
			if e.pause > 0.0:
				e.pause = maxf(0.0, e.pause - dt)
				continue  # a boss phase playing out
			if e.sieging and e.at_barricade and not _blocks(e):
				# The barricade broke (or was never rebuilt): walk on.
				e.sieging = false
				e.at_barricade = false
			if e.sieging and e.target_plot != null and e.target_plot.is_empty():
				# The unit fell (to it or to another): walk on.
				e.sieging = false
				e.target_plot = null
			if e.sieging:
				e.strike_timer -= dt
				if e.strike_timer <= READY_EPSILON:
					_strike(e)
				continue
			var before: float = e.d
			e.d += e.speed * e.slow_factor * _terrain_speed(e) * dt
			var escort: Enemy = _big_one_ahead(enemies, i) \
					if biggest >= e.def.radius + ESCORT_SIZE_GAP and e.on_ground() else null
			if escort != null:
				e.d = minf(e.d, maxf(before, escort.d - (escort.def.radius + e.def.radius) * 0.7))
			_burrow(e, geo, dt)
			if e.def.siege_range > 0.0 and not e.burrowed():
				var post: float = maxf(0.0, geo.length - e.def.siege_range)
				var walled: bool = _blocks(e) and e.on_ground() and _barricade_stop(e) < post
				if before <= post and e.d >= post and not walled:
					e.d = post
					_place_enemy(e)
					e.sieging = true
					e.lobbing = true
					e.strike_timer = 0.0
					_strike(e)
					continue
			if _blocks(e) and e.on_ground():
				var stop: float = _barricade_stop(e)
				if before <= stop and e.d >= stop:
					e.d = stop
					_place_enemy(e)
					e.sieging = true
					e.at_barricade = true
					e.strike_timer = 0.0
					_strike(e)
					continue
			if e.def.unit_reach > 0.0:
				_place_enemy(e)
				var prey: Plot = unit_in_reach(e)
				if prey != null:
					e.sieging = true
					e.target_plot = prey
					e.strike_timer = 0.0
					_strike(e)
					continue
			if e.d >= geo.length:
				e.d = geo.length
				_surface(e)
				_place_enemy(e)
				e.sieging = true
				e.strike_timer = 0.0
				_strike(e)
				continue
			_place_enemy(e)
		_sort_desc(enemies)


## Burrowers: count down surface time (paused while slowed), dive for burrow_length (never
## where it would surface within reach of the gate: it must come up to strike), and surface
## once `d` reaches the far end. Frozen or sieging enemies don't get here.
func _burrow(e: Enemy, geo: PathGeo, dt: float) -> void:
	if e.def.burrow_every <= 0.0 or e.def.burrow_length <= 0.0:
		return
	if e.burrowed():
		if e.d >= e.surface_d:
			_surface(e)
		return
	if e.slow_factor < 1.0:
		return  # chilled: too stiff to dig (why Frost counters it)
	e.burrow_timer -= dt
	if e.burrow_timer > 0.0:
		return
	if e.d + e.def.burrow_length >= geo.length - e.def.radius:
		e.burrow_timer = 0.0  # too near the gate: it stays up
		return
	e.surface_d = e.d + e.def.burrow_length
	enemy_burrowed.emit(e)


func _surface(e: Enemy) -> void:
	if not e.burrowed():
		return
	e.surface_d = -1.0
	e.burrow_timer = e.def.burrow_every
	enemy_surfaced.emit(e)


## Mud slows whoever walks through it (zones multiply); flyers and burrowers pass it.
func _terrain_speed(e: Enemy) -> float:
	if _mud.is_empty() or not e.on_ground():
		return 1.0
	var k: float = 1.0
	for zone: ZoneDef in _mud:
		if zone.contains(Vector2(e.x, e.y)):
			k *= zone.value
	return k


## Escorts: a small enemy can't walk through a much bigger one ahead of it on its path (it
## bunches up behind, shielded from units that shoot "first in reach"). Only the few enemies
## just ahead are checked (the path is sorted, furthest along first), so this stays ~linear.
func _big_one_ahead(enemies: Array, i: int) -> Enemy:
	for k: int in range(i - 1, maxi(-1, i - 1 - ESCORT_LOOKAHEAD), -1):
		var a: Enemy = enemies[k]
		var e: Enemy = enemies[i]
		if a.def.radius >= e.def.radius + ESCORT_SIZE_GAP and a.on_ground() and not a.lobbing \
				and absf(a.offset - e.offset) < (a.def.radius + e.def.radius) * 0.9:
			return a
	return null


## True if the barricade stands on `e`'s path.
func _blocks(e: Enemy) -> bool:
	return barricade.is_standing() and barricade.blocks(e.path)


## Where (distance along its path) an enemy stops in front of the barricade.
func _barricade_stop(e: Enemy) -> float:
	return barricade.stop_d[e.path] - e.def.radius * 0.5


## The built plot nearest `e` within its unit_reach (ties: lower index), or null.
func unit_in_reach(e: Enemy) -> Plot:
	var best: Plot = null
	var best_d: float = e.def.unit_reach * e.def.unit_reach
	for plot: Plot in plots:
		if plot.is_empty():
			continue
		var d: float = plot.position.distance_squared_to(e.pos())
		if d <= best_d and (best == null or d < best_d):
			best_d = d
			best = plot
	return best


## A stopped enemy strikes what it stopped for (the barricade, a unit, or the gate); the next
## strike comes one attack_interval later.
func _strike(e: Enemy) -> void:
	e.strike_timer += maxf(0.05, e.def.attack_interval)
	if e.target_plot != null:
		var plot: Plot = e.target_plot
		plot.hp = maxf(0.0, plot.hp - e.def.unit_damage)
		unit_struck.emit(plot, e, e.def.unit_damage)
		if plot.hp <= 0.0:
			destroy_unit(plot)
		return
	if e.at_barricade:
		barricade.hp = maxf(0.0, barricade.hp - e.def.wall_damage)
		barricade_struck.emit(e, e.def.wall_damage)
		if barricade.hp <= 0.0:
			barricade_broken.emit()
		return
	if e.lobbing:
		_lob(e)
		return
	pending_wall_damage += e.def.wall_damage
	enemy_struck.emit(e, e.def.wall_damage)
	if mods.gate_thorns > 0.0:
		_queued_thorns.append(e)
		_queued_thorn_damage.append(mods.gate_thorns * maxf(0.05, e.def.attack_interval))


## A Bombardier's strike: a glob flies from it to the gate below its path's end.
func _lob(e: Enemy) -> void:
	var lob := Lob.new()
	lob.id = _take_id()
	lob.enemy = e
	lob.start = e.pos()
	var end: Vector2 = geos[e.path].point_at(geos[e.path].length)
	lob.dest = Vector2(end.x, config.wall_y)
	lob.pos = lob.start
	lob.duration = maxf(0.05, e.def.lob_time)
	lob.damage = e.def.wall_damage
	lobs.append(lob)
	enemy_lobbed.emit(lob)


## Globs fly on (a straight line in the sim; the view draws the arc) and hit the gate. No gate
## thorns: the thrower is far away.
func _move_lobs(dt: float) -> void:
	if lobs.is_empty():
		return
	var keep: Array[Lob] = []
	for lob: Lob in lobs:
		lob.t += dt
		lob.pos = lob.start.lerp(lob.dest, minf(1.0, lob.t / lob.duration))
		if lob.t < lob.duration:
			keep.append(lob)
			continue
		pending_wall_damage += lob.damage
		enemy_struck.emit(lob.enemy, lob.damage)
		lob_landed.emit(lob)
	lobs = keep


func _move_crates(dt: float) -> void:
	for path: int in geos.size():
		var crates: Array = path_crates[path]
		for c: Crate in crates:
			c.d += c.def.speed * dt
			_place_crate(c)
		_sort_desc(crates)
		while not crates.is_empty() and (crates[0] as Crate).d >= geos[path].length:
			var lost: Crate = crates.pop_front()
			lost.alive = false
			crate_lost.emit(lost)


## Insertion sort by d descending: paths are almost sorted every tick, so this is ~linear.
static func _sort_desc(items: Array) -> void:
	for i: int in range(1, items.size()):
		var item: Variant = items[i]
		var d: float = item.d
		var j: int = i - 1
		while j >= 0 and items[j].d < d:
			items[j + 1] = items[j]
			j -= 1
		items[j + 1] = item


# --- spitters ---------------------------------------------------------------------------

## Every spitter whose timer is up spits at the nearest working unit within its range. A
## spitter at the gate strikes the gate instead: spitting point-blank at the wall's own spots
## made a death spiral (the units that should kill it were jammed; see the work item log).
func _spit_enemies(dt: float) -> void:
	for group: Array in path_enemies:
		for e: Enemy in group:
			if e.def.spit_interval <= 0.0 or e.sieging or e.stun > 0.0 or e.burrowed():
				continue
			e.spit_timer = maxf(0.0, e.spit_timer - dt)
			if e.spit_timer > READY_EPSILON:
				continue
			var target: Plot = spit_target(e)
			if target == null:
				continue
			e.spit_timer = e.def.spit_interval
			var sp := Spit.new()
			sp.id = _take_id()
			sp.start = e.pos()
			sp.pos = sp.start
			sp.plot = target
			sp.speed = maxf(1.0, e.def.spit_speed)
			sp.duration = e.def.disable_duration
			spits.append(sp)
			spit_fired.emit(sp)


## The built, working plot nearest `e` within its spit range (ties: lower index), or null.
func spit_target(e: Enemy) -> Plot:
	var best: Plot = null
	var best_d: float = e.def.spit_range * e.def.spit_range
	for plot: Plot in plots:
		if plot.is_empty() or plot.is_disabled():
			continue
		var d: float = plot.position.distance_squared_to(e.pos())
		if d <= best_d and (best == null or d < best_d):
			best_d = d
			best = plot
	return best


func _move_spits(dt: float) -> void:
	var keep: Array[Spit] = []
	for sp: Spit in spits:
		var to: Vector2 = sp.plot.position - sp.pos
		var step: float = sp.speed * dt
		if to.length() <= step:
			sp.pos = sp.plot.position
			if not sp.plot.is_empty():
				sp.plot.disabled = maxf(sp.plot.disabled, sp.duration)
				sp.plot.target = null
				unit_disabled.emit(sp.plot, sp.duration)
			continue
		sp.pos += to.normalized() * step
		keep.append(sp)
	spits = keep


# --- units on plots ---------------------------------------------------------------------

func _fire_plots(dt: float) -> void:
	for plot: Plot in plots:
		if plot.is_empty():
			continue
		if plot.disabled > 0.0:
			plot.disabled = maxf(0.0, plot.disabled - dt)
			continue
		plot.cooldown = maxf(0.0, plot.cooldown - dt)
		if plot.target != null and not (plot.target.hittable()
				and _in_reach(plot, plot.target.pos())):
			plot.target = null
		if plot.cooldown > READY_EPSILON:
			if plot.target != null:
				plot.aim = plot.target.pos()
			continue
		plot.target = first_in_reach(plot)
		if plot.target == null:
			continue
		plot.aim = plot.target.pos()
		_fire_plot(plot, plot.target)
		plot.cooldown = plot_reload(plot)


func _in_reach(plot: Plot, p: Vector2) -> bool:
	var reach: float = plot_reach(plot)
	return plot.position.distance_squared_to(p) <= reach * reach


## The enemy nearest the gate (least distance left on its path) within the plot's reach
## ("first"), or null.
##
## Cost matters: idle plots look for a target every tick, over every path. Paths too far from
## the plot are skipped (Plot.path_dist is static). On the others, the reach circle's y range
## maps to a window of distances along the path (y strictly increases along it; the spread is
## the margin for sideways offsets), found by binary search, and only enemies inside it are
## distance-checked: O(paths × log n) per plot (a full scan cost ~5 ms per tick at the stress
## load).
func first_in_reach(plot: Plot) -> Enemy:
	var best: Enemy = null
	var best_left: float = INF
	var reach: float = plot_reach(plot)
	for path: int in geos.size():
		var spread: float = config.map.paths[path].spread
		if plot.path_dist[path] > reach + spread:
			continue
		var geo: PathGeo = geos[path]
		var enemies: Array = path_enemies[path]
		var d_hi: float = geo.d_at_y(plot.position.y + reach + spread)
		var d_lo: float = geo.d_at_y(plot.position.y - reach - spread)
		var i: int = _first_at_or_below(enemies, d_hi)
		while i < enemies.size():
			var e: Enemy = enemies[i]
			if e.d < d_lo or geo.length - e.d >= best_left:
				break
			if _in_reach(plot, e.pos()) and can_target(plot, e):
				best = e
				best_left = geo.length - e.d
				break
			i += 1
	return best


## Whether the unit on `plot` may shoot at `e`: never underground, and shells never at flyers.
static func can_target(plot: Plot, e: Enemy) -> bool:
	if e.burrowed():
		return false
	return not (e.def.flying and plot.def.attack == UnitDef.Attack.SHELL)


## Index of the first enemy (in a d-descending path) with d <= `max_d`.
static func _first_at_or_below(enemies: Array, max_d: float) -> int:
	var lo: int = 0
	var hi: int = enemies.size()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if (enemies[mid] as Enemy).d > max_d:
			lo = mid + 1
		else:
			hi = mid
	return lo


func _fire_plot(plot: Plot, target: Enemy) -> void:
	var def: UnitDef = plot.def
	var m: MasteryDef = plot.mastery
	var syn: StatBonus = plot.syn
	var pierce: float = (m.armor_pierce if m else 0.0) + syn.pierce
	var dmg: float = plot_damage(plot)
	var crit: float = mods.crit_chance + syn.crit
	if crit > 0.0 and rng.stream(&"combat").randf() < crit:
		dmg *= config.crit_multiplier + mods.crit_mult_bonus
	plot.shots_fired += 1
	match def.attack:
		UnitDef.Attack.HITSCAN:
			unit_fired.emit(plot, target.pos())
			_chill(target, syn)
			_damage_enemy(target, dmg, def.damage_type, pierce)
		UnitDef.Attack.BEAM:
			unit_fired.emit(plot, target.pos())
			var victims: Array[Enemy] = []
			var cap: int = def.beam_max_targets + syn.beam_targets if def.beam_max_targets > 0 \
					else 0
			for e: Enemy in path_enemies[target.path]:  # furthest along first
				if e.hittable() and _in_reach(plot, e.pos()):
					victims.append(e)
					if cap > 0 and victims.size() >= cap:
						break
			for e: Enemy in victims:
				_chill(e, syn)
				_damage_enemy(e, dmg, def.damage_type, pierce)
		_:
			var s := Shot.new()
			s.id = _take_id()
			s.plot = plot.index
			s.attack = def.attack
			s.start = plot.position
			s.pos = plot.position
			s.dest = target.pos()
			s.target = target
			s.speed = def.projectile_speed
			s.damage = dmg
			s.damage_type = def.damage_type
			s.armor_pierce = pierce
			s.splash = def.splash_radius * (1.0 + (m.splash_bonus if m else 0.0) + syn.splash)
			if def.slow_duration > 0.0:
				s.slow = clampf(def.slow_factor - mods.frost_slow_bonus
						- (m.slow_bonus if m else 0.0) - syn.slow, 0.2, 1.0)
				s.slow_time = def.slow_duration + (m.slow_time_bonus if m else 0.0) \
						+ syn.slow_time
			elif syn.chill_time > 0.0:
				s.slow = syn.chill  # a synergy's chill: this unit's hits slow briefly
				s.slow_time = syn.chill_time
			else:
				s.slow = 1.0
			if def.attack == UnitDef.Attack.SHELL:
				s.duration = maxf(0.05, s.start.distance_to(s.dest) / s.speed)
			shots.append(s)
			unit_fired.emit(plot, target.pos())


## A synergy's chill on an instant hit (hitscan, beam): slow `e` briefly.
static func _chill(e: Enemy, syn: StatBonus) -> void:
	if syn.chill_time > 0.0:
		e.slow_factor = minf(e.slow_factor, syn.chill)
		e.slow_timer = maxf(e.slow_timer, syn.chill_time)


# --- special attacks --------------------------------------------------------------------

## Call `ability` at `pos` with damage × `power`: it lands ability.delay s later (Run owns the
## choice of ability and its cooldown). Returns the Cast (it is in `casts` until it lands).
func cast(ability: AbilityDef, pos: Vector2, power: float = 1.0) -> Cast:
	var c := Cast.new()
	_cast_ids += 1
	c.id = _cast_ids
	c.ability = ability
	c.pos = pos
	c.t = ability.delay
	c.power = power
	casts.append(c)
	ability_called.emit(c)
	return c


## Count casts down and land the due ones, in call order.
func _land_casts(dt: float) -> void:
	if casts.is_empty():
		return
	var due: Array[Cast] = []
	var keep: Array[Cast] = []
	for c: Cast in casts:
		c.t -= dt
		if c.t > 0.0:
			keep.append(c)
		else:
			due.append(c)
	casts = keep
	for c: Cast in due:
		_land(c)
		ability_landed.emit(c)


func _land(c: Cast) -> void:
	var a: AbilityDef = c.ability
	match a.kind:
		AbilityDef.Kind.STRIKE:
			for e: Enemy in enemies_within(c.pos, a.radius):
				_apply_damage(e, a.damage * c.power)
		AbilityDef.Kind.FREEZE:
			for e: Enemy in enemies_within(c.pos, a.radius):
				e.stun = maxf(e.stun, a.duration)
				e.slow_factor = minf(e.slow_factor, a.slow)
				e.slow_timer = maxf(e.slow_timer, a.duration + a.slow_time)
				if a.damage > 0.0:
					_apply_damage(e, a.damage * c.power)
		AbilityDef.Kind.BURN:
			var road: Array[Stretch] = burn_layout(a, c.pos)
			if road.is_empty():
				return
			var h := Hazard.new()
			h.id = c.id
			h.stretches = road
			h.half_width = burn_half_width(road)
			var box := Rect2(road[0].points[0], Vector2.ZERO)
			for st: Stretch in road:
				for p: Vector2 in st.points:
					box = box.expand(p)
			h.bounds = box.grow(h.half_width)
			h.t = a.duration
			h.duration = a.duration
			h.dps = a.damage * c.power
			hazards.append(h)
		AbilityDef.Kind.MINES:
			_lay_mines(c)
		AbilityDef.Kind.REPAIR:
			pending_gate_heal += a.gate_heal
			for plot: Plot in plots:
				if not plot.is_empty():
					plot.hp = minf(plot.max_hp, plot.hp + plot.max_hp * a.unit_heal)
			if barricade.is_built() and barricade.max_hp > 0.0:
				barricade.hp = minf(barricade.max_hp, barricade.hp + barricade.max_hp * a.unit_heal)


## Every enemy whose body overlaps the circle at `pos` of `radius` (half its radius counts, as
## for shells), not underground. A copy, so the caller may kill them.
func enemies_within(pos: Vector2, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for group: Array in path_enemies:
		for e: Enemy in group:
			var r: float = radius + e.def.radius * 0.5
			if e.hittable() and e.pos().distance_squared_to(pos) <= r * r:
				out.append(e)
	return out


## Burning stretches burn whoever stands on them (within half_width of the centre line, plus
## half its body), then go out.
func _burn(dt: float) -> void:
	if hazards.is_empty():
		return
	var keep: Array[Hazard] = []
	for h: Hazard in hazards:
		var victims: Array[Enemy] = []
		for group: Array in path_enemies:
			for e: Enemy in group:
				if not e.on_ground():
					continue  # flying over the fire, or tunnelling under it
				var p: Vector2 = e.pos()
				var reach: float = e.def.radius * 0.5
				if h.bounds.grow(reach).has_point(p) and _on_fire(h, p, h.half_width + reach):
					victims.append(e)
		for e: Enemy in victims:
			_apply_damage(e, h.dps * dt)
		h.t -= dt
		if h.t > 0.0:
			keep.append(h)
	hazards = keep


## MINES: ability.mine_count mines along the open path nearest the tap (mine_layout).
func _lay_mines(c: Cast) -> void:
	var a: AbilityDef = c.ability
	var layout: Array = mine_layout(a, c.pos)
	if layout.is_empty():
		return
	var path: int = layout[0]
	for d: float in layout[1]:
		var m := Mine.new()
		_cast_ids += 1
		m.id = _cast_ids
		m.path = path
		m.d = d
		m.pos = geos[path].point_at(d)
		m.damage = a.damage * c.power
		m.radius = a.radius
		mines.append(m)


## The open path nearest `pos` and the distance along it of its nearest point, as [path, d];
## empty if no path is open. Aimed attacks that lie on the road (MINES, BURN) snap to it.
func nearest_open_path(pos: Vector2) -> Array:
	var best: int = -1
	var best_near := Vector2(0.0, INF)
	for i: int in open_paths:
		var near: Vector2 = geos[i].nearest(pos)
		if near.y < best_near.y:
			best_near = near
			best = i
	return [] if best < 0 else [best, best_near.x]


## Where a MINES ability called at `pos` lays its mines: [path index, distances along it], on the
## open path nearest `pos`, centred on its nearest point and mine_spacing apart (kept on the
## path). Empty if no path is open. The aim preview draws the same spots.
func mine_layout(a: AbilityDef, pos: Vector2) -> Array:
	var near: Array = nearest_open_path(pos)
	if near.is_empty():
		return []
	var best: int = near[0]
	var ds := PackedFloat32Array()
	for k: int in a.mine_count:
		ds.append(clampf(near[1] + (k - (a.mine_count - 1) / 2.0) * a.mine_spacing,
				0.0, geos[best].length - 1.0))
	return [best, ds]


## Which road a BURN ability called at `pos` sets alight: on every open path through the spot
## nearest `pos` (the nearest path, and any other within 2 px of it there: where paths share a
## road, as at a fork or a merge), a stretch `length` long centred on that spot (shifted to stay
## on the path). Stretches identical to an earlier one (a shared trunk) are dropped. Empty if no
## path is open. The aim preview and the telegraph draw the same road.
func burn_layout(a: AbilityDef, pos: Vector2) -> Array[Stretch]:
	var out: Array[Stretch] = []
	var near: Array = nearest_open_path(pos)
	if near.is_empty():
		return out
	var spot: Vector2 = geos[near[0]].point_at(near[1])
	for i: int in open_paths:
		var on: Vector2 = geos[i].nearest(spot)
		if on.y > 2.0:
			continue
		var st := Stretch.new()
		st.path = i
		var total: float = geos[i].length
		st.d_lo = clampf(on.x - a.length / 2.0, 0.0, maxf(0.0, total - a.length))
		st.d_hi = minf(st.d_lo + a.length, total)
		st.points = geos[i].stretch(st.d_lo, st.d_hi)
		var seen: bool = false
		for other: Stretch in out:
			seen = seen or other.points == st.points
		if not seen:
			out.append(st)
	return out


## How far to each side of the centre line the fire on `road` reaches: the widest sideways
## spread an enemy can have on those paths, plus a margin, so it covers the whole road.
func burn_half_width(road: Array[Stretch]) -> float:
	var spread: float = 0.0
	for st: Stretch in road:
		spread = maxf(spread, config.map.paths[st.path].spread)
	return spread + 8.0


## Whether `p` is within `reach` of any of the hazard's stretches.
static func _on_fire(h: Hazard, p: Vector2, reach: float) -> bool:
	for st: Stretch in h.stretches:
		if PathGeo.distance_to_polyline(st.points, p) <= reach:
			return true
	return false


## A mine goes off when an enemy on its path stands on it (within half its body along the path).
## Mines placed behind a walker wait for the next one.
func _trip_mines() -> void:
	if mines.is_empty():
		return
	var keep: Array[Mine] = []
	for m: Mine in mines:
		var enemies: Array = path_enemies[m.path]
		var tripped: bool = false
		var i: int = _first_at_or_below(enemies, m.d + 40.0)
		while i < enemies.size():
			var e: Enemy = enemies[i]
			var reach: float = e.def.radius * 0.5 + 4.0
			if e.d < m.d - reach:
				break
			if absf(e.d - m.d) <= reach and e.on_ground():
				tripped = true
				break
			i += 1
		if not tripped:
			keep.append(m)
			continue
		for e: Enemy in enemies_within(m.pos, m.radius):
			if e.on_ground():
				_apply_damage(e, m.damage)
		mine_exploded.emit(m)
	mines = keep


func _clear_abilities() -> void:
	casts.clear()
	hazards.clear()
	mines.clear()


## Move unit projectiles and resolve arrivals, in list order (deterministic).
func _move_shots(dt: float) -> void:
	var keep: Array[Shot] = []
	for s: Shot in shots:
		if s.attack == UnitDef.Attack.SHELL:
			s.t += dt
			s.pos = s.start.lerp(s.dest, minf(1.0, s.t / s.duration))
			if s.t >= s.duration:
				_land_shell(s)
				continue
		else:
			if s.target.alive:
				s.dest = s.target.pos()
			var step: float = s.speed * dt
			var to_dest: Vector2 = s.dest - s.pos
			var reach: float = s.target.def.radius if s.target.alive else 0.0
			if to_dest.length() <= step + reach:
				s.pos = s.dest
				if s.target.hittable():
					_bullet_hit(s)
				continue
			s.pos += to_dest.normalized() * step
		keep.append(s)
	shots = keep


func _bullet_hit(s: Shot) -> void:
	var e: Enemy = s.target
	if s.slow_time > 0.0:
		e.slow_factor = minf(e.slow_factor, s.slow)
		e.slow_timer = maxf(e.slow_timer, s.slow_time)
	_damage_enemy(e, s.damage, s.damage_type, s.armor_pierce)


## A shell lands where its target *was*: everything within the splash is hit, and an enemy
## that has moved out of it is missed.
func _land_shell(s: Shot) -> void:
	var victims: Array[Enemy] = []
	for group: Array in path_enemies:
		for e: Enemy in group:
			var r: float = s.splash + e.def.radius * 0.5
			if e.on_ground() and e.pos().distance_squared_to(s.dest) <= r * r:
				victims.append(e)
	for e: Enemy in victims:
		_damage_enemy(e, s.damage, s.damage_type, s.armor_pierce)
	shell_landed.emit(s)


# --- crates: the player's taps -----------------------------------------------------------

## The player tapped field point `p`: the crate under it (within its radius plus
## config.tap_slop, nearest first) takes `damage` (× the crate-damage bonus). True if a crate
## was hit. Units never hit crates; this is the only way to break one.
func tap_crate_at(p: Vector2, damage: float) -> bool:
	var best: Crate = null
	var best_d: float = INF
	for group: Array in path_crates:
		for c: Crate in group:
			var r: float = c.def.radius + config.tap_slop
			var d: float = c.pos().distance_squared_to(p)
			if d <= r * r and d < best_d:
				best_d = d
				best = c
	if best == null:
		return false
	_hit_crate(best, damage)
	return true


func _hit_crate(c: Crate, dmg: float) -> void:
	c.hp -= dmg * (1.0 + mods.crate_damage_bonus)
	if c.hp > 0.0:
		crate_tapped.emit(c)
		return
	c.alive = false
	path_crates[c.path].erase(c)
	var coins: int = Economy.crate_reward(c.def, mods)
	pending_gold += coins
	crates_broken += 1
	if c.def.is_boost():
		boost_mult = c.def.boost_rate_mult
		boost_time = maxf(boost_time, c.def.boost_duration)
		boost_started.emit(c)
	crate_broken.emit(c, coins)


## Apply a hit of `raw` damage of `type` through the counter chart.
func _damage_enemy(e: Enemy, raw: float, type: UnitDef.DamageType, pierce: float = 0.0) -> void:
	if not e.alive:
		return
	var dmg: float = effective_damage(config, e.def, raw, type, pierce, e.extra_armor())
	if dmg > raw + 1e-4:
		enemy_hit.emit(e, dmg, 1)
	elif dmg < raw - 1e-4:
		enemy_hit.emit(e, dmg, -1)
	_apply_damage(e, dmg)


## Take `dmg` off `e` as is (past the chart): a guarded boss takes none, its shield soaks it
## first, then hp. A kill pays out and may split; a boss's falling hp may fire its phases.
func _apply_damage(e: Enemy, dmg: float) -> void:
	if not e.alive or e.guards > 0:
		return
	if e.shield > 0.0:
		var soak: float = minf(e.shield, dmg)
		e.shield -= soak
		dmg -= soak
		shield_hit.emit(e, soak)
		if dmg <= 0.0:
			return
	e.hp -= dmg
	if e.hp <= 0.0:
		e.alive = false
		if _is_warden(e.def):
			_wardens -= 1
		if e.def.is_boss:
			bosses.erase(e)
		if e.guarding != null:
			e.guarding.guards = maxi(0, e.guarding.guards - 1)
		path_enemies[e.path].erase(e)
		var gold: int = Economy.kill_reward(e.def, mods)
		pending_gold += gold
		kills += 1
		enemy_killed.emit(e, gold)
		if e.def.split_into != null and e.def.split_count > 0:
			_split(e)
	elif e.def.is_boss:
		_check_phases(e)  # only bosses have phases (content_test checks it)


## A Splitter bursts: its brood appears where it fell (just behind, spread sideways), scaled by
## the wave like any spawn; elite properties are not inherited. Inserted in sorted position,
## because this can happen mid-tick and targeting binary-searches the path.
func _split(parent: Enemy) -> void:
	var kind: EnemyDef = parent.def.split_into
	var spread: float = RunConfig.jitter_for(config.map.paths[parent.path].spread, kind.radius)
	for k: int in parent.def.split_count:
		var child := Enemy.new()
		child.id = _take_id()
		child.def = kind
		child.path = parent.path
		child.d = maxf(0.0, parent.d - k * 6.0)
		child.offset = clampf(parent.offset + (k - (parent.def.split_count - 1) / 2.0) * 12.0,
				-spread, spread)
		child.max_hp = kind.hp * _wave.hp_scale
		child.hp = child.max_hp
		child.speed = kind.speed * _wave.speed_scale
		_arrive(child)
		_place_enemy(child)
		_insert_sorted(path_enemies[child.path], child)
		enemy_spawned.emit(child)


## Fire every phase of boss `e` whose threshold its hp has reached, in order, once each.
func _check_phases(e: Enemy) -> void:
	var phases: Array[BossPhase] = e.def.phases
	while e.alive and e.next_phase < phases.size() \
			and e.hp <= phases[e.next_phase].at_hp_fraction * e.max_hp + 1e-4:
		var index: int = e.next_phase
		e.next_phase += 1
		_fire_phase(e, phases[index])
		boss_phase.emit(e, index)


## A phase plays out: the boss's armour and speed change, it may stop, and the phase's spawns
## appear just ahead of it (staggered along the path, spread sideways), scaled by the wave.
## Inserted in sorted position: this can run mid-tick, from a hit.
func _fire_phase(boss: Enemy, ph: BossPhase) -> void:
	boss.armor_bonus += ph.armor_delta
	boss.speed *= ph.speed_mult
	boss.pause = maxf(boss.pause, ph.pause_seconds)
	if ph.spawn == null or ph.spawn_count <= 0:
		return
	var kind: EnemyDef = ph.spawn
	var geo: PathGeo = geos[boss.path]
	var spread: float = RunConfig.jitter_for(config.map.paths[boss.path].spread, kind.radius)
	for k: int in ph.spawn_count:
		var child := Enemy.new()
		child.id = _take_id()
		child.def = kind
		child.path = boss.path
		# Clear of its body (the sprite is drawn bigger than the radius), staggered in rows.
		child.d = minf(boss.d + boss.def.radius * 1.3 + kind.radius + 8.0 * (k % 3),
				maxf(0.0, geo.length - 1.0))
		var side: float = 0.0 if ph.spawn_count == 1 \
				else float(k) / float(ph.spawn_count - 1) * 2.0 - 1.0
		child.offset = side * spread
		child.max_hp = kind.hp * _wave.hp_scale
		child.hp = child.max_hp
		child.speed = kind.speed * _wave.speed_scale
		if ph.keep_pace:
			child.speed = minf(child.speed, boss.speed)
		if ph.guard:
			child.guarding = boss
			boss.guards += 1
		_arrive(child)
		_place_enemy(child)
		_insert_sorted(path_enemies[child.path], child)
		enemy_spawned.emit(child)


## Insert `e` into a d-descending path list, keeping it sorted.
static func _insert_sorted(enemies: Array, e: Enemy) -> void:
	var i: int = _first_at_or_below(enemies, e.d)
	enemies.insert(i, e)


## Menders heal every other enemy within their radius; a pulse is reported once a second.
func _heal(dt: float) -> void:
	for group: Array in path_enemies:
		for m: Enemy in group:
			if m.def.heal_radius <= 0.0 or m.def.heal_per_second <= 0.0 or m.stun > 0.0:
				continue
			var r2: float = m.def.heal_radius * m.def.heal_radius
			var healed: bool = false
			for other_group: Array in path_enemies:
				for o: Enemy in other_group:
					if o != m and o.hp < o.max_hp and o.pos().distance_squared_to(m.pos()) <= r2:
						o.hp = minf(o.max_hp, o.hp + o.max_hp * m.def.heal_per_second * dt)
						healed = true
			m.pulse_timer -= dt
			if healed and m.pulse_timer <= 0.0:
				m.pulse_timer = 1.0
				mender_pulse.emit(m)


## Wardens' auras: every enemy within a live, unfrozen, surfaced Warden's shield_radius (the
## Warden included) is capped at that aura's strength (shield_amount × the Warden's hp scale;
## the strongest aura counts) and refills toward it at shield_regen a second. Outside every
## aura a shield keeps what it has but doesn't refill. O(wardens × enemies), and skipped
## entirely while no Warden is on the field.
func _shield(dt: float) -> void:
	if _wardens <= 0:
		return
	# 10 times a second, with the elapsed time: the aura is a slow effect, and the all-pairs
	# check cost ~0.5 ms a tick at the mixed stress load when run every tick.
	_shield_clock += dt
	if _shield_clock < SHIELD_PERIOD - READY_EPSILON:
		return
	dt = _shield_clock
	_shield_clock = 0.0
	for group: Array in path_enemies:
		for e: Enemy in group:
			e.shield_max = 0.0
	for group: Array in path_enemies:
		for w: Enemy in group:
			if not _is_warden(w.def) or w.stun > 0.0 or w.burrowed():
				continue
			var cap: float = w.def.shield_amount * w.max_hp / maxf(0.001, w.def.hp)
			var r2: float = w.def.shield_radius * w.def.shield_radius
			for other_group: Array in path_enemies:
				for o: Enemy in other_group:
					if cap > o.shield_max and o.pos().distance_squared_to(w.pos()) <= r2:
						if o.shield < cap:
							o.shield = minf(cap, o.shield + w.def.shield_regen * dt)
						o.shield_max = cap


## Apply the damage queued during the move pass: Last Stand blasts, then gate thorns.
func _resolve_queued() -> void:
	if not _queued_blasts.is_empty():
		var blasts: Array[Vector3] = _queued_blasts.duplicate()
		_queued_blasts.clear()
		var r: float = config.death_blast_radius
		for b: Vector3 in blasts:
			var at := Vector2(b.x, b.y)
			var victims: Array[Enemy] = []
			for group: Array in path_enemies:
				for e: Enemy in group:
					var reach: float = r + e.def.radius * 0.5
					if e.hittable() and e.pos().distance_squared_to(at) <= reach * reach:
						victims.append(e)
			for e: Enemy in victims:
				_damage_enemy(e, b.z, UnitDef.DamageType.EXPLOSIVE)
	if not _queued_thorns.is_empty():
		for i: int in _queued_thorns.size():
			_apply_damage(_queued_thorns[i], _queued_thorn_damage[i])
		_queued_thorns.clear()
		_queued_thorn_damage.clear()


## The unit on `plot` falls: the plot empties (no refund) and anything aiming at it lets go.
## With Last Stand (RunModifiers.death_blast) it explodes: death_blast × its level, queued.
func destroy_unit(plot: Plot) -> void:
	if plot.is_empty():
		return
	var def: UnitDef = plot.def
	if mods.death_blast > 0.0:
		_queued_blasts.append(Vector3(plot.position.x, plot.position.y,
				mods.death_blast * plot.level))
		unit_blast.emit(plot.position, config.death_blast_radius)
	plot.def = null
	plot.level = 0
	plot.mastery = null
	plot.spent = 0
	plot.hp = 0.0
	plot.max_hp = 0.0
	plot.cooldown = 0.0
	plot.disabled = 0.0
	plot.target = null
	refresh_synergies()
	unit_destroyed.emit(plot, def)
