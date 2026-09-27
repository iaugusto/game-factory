class_name RunController
extends Node2D
## Root of scenes/run.tscn. Ticks a core Run at the fixed rate, renders its state and forwards
## input. Holds no rules (CLAUDE.md §4): everything it shows, it reads from Run/CombatSim, and
## every action (tap a crate, build, upgrade, card, start wave) is a Run call.
##
## Input is taps only: every unit is fixed on a plot, so there is nothing to steer. A press on a
## crate taps it (Run.tap); a press on a plot opens its build menu.
##
## Launch arguments (after `--`):
##   --seed=N            fixed run seed (default: random)
##   --map=ID            which map to play (default: the first in RunConfig.maps)
##   --autoplay          the scripted player plays (taps crates, builds, picks cards, starts waves)
##   --skip-to-wave=K    fast-forward (autoplayed, not rendered) to the BUILD phase of wave K
##   --skip=S            then start that wave and fast-forward S seconds into it
##   --stress            DEV ONLY: a synthetic budget-load wave (~260 enemies, all plots firing)
##   --open-plot=N       DEV ONLY: open plot N's build menu at start (for screenshots)
##   --perf              print frame-time stats every 5 s
##   --quit-on-end       print a summary and quit when the run ends
##
## Tests drive it without real time: tick(n), sync_views(), handle_pointer(event),
## open_plot(i), start_wave(), and the UI nodes' own methods.

const CONFIG_PATH: String = "res://data/run_config.tres"
const AUTO_DELAY: float = 1.0
## The breach when the gate falls: slow motion for this long (real seconds), then the result
## fades in.
const BREACH_TIME: float = 1.2
const BREACH_TIME_SCALE: float = 0.3
const PERF_WINDOW: float = 5.0

## Everything in res://data/run_config.tres; `config` is it for the map being played.
var base_config: RunConfig
var config: RunConfig
var run: Run
var bot := Autoplay.new()
var autoplay: bool = false
var quit_on_end: bool = false

var field: Node2D
var field_view: FieldView
var plot_field: PlotField
var crate_field: CrateField
var enemy_field: EnemyField
var shot_field: ShotField
var fx: Fx
var hud: Hud
var build_bar: BuildBar
var barricade_field: BarricadeField
var barricade_menu: BarricadeMenu
var intel_card: IntelCard
var build_menu: BuildMenu
var card_picker: CardPicker
var overlay: PhaseOverlay

## True while fast-forwarding: views still track state, but no effects fire.
var _skipping: bool = false
var _auto_timer: float = -1.0
## Real seconds of breach slow motion left (the gate fell).
var _breach_timer: float = 0.0
## Chart hit feedback is throttled: at most this many sparks/pings per second each.
const HIT_FX_PER_SECOND: float = 14.0
var _hit_fx_budget: Vector2 = Vector2.ZERO
var _stress: bool = false
var _perf: bool = false
var _perf_frames: int = 0
var _perf_time: float = 0.0
var _perf_max_frame: float = 0.0
var _perf_tick: float = 0.0
var _perf_warmup: int = 60
var _perf_last_usec: int = 0
var _perf_peak_enemies: int = 0
var _perf_peak_shots: int = 0


func _ready() -> void:
	base_config = load(CONFIG_PATH)
	Engine.physics_ticks_per_second = base_config.tick_rate
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var chosen: MapDef = base_config.map_by_id(StringName(args.get("map", "")))
	config = base_config.for_map(chosen if chosen != null else base_config.map)
	autoplay = args.has("autoplay")
	quit_on_end = args.has("quit-on-end")
	_perf = args.has("perf")
	_stress = args.has("stress")
	if _stress:
		config = _stress_config(config)
	_build_nodes()
	var run_seed: int = int(args.get("seed", "0"))
	start_run(run_seed if run_seed != 0 else randi())
	if _stress:
		_fill_plots_for_stress()
	if args.has("skip-to-wave"):
		fast_forward_to_wave(int(args["skip-to-wave"]))
	if args.has("skip"):
		fast_forward_seconds(float(args["skip"]))
	if args.has("open-plot"):
		open_plot.call_deferred(int(args["open-plot"]))
	get_viewport().size_changed.connect(_layout)
	_layout()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# --- setup ------------------------------------------------------------------------------

func _build_nodes() -> void:
	field = Node2D.new()
	add_child(field)
	field_view = FieldView.new()
	field_view.setup(config)
	field.add_child(field_view)
	plot_field = PlotField.new()
	field.add_child(plot_field)
	barricade_field = BarricadeField.new()
	field.add_child(barricade_field)
	crate_field = CrateField.new()
	field.add_child(crate_field)
	enemy_field = EnemyField.new()
	enemy_field.setup(config)
	field.add_child(enemy_field)
	shot_field = ShotField.new()
	field.add_child(shot_field)
	fx = Fx.new()
	fx.bounds_width = config.playfield_width()
	fx.coin_arrived.connect(func() -> void: hud.pulse_coins())
	field.add_child(fx)
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	build_bar = BuildBar.new()
	build_bar.start_pressed.connect(start_wave)
	build_bar.repair_pressed.connect(_on_repair_gate)
	ui.add_child(build_bar)
	barricade_menu = BarricadeMenu.new()
	barricade_menu.build_requested.connect(_on_barricade_build)
	barricade_menu.upgrade_requested.connect(_on_barricade_upgrade)
	barricade_menu.repair_requested.connect(_on_barricade_repair)
	barricade_menu.closed.connect(_on_menu_closed)
	ui.add_child(barricade_menu)
	build_menu = BuildMenu.new()
	build_menu.build_requested.connect(_on_build_requested)
	build_menu.upgrade_requested.connect(_on_upgrade_requested)
	build_menu.sell_requested.connect(_on_sell_requested)
	build_menu.repair_requested.connect(_on_repair_unit)
	build_menu.mastery_requested.connect(_on_mastery_requested)
	build_menu.closed.connect(_on_menu_closed)
	ui.add_child(build_menu)
	intel_card = IntelCard.new()
	ui.add_child(intel_card)
	card_picker = CardPicker.new()
	card_picker.picked.connect(_on_card_picked)
	ui.add_child(card_picker)
	overlay = PhaseOverlay.new()
	overlay.restart_pressed.connect(func() -> void: start_run(randi()))
	overlay.next_map_pressed.connect(func() -> void:
		switch_map(next_map())
		start_run(randi()))
	ui.add_child(overlay)


## Centre the playfield horizontally in whatever width the window has.
func _layout() -> void:
	field.position = field_origin()


func field_origin() -> Vector2:
	var view: Vector2 = get_viewport_rect().size
	return Vector2((view.x - config.playfield_width()) / 2.0, Hud.HEIGHT)


## The map after the current one in RunConfig.maps (wrapping), or null if there's only one.
func next_map() -> MapDef:
	var maps: Array[MapDef] = base_config.maps
	if maps.size() < 2:
		return null
	return maps[(maps.find(config.map) + 1) % maps.size()]


## Play `m` from the next run on (views that depend on the map are rebuilt by start_run).
func switch_map(m: MapDef) -> void:
	if m == null:
		return
	config = base_config.for_map(m)
	field_view.setup(config)
	enemy_field.setup(config)


func start_run(run_seed: int) -> void:
	_close_menus()
	enemy_field.clear()
	crate_field.clear()
	field_view.clear_decals()
	fx.clear()
	overlay.visible = false
	card_picker.visible = false
	_auto_timer = -1.0
	_breach_timer = 0.0
	run = Run.new(config, run_seed)
	var sim: CombatSim = run.combat
	sim.enemy_killed.connect(_on_enemy_killed)
	sim.enemy_struck.connect(_on_enemy_struck)
	sim.spit_fired.connect(_on_spit_fired)
	sim.unit_disabled.connect(_on_unit_disabled)
	sim.crate_spawned.connect(_on_crate_spawned)
	sim.crate_broken.connect(_on_crate_broken)
	sim.crate_tapped.connect(_on_crate_tapped)
	sim.crate_lost.connect(_on_crate_lost)
	sim.unit_fired.connect(_on_unit_fired)
	sim.shell_landed.connect(_on_shell_landed)
	sim.boost_started.connect(_on_boost_started)
	sim.enemy_hit.connect(_on_enemy_hit)
	sim.barricade_struck.connect(_on_barricade_struck)
	sim.barricade_broken.connect(_on_barricade_broken)
	sim.unit_struck.connect(_on_unit_struck)
	sim.unit_destroyed.connect(_on_unit_destroyed)
	sim.mender_pulse.connect(_on_mender_pulse)
	run.phase_changed.connect(_on_phase_changed)
	plot_field.setup(run)
	barricade_field.setup(run)
	print("run seed %d on %s" % [run_seed, config.map.id])
	_on_phase_changed(run.phase)
	if not autoplay:
		fx.popup(config.map.display_name.to_upper(), Vector2(config.playfield_width() / 2.0, 250),
				UiTheme.ACCENT, 30, 2.0, 20.0)
	sync_views()


# --- simulation -------------------------------------------------------------------------

## Advance `n` fixed ticks of the WAVE phase (the scripted player plays if enabled).
func tick(n: int = 1) -> void:
	for i: int in n:
		if run.phase != Run.Phase.WAVE:
			return
		if autoplay or _skipping:
			bot.step_wave(run)
		else:
			run.step()


func _physics_process(_delta: float) -> void:
	tick(1)


## BUILD → WAVE (the build bar's button, autoplay, or a test).
func start_wave() -> void:
	_close_menus()
	run.start_wave()


## Fast-forward, unrendered, to the BUILD phase before wave `wave_number` (1-based), with the
## scripted player making every decision.
func fast_forward_to_wave(wave_number: int) -> void:
	_skipping = true
	var target: int = clampi(wave_number, 1, run.wave_count()) - 1
	while not run.is_over() and not (run.phase == Run.Phase.BUILD and run.wave_index >= target):
		_advance_skipping()
	_skipping = false
	_after_skip()


## Start the wave if in BUILD, then fast-forward `seconds` into it.
func fast_forward_seconds(seconds: float) -> void:
	_skipping = true
	if run.phase == Run.Phase.BUILD:
		bot.play_build(run)
		run.start_wave()
	var ticks: int = roundi(seconds * config.tick_rate)
	var start: int = run.ticks
	while run.phase == Run.Phase.WAVE and run.ticks - start < ticks:
		tick(1)
	_skipping = false
	_after_skip()


func _advance_skipping() -> void:
	match run.phase:
		Run.Phase.WAVE:
			tick(1)
		Run.Phase.BUILD:
			bot.play_build(run)
			run.start_wave()
		Run.Phase.CARD:
			run.pick_card(0)


func _after_skip() -> void:
	fx.clear()
	field_view.clear_decals()
	_on_phase_changed(run.phase)
	sync_views()


# --- rendering --------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Real time (not slowed by the build menu's time scale) for UI and the autoplayer's pauses.
	var real: float = delta / maxf(Engine.time_scale, 0.001)
	sync_views(delta)
	field.position = field_origin() + fx.shake_offset()
	fx.coin_target = hud.coin_icon_center() - field.position
	build_menu.sync(run)
	barricade_menu.sync(run)
	if build_bar.visible:
		build_bar.sync(run)
	_hit_fx_budget = Vector2(minf(HIT_FX_PER_SECOND, _hit_fx_budget.x + HIT_FX_PER_SECOND * real),
			minf(HIT_FX_PER_SECOND, _hit_fx_budget.y + HIT_FX_PER_SECOND * real))
	if _breach_timer > 0.0:
		_breach_timer -= real
		if _breach_timer <= 0.0:
			Engine.time_scale = 1.0
	if _auto_timer >= 0.0:
		_auto_timer -= real
		if _auto_timer < 0.0:
			_autoplay_decide()
	if _perf:
		_sample_perf(delta)


## Copy core state onto the views. Safe to call any number of times.
func sync_views(delta: float = 0.0) -> void:
	var sim: CombatSim = run.combat
	enemy_field.sync(sim, delta)
	crate_field.sync(delta)
	plot_field.sync(run, delta)
	barricade_field.sync(delta)
	shot_field.sync(run)
	field_view.wall_ratio = run.wall_hp() / run.wall_max()
	field_view.wave_number = run.wave_index + 1
	hud.sync(run, delta)


func _banner(text: String, color: Color = Color("#ffe8a0"), size: int = 50) -> void:
	if _skipping:
		return
	fx.popup(text, Vector2(config.playfield_width() / 2.0, 330), color, size, 1.6, 30.0)


# --- core signals -> views and effects --------------------------------------------------

func _on_enemy_killed(e: CombatSim.Enemy, gold: int) -> void:
	if not _skipping:
		var pos: Vector2 = e.pos()
		fx.death(pos, e.def.color, e.def.radius)
		field_view.add_decal("fx/splat", pos, Color(e.def.color.darkened(0.45), 0.55),
				e.def.radius / 22.0, float(e.id % 7))
		if gold >= 3:
			fx.popup("+%d" % gold, pos, UiTheme.ACCENT, 18)
	enemy_field.forget(e.id)


## An enemy at the gate struck it: sparks where it hit, and the damage.
func _on_enemy_struck(e: CombatSim.Enemy, damage: float) -> void:
	if _skipping:
		return
	var p := Vector2(e.x, config.wall_y - FieldView.WALL_TOP_OFFSET)
	fx.gate_strike(p, damage)
	fx.popup("-%d" % roundi(damage), p - Vector2(0, 26), UiTheme.BAD, 20, 0.7, 30.0)


func _on_spit_fired(sp: CombatSim.Spit) -> void:
	if not _skipping:
		fx.flash("fx/glow", sp.start, 0.2, 0.6, Color(0.83, 1.0, 0.35, 0.8), 0.15)


## A glob landed: the unit is gooed and shut down for a while.
func _on_unit_disabled(plot: CombatSim.Plot, duration: float) -> void:
	if _skipping:
		return
	fx.acid_splash(plot.position)
	fx.popup("JAMMED %ds" % roundi(duration), plot.position - Vector2(0, 34),
			Color(0.83, 1.0, 0.35), 15, 0.9, 30.0)


## The gate breaks: a heavy shake, blasts along the wall, the banner, and a moment of slow
## motion before the result fades in.
func _breach() -> void:
	if _skipping:
		return
	fx.shake(24.0)
	for i: int in 5:
		var x: float = config.playfield_width() * (0.1 + 0.2 * i)
		fx.wall_hit(Vector2(x, config.wall_y - FieldView.WALL_TOP_OFFSET), 20.0)
	_banner("THE GATE HAS FALLEN", UiTheme.BAD, 38)
	Engine.time_scale = BREACH_TIME_SCALE
	_breach_timer = BREACH_TIME


func _on_crate_spawned(c: CombatSim.Crate) -> void:
	crate_field.bind(c)


func _on_crate_broken(c: CombatSim.Crate, coins: int) -> void:
	if not _skipping:
		fx.crate_break(c.pos(), c.def.color, coins)
		fx.popup("+%d" % coins, c.pos() - Vector2(0, 20), UiTheme.ACCENT, 26, 0.9, 60.0)
	crate_field.release(c.id)


func _on_crate_tapped(c: CombatSim.Crate) -> void:
	if not _skipping:
		fx.crate_tap(c.pos(), c.def.color)


func _on_crate_lost(c: CombatSim.Crate) -> void:
	if not _skipping:
		fx.poof(c.pos())
	crate_field.release(c.id)


func _on_unit_fired(plot: CombatSim.Plot, target: Vector2) -> void:
	if _skipping:
		return
	var dir: Vector2 = (target - plot.position).normalized()
	match plot.def.attack:
		UnitDef.Attack.HITSCAN:
			fx.tracer(plot.position + dir * 26.0, target, plot.def.color)
		UnitDef.Attack.BEAM:
			fx.beam(plot.position + dir * 24.0, plot.position + dir * run.combat.plot_reach(plot),
					plot.def.color)


func _on_shell_landed(s: CombatSim.Shot) -> void:
	if _skipping:
		return
	fx.explosion(s.dest, s.splash)
	field_view.add_decal("fx/scorch", s.dest, Color(1, 1, 1, 0.7), s.splash / 30.0, float(s.id % 5))


func _on_boost_started(_c: CombatSim.Crate) -> void:
	if _skipping:
		return
	_banner("OVERDRIVE!", UiTheme.TEAL, 44)
	for plot: CombatSim.Plot in run.plots:
		if not plot.is_empty():
			fx.ring(plot.position, UiTheme.TEAL, 60.0, 0.5)


func _on_phase_changed(phase: Run.Phase) -> void:
	_close_menus()
	build_bar.visible = phase == Run.Phase.BUILD and not autoplay
	match phase:
		Run.Phase.BUILD:
			build_bar.show_for(run.wave_index + 1, run.wave_count(), run)
			build_bar.visible = not autoplay
			if not autoplay and not _skipping:
				intel_card.show_enemies(config, WaveSchedule.new_enemies(config.waves,
						run.wave_index))
			if not run.newly_open_paths().is_empty() and not _skipping:
				fx.popup("NEW BREACH!", Vector2(config.playfield_width() / 2.0, 250),
						UiTheme.BAD, 34, 2.4, 20.0)
				fx.shake(8.0)
			_banner("WAVE %d INCOMING" % (run.wave_index + 1), Color("#ffe8a0"), 36)
			_auto_timer = AUTO_DELAY if autoplay else -1.0
		Run.Phase.WAVE:
			_banner("WAVE %d" % (run.wave_index + 1))
		Run.Phase.CARD:
			if not _skipping:
				card_picker.show_offer(run.waves_cleared, run.wave_count(), run.card_offer)
			_auto_timer = AUTO_DELAY * 1.5 if autoplay else -1.0
		Run.Phase.WON, Run.Phase.LOST:
			var lost: bool = phase == Run.Phase.LOST
			if lost:
				_breach()
			var other: MapDef = next_map()
			overlay.show_result(not lost, run.waves_cleared, run.wave_count(), run.bricks(),
					BREACH_TIME if lost and not _skipping else 0.0,
					other.display_name if other != null else "")
			print("run end: %s at wave %d, bricks %d, ticks %d" % [Run.Phase.keys()[phase],
					run.waves_cleared, run.bricks(), run.ticks])
			if quit_on_end:
				get_tree().quit(0)


func _autoplay_decide() -> void:
	match run.phase:
		Run.Phase.BUILD:
			bot.play_build(run)
			start_wave()
		Run.Phase.CARD:
			card_picker.pick(mini(bot.card_choice, run.card_offer.size() - 1))


# --- player actions (from the UI) -------------------------------------------------------

## Open the build menu on plot `index` (a tap on it, or a test).
func open_plot(index: int) -> void:
	if not run.can_spend() or not run.plot_open(index):
		return
	plot_field.select(index)
	var screen: Vector2 = field.position + run.plots[index].position
	build_menu.open(index, screen, run)
	_slow_time()


func _on_build_requested(plot: int, unit_id: StringName) -> void:
	if run.build(plot, unit_id):
		fx.ring(run.plots[plot].position, UiTheme.TEAL, 40.0, 0.35)
		fx.popup("-%d" % run.unit_cost(unit_id), run.plots[plot].position - Vector2(0, 30),
				UiTheme.ACCENT, 18)
		build_menu.close()


func _on_upgrade_requested(plot: int) -> void:
	var cost: int = run.upgrade_cost(plot)
	if run.upgrade(plot):
		fx.ring(run.plots[plot].position, UiTheme.ACCENT, 44.0, 0.4)
		fx.popup("LEVEL %d" % run.plots[plot].level, run.plots[plot].position - Vector2(0, 34),
				UiTheme.ACCENT, 18)
		fx.popup("-%d" % cost, run.plots[plot].position - Vector2(0, 12), UiTheme.ACCENT, 14)
		build_menu.close()


func _on_sell_requested(plot: int) -> void:
	var refund: int = run.sell(plot)
	if refund >= 0:
		fx.poof(run.plots[plot].position)
		fx.popup("+%d" % refund, run.plots[plot].position - Vector2(0, 30), UiTheme.ACCENT, 18)
		build_menu.close()


func _on_repair_unit(plot: int) -> void:
	if run.repair_unit(plot):
		fx.ring(run.plots[plot].position, UiTheme.GOOD, 44.0, 0.4)
		build_menu.close()


func _on_mastery_requested(plot: int, index: int) -> void:
	if run.buy_mastery(plot, index):
		var p: CombatSim.Plot = run.plots[plot]
		fx.ring(p.position, UiTheme.ACCENT, 60.0, 0.5)
		fx.popup("★ %s" % p.mastery.title.to_upper(), p.position - Vector2(0, 36), UiTheme.ACCENT, 18)
		build_menu.close()


func _on_repair_gate() -> void:
	if run.repair_gate():
		fx.flash("fx/glow", Vector2(config.playfield_width() / 2.0, config.wall_y), 1.0, 4.0,
				Color(0.4, 1.0, 0.7, 0.5), 0.4)
		fx.popup("+%d GATE" % roundi(config.gate_repair_hp),
				Vector2(config.playfield_width() / 2.0, config.wall_y - 40), UiTheme.GOOD, 20)


## Open the barricade card on slot `slot` (a tap on it, or a test).
func open_barricade(slot: int) -> void:
	if not run.can_spend() or slot < 0 or slot >= config.map.barricade_slots.size():
		return
	build_menu.close()
	barricade_field.select(slot)
	barricade_menu.open(slot, field.position + config.map.barricade_slots[slot], run)
	_slow_time()


func _on_barricade_build(slot: int) -> void:
	var moving: bool = run.barricade().is_built()
	if run.build_barricade(slot):
		var p: Vector2 = config.map.barricade_slots[slot]
		fx.ring(p, UiTheme.ACCENT, 70.0, 0.4)
		fx.popup("MOVED" if moving else "BARRICADE", p - Vector2(0, 34), UiTheme.ACCENT, 18)
		barricade_menu.close()


func _on_barricade_upgrade() -> void:
	if run.upgrade_barricade():
		var b: CombatSim.Barricade = run.barricade()
		fx.ring(b.position, UiTheme.ACCENT, 70.0, 0.4)
		fx.popup("LEVEL %d" % b.level, b.position - Vector2(0, 34), UiTheme.ACCENT, 18)
		barricade_menu.close()


func _on_barricade_repair() -> void:
	if run.repair_barricade():
		fx.ring(run.barricade().position, UiTheme.GOOD, 70.0, 0.4)
		barricade_menu.close()


func _on_barricade_struck(e: CombatSim.Enemy, damage: float) -> void:
	if not _skipping:
		fx.gate_strike(Vector2(e.x, run.barricade().position.y - 14.0), damage * 0.5)


func _on_barricade_broken() -> void:
	if not _skipping:
		var p: Vector2 = run.barricade().position
		fx.explosion(p, 50.0)
		fx.popup("BARRICADE DOWN", p - Vector2(0, 36), UiTheme.BAD, 20)


func _on_unit_struck(plot: CombatSim.Plot, _e: CombatSim.Enemy, damage: float) -> void:
	if not _skipping:
		fx.gate_strike(plot.position, damage * 0.5)


## A unit falls: a blast, rubble on the pad, and the loss called out.
func _on_unit_destroyed(plot: CombatSim.Plot, def: UnitDef) -> void:
	if _skipping:
		return
	fx.explosion(plot.position, 40.0)
	field_view.add_decal("fx/scorch", plot.position, Color(1, 1, 1, 0.8), 1.2, float(plot.index))
	fx.popup("%s LOST" % def.display_name.to_upper(), plot.position - Vector2(0, 36), UiTheme.BAD, 18)
	if build_menu.plot == plot.index:
		build_menu.close()


func _on_mender_pulse(e: CombatSim.Enemy) -> void:
	if not _skipping:
		fx.ring(enemy_field.position_of(e), Color(0.45, 1.0, 0.6, 0.8), e.def.heal_radius, 0.6)


## The counter chart made visible: weak hits spark gold, resisted ones ping grey (throttled).
func _on_enemy_hit(e: CombatSim.Enemy, _amount: float, effect: int) -> void:
	if _skipping:
		return
	if effect > 0 and _hit_fx_budget.x >= 1.0:
		_hit_fx_budget.x -= 1.0
		fx.weak_hit(enemy_field.position_of(e))
	elif effect < 0 and _hit_fx_budget.y >= 1.0:
		_hit_fx_budget.y -= 1.0
		fx.resisted_hit(enemy_field.position_of(e))


func _on_card_picked(index: int) -> void:
	var title: String = run.card_offer[index].title if index < run.card_offer.size() else ""
	if run.pick_card(index):
		_banner(title.to_upper(), UiTheme.ACCENT, 32)


func _on_menu_closed() -> void:
	plot_field.select(-1)
	barricade_field.select(-1)
	if not build_menu.is_open() and not barricade_menu.is_open():
		Engine.time_scale = 1.0


func _close_menus() -> void:
	if build_menu != null:
		build_menu.close()
		barricade_menu.close()
		intel_card.close()
	Engine.time_scale = 1.0


## Mid-wave, menus slow the game rather than pause it: the pressure stays.
func _slow_time() -> void:
	if run.phase == Run.Phase.WAVE:
		Engine.time_scale = config.build_menu_time_scale


# --- input ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	handle_pointer(event)


## Pointer input (touch or mouse), presses only: a press on a crate taps it; otherwise a press
## on a build plot opens its menu, and one on a barricade slot opens the barricade card. Crates
## win because they are fleeting and plots are not.
## Public so tests can feed events directly.
func handle_pointer(event: InputEvent) -> void:
	if autoplay or run.is_over():
		return
	# With emulate_mouse_from_touch, a touch also arrives as an emulated mouse event.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	else:
		return
	var fp: Vector2 = pos - field_origin()
	if run.tap(fp):
		return
	var plot: int = plot_field.plot_at(fp)
	if plot >= 0 and run.can_spend():
		open_plot(plot)
		return
	var slot: int = barricade_field.slot_at(fp)
	if slot >= 0 and run.can_spend():
		open_barricade(slot)


# --- diagnostics ------------------------------------------------------------------------

func _sample_perf(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _perf_warmup > 0:
		_perf_warmup -= 1
		_perf_last_usec = now
		return
	if _perf_last_usec > 0:
		_perf_max_frame = maxf(_perf_max_frame, (now - _perf_last_usec) / 1000.0)
	_perf_last_usec = now
	_perf_frames += 1
	_perf_time += delta
	_perf_tick += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	_perf_peak_enemies = maxi(_perf_peak_enemies, run.combat.enemy_count())
	_perf_peak_shots = maxi(_perf_peak_shots, run.combat.shots.size())
	if _perf_time >= PERF_WINDOW:
		print("PERF wave %d | fps %.1f | frame avg %.2f ms max %.2f ms | sim tick avg %.2f ms | peak enemies %d shots %d | particles %d | draw calls %d" % [
			run.wave_index + 1, _perf_frames / _perf_time, _perf_time * 1000.0 / _perf_frames,
			_perf_max_frame, _perf_tick * 1000.0 / _perf_frames, _perf_peak_enemies,
			_perf_peak_shots, fx.particle_count(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		_perf_frames = 0
		_perf_time = 0.0
		_perf_max_frame = 0.0
		_perf_tick = 0.0
		_perf_peak_enemies = 0
		_perf_peak_shots = 0


## DEV ONLY: the performance budget's load (prototype plan §3): ~260 enemies alive at once,
## with every plot occupied and firing. A deep copy; the real config is untouched.
static func _stress_config(base: RunConfig) -> RunConfig:
	var cfg: RunConfig = base.duplicate(true)
	var tank: EnemyDef = null
	for w: WaveDef in cfg.waves:
		for s: SpawnEntry in w.spawns:
			if s.enemy.id == &"grunt":
				tank = s.enemy.duplicate()
	tank.hp = 1e9
	tank.speed = 6.0
	var entry := SpawnEntry.new()
	entry.enemy = tank
	entry.count = 260
	entry.interval = 0.03
	var wave := WaveDef.new()
	wave.spawns = [entry]
	cfg.waves = [wave]
	cfg.start_gold = 100000
	return cfg


func _fill_plots_for_stress() -> void:
	for i: int in run.plots.size():
		run.build(i, config.units[i % config.units.size()].id)
	run.start_wave()


static func _parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a: String in args:
		if not a.begins_with("--"):
			continue
		var kv: PackedStringArray = a.substr(2).split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return out
