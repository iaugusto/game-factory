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
##   --map=ID            which map to play (default: the campaign's sector, else the first map)
##   --tree=IDS          skill-tree nodes to play with: "all", or ids joined by commas
##                       (default: the save's tree when launched from the campaign, else none)
##   --autoplay          the scripted player plays (taps crates, builds, picks cards, starts waves)
##   --skip-to-wave=K    fast-forward (autoplayed, not rendered) to the BUILD phase of wave K
##   --skip=S            then start that wave and fast-forward S seconds into it
##   --stress            DEV ONLY: a synthetic budget-load wave (~260 enemies, all plots firing);
##                       --stress=mix makes 40 of them the Stage 2 enemies
##   --open-plot=N       DEV ONLY: open plot N's build menu at start (for screenshots)
##   --perf              print frame-time stats every 5 s
##   --quit-on-end       print a summary and quit when the run ends
##   --style=ID          UI style direction (data/styles/ID.tres; read by UiTheme, any scene)
##   --tips              show tips in a direct run too (fresh: none seen, nothing saved); with
##                       --autoplay the bot reads each tip for TIP_DEMO_READ s (for clips)
##   --ability=ID        the special attack to take (skips the pick when the map starts)
##   --pick=ID           DEV ONLY: answer the pick with ID (it still opens; for captures)
##   --demo=ID           DEV ONLY: a staged scene of special attack ID for its tutorial clip
##                       (RunController.demo_config; prints where and when it lands)
##   --showcase=IDS      DEV ONLY: one wave of the enemies IDS (comma-separated, from
##                       data/enemies/) among Drones, with coins to build (showcase_config)
##   --gold=N            DEV ONLY: start with N coins (after --showcase; for captures)
##
## When a map starts by hand, the player picks the special attack to take (AbilityPicker; the
## campaign offers the unlocked ones, a direct run all of them). The first pick of each shows
## its tutorial (the ability_intro tip, with a clip).
##
## Launched from the campaign screen (Session.active), a run is on Session.map_id with the
## save's skill tree, and its result is recorded (stars) through Session. Launched directly
## (any run argument, tests), it records nothing.
##
## Tests drive it without real time: tick(n), sync_views(), handle_pointer(event),
## open_plot(i), start_wave(), and the UI nodes' own methods.

const CONFIG_PATH: String = "res://data/run_config.tres"
const AUTO_DELAY: float = 1.0
## The breach when the gate falls: slow motion for this long (real seconds), then the result
## fades in.
const BREACH_TIME: float = 1.2
## Real seconds between the end of one banner and the start of the next queued one.
const BANNER_GAP: float = 0.1
## While a tip is up, time runs at most this fast (a visual stop; the run doesn't tick at all).
const TIP_TIME_FLOOR: float = 0.001
## With --autoplay --tips, seconds the bot "reads" a card before turning it.
const TIP_DEMO_READ: float = 1.8
const BREACH_TIME_SCALE: float = 0.3
const PERF_WINDOW: float = 5.0

## Everything in res://data/run_config.tres; `config` is it for the map being played.
var base_config: RunConfig
var config: RunConfig
var run: Run
var bot := Autoplay.new()
## Starting modifiers from the skill tree (null: none).
var tree_mods: RunModifiers = null
## Record results through Session (a campaign run, played by hand).
var records: bool = false
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
## Contextual tips: which to show (core) and the layer that shows them.
var tips := TipDirector.new()
var tip_layer: TipLayer
var build_menu: BuildMenu
var card_picker: CardPicker
var overlay: PhaseOverlay
var ability_button: AbilityButton
var ability_picker: AbilityPicker
## Links between units (under the plots), and special attacks plus the aim preview (over
## enemies).
var link_view: AbilityView
var ability_view: AbilityView
## An aimed special attack is armed: the next field tap calls it there.
var aiming: bool = false
## Offer the pick of special attack when a run starts (hand-played runs; tests switch it off).
var offer_pick: bool = true
## The special attack forced by --ability (null: the save's last pick, else the first).
var forced_ability: AbilityDef = null
## --pick: the id the pick is answered with as soon as it opens (&"": the player picks).
var auto_pick: StringName = &""
var _aim_pos: Vector2 = Vector2(270, 420)
## Links shown so far ("i:j:synergy"), to announce the new ones.
var _link_keys: Dictionary = {}

## True while fast-forwarding: views still track state, but no effects fire.
var _skipping: bool = false
var _auto_timer: float = -1.0
## Real seconds of breach slow motion left (the gate fell).
var _breach_timer: float = 0.0
## Banners waiting for the lane ([text, color, role, life]) and real seconds until the next.
var _banners: Array[Array] = []
var _banner_wait: float = 0.0
## The crate a crate tip points at (the one that triggered it).
var _tip_crate: CombatSim.Crate = null
## Whether tips read are written to the save (campaign runs).
var _tips_persist: bool = false
var _tips_froze: bool = false
## --autoplay --tips: the bot shows and dismisses tips (clips of the tutorial).
var _tip_demo: bool = false
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
## --demo: a staged scene of one special attack (for its tutorial clip).
var _demo: bool = false
## --demo: the stream is fast-forwarded until it is this far (field units) short of where the
## attack is called (about a second of walking), and the game quits this long after the call.
const DEMO_EARLY: float = 45.0
const DEMO_AFTER: float = 6.0
var _demo_cast_tick: int = -1


func _ready() -> void:
	base_config = load(CONFIG_PATH)
	Engine.physics_ticks_per_second = base_config.tick_rate
	var args: Dictionary = parse_args(OS.get_cmdline_user_args())
	var campaign_run: bool = Session.active and not Session.wants_direct_run(args)
	var chosen: MapDef = base_config.map_by_id(StringName(args.get("map",
			String(Session.map_id) if campaign_run else "")))
	config = base_config.for_map(chosen if chosen != null else base_config.map)
	autoplay = args.has("autoplay")
	if args.has("tree"):
		tree_mods = tree_from_arg(base_config.skill_tree, String(args["tree"]))
	elif campaign_run:
		tree_mods = Session.run_mods(base_config)
	records = campaign_run and not autoplay
	quit_on_end = args.has("quit-on-end")
	_perf = args.has("perf")
	_stress = args.has("stress")
	if _stress:
		config = _stress_config(config, args["stress"] == "mix")
	if args.has("ability"):
		forced_ability = base_config.ability_by_id(StringName(args["ability"]))
		if forced_ability == null:
			push_warning("--ability: unknown special attack '%s'" % args["ability"])
	auto_pick = StringName(args.get("pick", ""))
	if args.has("demo"):
		forced_ability = base_config.ability_by_id(StringName(args["demo"]))
		config = demo_config(config)
		_demo = true
	if args.has("showcase"):
		config = showcase_config(config, String(args["showcase"]).split(","))
	if args.has("gold"):
		config = config.duplicate(false)
		config.start_gold = int(args["gold"])
	offer_pick = not autoplay and forced_ability == null and not _stress \
			and not args.has("skip-to-wave") and not args.has("skip") and not args.has("open-plot")
	_build_nodes()
	var save_tips: bool = campaign_run and not autoplay and not Session.profile().tips_off
	if save_tips:
		enable_tips(Session.profile().tips_seen, true)
	elif args.has("tips"):
		enable_tips({})
		_tip_demo = autoplay
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
	if _demo:
		_demo_begin()
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
	link_view = AbilityView.new()
	link_view.links_only = true
	field.add_child(link_view)
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
	ability_view = AbilityView.new()
	field.add_child(ability_view)
	fx = Fx.new()
	fx.bounds_width = config.playfield_width()
	fx.coin_arrived.connect(func() -> void: hud.pulse_coins())
	field.add_child(fx)
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	ability_button = AbilityButton.new()
	ability_button.pressed.connect(toggle_ability)
	ui.add_child(ability_button)
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
	card_picker = CardPicker.new()
	card_picker.picked.connect(_on_card_picked)
	card_picker.reroll_pressed.connect(_on_reroll)
	ui.add_child(card_picker)
	ability_picker = AbilityPicker.new()
	ability_picker.chosen.connect(_on_ability_chosen)
	ui.add_child(ability_picker)
	tips.enabled = false
	tips.tips = base_config.tips
	tip_layer = TipLayer.new()
	tip_layer.finished.connect(_on_tip_finished)
	tip_layer.resolver = focus_rect
	tip_layer.focus_pressed.connect(handle_pointer)
	ui.add_child(tip_layer)
	overlay = PhaseOverlay.new()
	overlay.restart_pressed.connect(func() -> void: start_run(randi()))
	overlay.next_map_pressed.connect(func() -> void:
		switch_map(next_map())
		start_run(randi()))
	overlay.campaign_pressed.connect(func() -> void: Session.goto_campaign())
	ui.add_child(overlay)


## Centre the playfield horizontally in whatever width the window has.
func _layout() -> void:
	field.position = field_origin()
	var view: Vector2 = get_viewport_rect().size
	ability_button.position = Vector2(view.x - AbilityButton.SIZE - 12.0, Hud.HEIGHT + 12.0)


func field_origin() -> Vector2:
	var view: Vector2 = get_viewport_rect().size
	return Vector2((view.x - config.playfield_width()) / 2.0, Hud.HEIGHT)


## The next sector after the current map in RunConfig.maps, or null after the last.
func next_map() -> MapDef:
	var maps: Array[MapDef] = base_config.maps
	var i: int = maps.find(config.map)
	return maps[i + 1] if i >= 0 and i + 1 < maps.size() else null


## Play `m` from the next run on (views that depend on the map are rebuilt by start_run).
func switch_map(m: MapDef) -> void:
	if m == null:
		return
	config = base_config.for_map(m)
	if records:
		Session.map_id = m.id
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
	tips.clear_queue()
	aiming = false
	_link_keys.clear()
	run = Run.new(config, run_seed, tree_mods)
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
	sim.unit_blast.connect(_on_unit_blast)
	sim.ability_called.connect(_on_ability_called)
	sim.ability_landed.connect(_on_ability_landed)
	sim.mine_exploded.connect(_on_mine_exploded)
	sim.lob_landed.connect(_on_lob_landed)
	sim.enemy_burrowed.connect(_on_burrow)
	sim.enemy_surfaced.connect(_on_burrow)
	sim.synergies_changed.connect(_on_synergies_changed)
	run.phase_changed.connect(_on_phase_changed)
	run.choose_ability(default_ability())
	plot_field.setup(run)
	barricade_field.setup(run)
	print("run seed %d on %s" % [run_seed, config.map.id])
	ability_picker.close()
	if not autoplay:
		_banner(config.map.display_name.to_upper(), UiTheme.look.title, &"heading", 1.6)
	_on_phase_changed(run.phase)
	if offer_pick:
		_offer_abilities()
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
			if _demo:
				_demo_tick()
			run.step()


func _physics_process(_delta: float) -> void:
	if tip_layer.is_active():
		return  # a tip stops the run
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
	_banners.clear()  # announcements from before the skip are stale
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
	_update_tips()
	if _banner_wait > 0.0:
		_banner_wait -= delta  # game time, like the popups it waits for (frozen under a tip)
		if _banner_wait <= 0.0:
			_next_banner()
	if _breach_timer > 0.0:
		_breach_timer -= real
		if _breach_timer <= 0.0:
			Engine.time_scale = 1.0
	var tip_waiting: bool = _tip_demo and (tip_layer.is_active() or tips.pending() != null)
	if _auto_timer >= 0.0 and not tip_waiting:
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
	ability_button.visible = run.phase == Run.Phase.WAVE and run.ability != null
	ability_button.sync(run, aiming, delta)
	link_view.sync(run, false, _aim_pos, delta)
	ability_view.sync(run, aiming, _aim_pos, delta)


## Queue a big centred announcement. Banners share one lane: each waits until the one before
## has faded out (its life plus BANNER_GAP), so two never draw on top of each other.
func _banner(text: String, color: Color = Color(0, 0, 0, 0), role: StringName = &"display",
		life: float = 1.6) -> void:
	if _skipping or _demo:
		return
	_banners.append([text, color if color.a > 0.0 else UiTheme.look.title, role, life])
	if _banner_wait <= 0.0:
		_next_banner()


func _next_banner() -> void:
	if _banners.is_empty():
		return
	var b: Array = _banners.pop_front()
	fx.popup(b[0], Vector2(config.playfield_width() / 2.0, 330), b[1], b[2], b[3], 30.0)
	_banner_wait = b[3] + BANNER_GAP


# --- core signals -> views and effects --------------------------------------------------

func _on_enemy_killed(e: CombatSim.Enemy, gold: int) -> void:
	if not _skipping:
		var pos: Vector2 = e.pos()
		fx.death(pos, e.def.color, e.def.radius)
		field_view.add_decal("fx/splat", pos, Color(e.def.color.darkened(0.45), 0.55),
				e.def.radius / 22.0, float(e.id % 7))
		if gold >= 3:
			fx.popup("+%d" % gold, pos, UiTheme.look.coin, &"body")
	enemy_field.forget(e.id)


## An enemy at the gate struck it: sparks where it hit, and the damage. A Bombardier's glob
## has its own splash (_on_lob_landed).
func _on_enemy_struck(e: CombatSim.Enemy, damage: float) -> void:
	if _skipping or e.lobbing:
		return
	var p := Vector2(e.x, config.wall_y - FieldView.WALL_TOP_OFFSET)
	fx.gate_strike(p, damage)
	fx.popup("-%d" % roundi(damage), p - Vector2(0, 26), UiTheme.look.threat, &"label", 0.7, 30.0)
	tips.notify(&"gate_struck")


func _on_spit_fired(sp: CombatSim.Spit) -> void:
	if not _skipping:
		fx.flash("fx/glow", sp.start, 0.2, 0.6, Color(0.83, 1.0, 0.35, 0.8), 0.15)


## A glob landed: the unit is gooed and shut down for a while.
func _on_unit_disabled(plot: CombatSim.Plot, duration: float) -> void:
	if _skipping:
		return
	fx.acid_splash(plot.position)
	fx.popup("JAMMED %ds" % roundi(duration), plot.position - Vector2(0, 34),
			Color(0.83, 1.0, 0.35), &"caption", 0.9, 30.0)
	tips.notify(&"unit_jammed", StringName(str(plot.index)))


## The gate breaks: a heavy shake, blasts along the wall, the banner, and a moment of slow
## motion before the result fades in.
func _breach() -> void:
	if _skipping:
		return
	fx.shake(24.0)
	for i: int in 5:
		var x: float = config.playfield_width() * (0.1 + 0.2 * i)
		fx.wall_hit(Vector2(x, config.wall_y - FieldView.WALL_TOP_OFFSET), 20.0)
	_banner("THE GATE HAS FALLEN", UiTheme.look.threat, &"display")
	Engine.time_scale = BREACH_TIME_SCALE
	_breach_timer = BREACH_TIME


func _on_crate_spawned(c: CombatSim.Crate) -> void:
	crate_field.bind(c)
	if _skipping or not tips.enabled:
		return
	_tip_crate = c
	tips.notify(&"boost_crate" if c.def.is_boost() else &"crate_spawned")


func _on_crate_broken(c: CombatSim.Crate, coins: int) -> void:
	if not _skipping:
		fx.crate_break(c.pos(), c.def.color, coins)
		fx.popup("+%d" % coins, c.pos() - Vector2(0, 20), UiTheme.look.coin, &"label", 0.9, 60.0)
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
	_banner("OVERDRIVE!", UiTheme.look.owned, &"display")
	for plot: CombatSim.Plot in run.plots:
		if not plot.is_empty():
			fx.ring(plot.position, UiTheme.look.owned, 60.0, 0.5)


func _on_phase_changed(phase: Run.Phase) -> void:
	_close_menus()
	aiming = false
	build_bar.visible = phase == Run.Phase.BUILD and not autoplay
	match phase:
		Run.Phase.BUILD:
			build_bar.show_for(run.wave_index + 1, run.wave_count(), run)
			build_bar.visible = not autoplay
			if not _skipping:
				_notify_build_tips()
			if not run.newly_open_paths().is_empty() and not _skipping:
				_banner("NEW BREACH!", UiTheme.look.threat, &"display", 2.0)
				fx.shake(8.0)
			_banner("WAVE %d INCOMING" % (run.wave_index + 1), UiTheme.look.title, &"heading")
			_auto_timer = AUTO_DELAY if autoplay else -1.0
		Run.Phase.WAVE:
			_banner("WAVE %d" % (run.wave_index + 1))
		Run.Phase.CARD:
			if not _skipping:
				card_picker.show_offer(run.waves_cleared, run.wave_count(), run.card_offer,
						run.rerolls_left)
				tips.notify(&"card_offer")
			_auto_timer = AUTO_DELAY * 1.5 if autoplay else -1.0
		Run.Phase.WON, Run.Phase.LOST:
			var lost: bool = phase == Run.Phase.LOST
			if lost:
				_breach()
			var result: Dictionary = {}
			if records:
				result = Session.record(config, run)
			else:
				result = {"stars": Campaign.stars_for(not lost, run.gate_fraction(),
						config.star_thresholds)}
			var other: MapDef = next_map()
			overlay.show_result(not lost, run.waves_cleared, run.wave_count(),
					run.gate_fraction(), result, BREACH_TIME if lost and not _skipping else 0.0,
					other.display_name if other != null and not lost else "")
			print("run end: %s at wave %d, gate %d%%, stars %d, ticks %d" % [
					Run.Phase.keys()[phase], run.waves_cleared, roundi(run.gate_fraction() * 100),
					int(result.get("stars", 0)), run.ticks])
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
	tip_layer.complete(&"plot_opened")


func _on_build_requested(plot: int, unit_id: StringName) -> void:
	if run.build(plot, unit_id):
		fx.ring(run.plots[plot].position, UiTheme.look.owned, 40.0, 0.35)
		fx.popup("-%d" % run.unit_cost(unit_id), run.plots[plot].position - Vector2(0, 30),
				UiTheme.look.coin, &"body")
		build_menu.close()
		if run.phase == Run.Phase.BUILD:
			tips.notify(&"unit_built")


func _on_upgrade_requested(plot: int) -> void:
	var cost: int = run.upgrade_cost(plot)
	if run.upgrade(plot):
		fx.ring(run.plots[plot].position, UiTheme.look.action, 44.0, 0.4)
		fx.popup("LEVEL %d" % run.plots[plot].level, run.plots[plot].position - Vector2(0, 34),
				UiTheme.look.action, &"body")
		fx.popup("-%d" % cost, run.plots[plot].position - Vector2(0, 12), UiTheme.look.coin, &"caption")
		if run.mastery_cost(plot) >= 0:
			tips.notify(&"mastery_ready", StringName(str(plot)))
		build_menu.close()


func _on_sell_requested(plot: int) -> void:
	var refund: int = run.sell(plot)
	if refund >= 0:
		fx.poof(run.plots[plot].position)
		fx.popup("+%d" % refund, run.plots[plot].position - Vector2(0, 30), UiTheme.look.coin, &"body")
		build_menu.close()


func _on_repair_unit(plot: int) -> void:
	if run.repair_unit(plot):
		fx.ring(run.plots[plot].position, UiTheme.look.good, 44.0, 0.4)
		build_menu.close()


func _on_mastery_requested(plot: int, index: int) -> void:
	if run.buy_mastery(plot, index):
		var p: CombatSim.Plot = run.plots[plot]
		fx.ring(p.position, UiTheme.look.action, 60.0, 0.5)
		fx.popup("★ %s" % p.mastery.title.to_upper(), p.position - Vector2(0, 36), UiTheme.look.action, &"body")
		build_menu.close()


func _on_repair_gate() -> void:
	if run.repair_gate():
		fx.flash("fx/glow", Vector2(config.playfield_width() / 2.0, config.wall_y), 1.0, 4.0,
				Color(0.4, 1.0, 0.7, 0.5), 0.4)
		fx.popup("+%d GATE" % roundi(config.gate_repair_hp),
				Vector2(config.playfield_width() / 2.0, config.wall_y - 40), UiTheme.look.good, &"label")


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
		fx.ring(p, UiTheme.look.action, 70.0, 0.4)
		fx.popup("MOVED" if moving else "BARRICADE", p - Vector2(0, 34), UiTheme.look.action, &"body")
		barricade_menu.close()


func _on_barricade_upgrade() -> void:
	if run.upgrade_barricade():
		var b: CombatSim.Barricade = run.barricade()
		fx.ring(b.position, UiTheme.look.action, 70.0, 0.4)
		fx.popup("LEVEL %d" % b.level, b.position - Vector2(0, 34), UiTheme.look.action, &"body")
		barricade_menu.close()


func _on_barricade_repair() -> void:
	if run.repair_barricade():
		fx.ring(run.barricade().position, UiTheme.look.good, 70.0, 0.4)
		barricade_menu.close()


func _on_barricade_struck(e: CombatSim.Enemy, damage: float) -> void:
	if not _skipping:
		fx.gate_strike(Vector2(e.x, run.barricade().position.y - 14.0), damage * 0.5)


func _on_barricade_broken() -> void:
	if not _skipping:
		var p: Vector2 = run.barricade().position
		fx.explosion(p, 50.0)
		fx.popup("BARRICADE DOWN", p - Vector2(0, 36), UiTheme.look.threat, &"label")


func _on_unit_struck(plot: CombatSim.Plot, _e: CombatSim.Enemy, damage: float) -> void:
	if not _skipping:
		fx.gate_strike(plot.position, damage * 0.5)


## A unit falls: a blast, rubble on the pad, and the loss called out.
## Last Stand: the fallen unit's pad erupts (a big explosion and a blast ring of its radius).
func _on_unit_blast(pos: Vector2, radius: float) -> void:
	if _skipping:
		return
	fx.explosion(pos, radius)
	fx.ring(pos, UiTheme.look.action, radius, 0.5)
	fx.shake(7.0)
	fx.popup("LAST STAND", pos - Vector2(0, 66), UiTheme.look.action, &"label")


func _on_unit_destroyed(plot: CombatSim.Plot, def: UnitDef) -> void:
	if _skipping:
		return
	fx.explosion(plot.position, 40.0)
	field_view.add_decal("fx/scorch", plot.position, Color(1, 1, 1, 0.8), 1.2, float(plot.index))
	fx.popup("%s LOST" % def.display_name.to_upper(), plot.position - Vector2(0, 36), UiTheme.look.threat, &"body")
	tips.notify(&"unit_destroyed", StringName(str(plot.index)))
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
		_banner(title.to_upper(), UiTheme.look.action, &"heading")


func _on_reroll() -> void:
	if run.reroll_cards():
		card_picker.show_offer(run.waves_cleared, run.wave_count(), run.card_offer,
				run.rerolls_left)


func _on_menu_closed() -> void:
	plot_field.select(-1)
	barricade_field.select(-1)
	if not build_menu.is_open() and not barricade_menu.is_open():
		Engine.time_scale = 1.0


func _close_menus() -> void:
	if build_menu != null:
		build_menu.close()
		barricade_menu.close()
	Engine.time_scale = 1.0


## Mid-wave, menus slow the game rather than pause it: the pressure stays.
func _slow_time() -> void:
	if run.phase == Run.Phase.WAVE:
		Engine.time_scale = config.build_menu_time_scale


# --- the special attack and unit links --------------------------------------------------

## The attack a run starts with: --ability, else the save's last pick if it is still unlocked
## (campaign runs), else the first of the pool.
func default_ability() -> AbilityDef:
	if forced_ability != null:
		return forced_ability
	var pool: Array[AbilityDef] = ability_pool()
	if records or Session.active:
		var last: AbilityDef = base_config.ability_by_id(Session.profile().last_ability)
		if last != null and pool.has(last):
			return last
	return pool[0] if not pool.is_empty() else null


## The attacks the player may pick from: the unlocked ones in a campaign run, all in a direct
## run (a dev launch).
func ability_pool() -> Array[AbilityDef]:
	if records:
		return Session.profile().campaign.abilities_unlocked(base_config)
	return base_config.abilities.duplicate()


## Open the pick of special attack (a run starting by hand). With one or none to pick from,
## there is nothing to ask.
func _offer_abilities() -> void:
	var pool: Array[AbilityDef] = ability_pool()
	if pool.size() <= 1:
		return
	var fresh: Dictionary = {}
	if tips.enabled:
		for a: AbilityDef in pool:
			if not tips.has_seen("ability_intro:%s" % a.id):
				fresh[a.id] = true
	var names: Dictionary = {}
	for m: MapDef in base_config.maps:
		names[m.id] = m.display_name
	ability_picker.open(base_config.abilities, pool, run.ability.id if run.ability else &"",
			fresh, names)
	build_bar.visible = false  # the pick comes first
	if auto_pick != &"":
		ability_picker.pick.call_deferred(auto_pick)


## The player took `a` into this run: remember it as the next default, and teach it the first
## time (the ability_intro tip, shown once the picker has closed).
func _on_ability_chosen(a: AbilityDef) -> void:
	build_bar.visible = run.phase == Run.Phase.BUILD and not autoplay
	if not run.choose_ability(a):
		return
	if records:
		Session.profile().last_ability = a.id
		Session.persist()
	_banner(a.display_name.to_upper(), AbilityView.color_of(a), &"heading", 1.2)
	tips.notify(&"ability_picked", a.id)


## The ability button: an aimed attack arms (time slows while the player picks a spot) or
## disarms; one that needs no aim goes off at once.
func toggle_ability() -> void:
	if not aiming and not run.ability_ready():
		return
	if not run.ability.targeted():
		run.call_ability(Vector2(config.playfield_width() / 2.0, config.wall_y))
		return
	aiming = not aiming
	if aiming:
		_close_menus()
		aiming = true
		Engine.time_scale = config.build_menu_time_scale
	else:
		Engine.time_scale = 1.0


## Call the armed attack at field point `fp`.
func fire_ability(fp: Vector2) -> void:
	aiming = false
	Engine.time_scale = 1.0
	run.call_ability(fp)


func _on_ability_called(c: CombatSim.Cast) -> void:
	if _skipping:
		return
	if c.ability.targeted():
		fx.ring(c.pos, AbilityView.color_of(c.ability), c.ability.radius * 0.5, 0.3)


## An attack landed: its effect, per kind.
func _on_ability_landed(c: CombatSim.Cast) -> void:
	if _skipping:
		return
	var a: AbilityDef = c.ability
	var pos: Vector2 = c.pos
	match a.kind:
		AbilityDef.Kind.STRIKE:
			fx.explosion(pos, a.radius)
			fx.explosion(pos, a.radius * 0.6)
			fx.ring(pos, UiTheme.look.action, a.radius * 1.2, 0.5)
			fx.shake(10.0)
			field_view.add_decal("fx/scorch", pos, Color(1, 1, 1, 0.9), a.radius / 29.0, pos.x)
		AbilityDef.Kind.FREEZE:
			var ice: Color = AbilityView.FREEZE_COLOR
			fx.flash("fx/glow", pos, 0.6, a.radius / 14.0, Color(ice, 0.8), 0.55)
			fx.ring(pos, ice, a.radius, 0.6)
			fx.ring(pos, Color.WHITE, a.radius * 0.6, 0.4)
			fx.shake(5.0)
			field_view.add_decal("fx/glow", pos, Color(ice, 0.22), a.radius / 30.0, 0.0)
		AbilityDef.Kind.BURN:
			var road: Array[CombatSim.Stretch] = run.combat.burn_layout(a, pos)
			var size: float = run.combat.burn_half_width(road) * 2.0
			for st: CombatSim.Stretch in road:
				var geo: PathGeo = run.combat.geos[st.path]
				var n: int = maxi(3, roundi((st.d_hi - st.d_lo) / 36.0))
				for i: int in n:
					var p: Vector2 = geo.point_at(lerpf(st.d_lo, st.d_hi, (i + 0.5) / n))
					fx.explosion(p, size * 0.6)
					field_view.add_decal("fx/scorch", p, Color(1, 1, 1, 0.8), size / 40.0, p.x)
			fx.shake(6.0)
		AbilityDef.Kind.MINES:
			for m: CombatSim.Mine in run.combat.mines:
				fx.ring(m.pos, AbilityView.MINE_COLOR, 16.0, 0.3)
		AbilityDef.Kind.REPAIR:
			var good: Color = UiTheme.look.good
			var gate := Vector2(config.playfield_width() / 2.0, config.wall_y)
			fx.flash("fx/glow", gate, 1.0, 4.0, Color(good, 0.5), 0.5)
			fx.popup("+%d GATE" % roundi(a.gate_heal), gate - Vector2(0, 44), good, &"label")
			for p: CombatSim.Plot in run.plots:
				if not p.is_empty():
					fx.ring(p.position, good, 44.0, 0.5)
			if run.barricade().is_built():
				fx.ring(run.barricade().position, good, 70.0, 0.5)


## A Bombardier's glob hit the gate: an acid splash on the wall, and the damage.
func _on_lob_landed(lob: CombatSim.Lob) -> void:
	if _skipping:
		return
	var p := Vector2(lob.dest.x, config.wall_y - FieldView.WALL_TOP_OFFSET)
	fx.acid_splash(p)
	fx.gate_strike(p, lob.damage)
	fx.popup("-%d" % roundi(lob.damage), p - Vector2(0, 26), UiTheme.look.threat, &"label", 0.7,
			30.0)
	tips.notify(&"gate_struck")


## A Burrower dived or surfaced: earth flies.
func _on_burrow(e: CombatSim.Enemy) -> void:
	if not _skipping:
		fx.dust(e.pos())


func _on_mine_exploded(m: CombatSim.Mine) -> void:
	if _skipping:
		return
	fx.explosion(m.pos, m.radius)
	fx.shake(3.0)
	field_view.add_decal("fx/scorch", m.pos, Color(1, 1, 1, 0.8), m.radius / 30.0, m.pos.x)


## Links were recomputed: name each new one where it formed, and teach the first.
func _on_synergies_changed() -> void:
	var now: Dictionary = {}
	for p: CombatSim.Plot in run.plots:
		for link: Array in p.links:
			var j: int = link[0]
			if j <= p.index:
				continue
			var s: SynergyDef = link[1]
			var key: String = "%d:%d:%s" % [p.index, j, s.id]
			now[key] = true
			if not _link_keys.has(key) and not _skipping:
				var mid: Vector2 = (p.position + run.plots[j].position) / 2.0
				fx.popup(s.title.to_upper(), mid - Vector2(0, 10), UiTheme.look.owned, &"body",
						1.4, 30.0)
				tips.notify(&"synergy_formed", StringName(str(p.index)))
	_link_keys = now


# --- tips -------------------------------------------------------------------------------

## Turn tips on for this scene with `seen` (tip keys already read). `persist`: write the save
## each time one is read (campaign runs). Tests call this to exercise tips.
func enable_tips(seen: Dictionary, persist: bool = false) -> void:
	tips.seen = seen
	tips.enabled = true
	_tips_persist = persist


## The build phase's tips: what is new this wave, and what the player can now do.
func _notify_build_tips() -> void:
	if not tips.enabled:
		return
	for e: EnemyDef in WaveSchedule.new_enemies(config.waves, run.wave_index):
		tips.notify(&"new_enemy", e.id)
	for path: int in run.newly_open_paths():
		tips.notify(&"new_portal", StringName(str(path)))
	if run.wave_index == 0:
		tips.notify(&"run_started")
	for p: CombatSim.Plot in run.plots:
		if p.unlock_wave > run.wave_index + 1:
			tips.notify(&"locked_pad", StringName(str(p.index)))
			break
	for p: CombatSim.Plot in run.plots:
		if p.terrain_reach > 0.0 and run.plot_open(p.index):
			tips.notify(&"high_ground", StringName(str(p.index)))
			break
	# The first build phase already teaches enemies and building; the barricade can wait.
	if run.wave_index >= 1 and run.barricade_cost() >= 0 and not run.barricade().is_built():
		tips.notify(&"barricade_ready")
	if run.can_repair_gate() and run.wall_hp() < run.wall_max():
		tips.notify(&"gate_damaged")


## Each frame: tips that depend on coins, then show the next tip when the moment is clear, and
## stop time while one is up.
func _update_tips() -> void:
	if tips.enabled and run.ability_ready():
		tips.notify(&"ability_ready")
	if tips.enabled and run.phase == Run.Phase.BUILD and not tip_layer.is_active():
		for p: CombatSim.Plot in run.plots:
			var cost: int = run.upgrade_cost(p.index) if not p.is_empty() else -1
			if cost >= 0 and run.gold >= cost:
				tips.notify(&"can_upgrade", StringName(str(p.index)))
				break
	pump_tips()
	# Only a wave needs stopping; between waves nothing moves, and menus keep their animation.
	if tip_layer.freeze > 0.0 and run.phase == Run.Phase.WAVE:
		var base: float = config.build_menu_time_scale \
				if run.phase == Run.Phase.WAVE and (build_menu.is_open() or barricade_menu.is_open()) \
				else 1.0
		Engine.time_scale = maxf(TIP_TIME_FLOOR, base * (1.0 - tip_layer.freeze))
		_tips_froze = true
	elif _tips_froze:
		_tips_froze = false
		Engine.time_scale = config.build_menu_time_scale \
				if run.phase == Run.Phase.WAVE and (build_menu.is_open() or barricade_menu.is_open()) \
				else 1.0


## Show the next waiting tip if nothing is in its way (menus, the result, a skip). Public so
## tests can pump without real-time processing.
func pump_tips() -> void:
	if _tip_demo and tip_layer.is_active() and tip_layer.age() >= TIP_DEMO_READ:
		_demo_turn_tip()
	if not tips.enabled or tip_layer.is_active() or _skipping or run.is_over():
		return
	if autoplay and not _tip_demo:
		return
	if build_menu.is_open() or barricade_menu.is_open() or ability_picker.visible:
		return
	var p: TipDirector.Pending = tips.pending()
	if p == null:
		return
	tip_layer.show_tip(p, _tip_pages(p))


## The demo bot on a tip: a "do" card is done by tapping its spotlight, others are turned.
func _demo_turn_tip() -> void:
	var spot: Rect2 = tip_layer.focus_rect()
	if tip_layer.pages[tip_layer.page_index].wait_for != &"" and spot.size.x > 0.0:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = spot.get_center()
		autoplay = false  # handle_pointer ignores the bot's own taps otherwise
		handle_pointer(e)
		autoplay = true
		build_menu.close()
	else:
		tip_layer.advance()


func _on_tip_finished(p: TipDirector.Pending) -> void:
	tips.done(p)
	if _tips_persist:
		Session.persist()


## Build the cards of tip `p` as the layer shows them. A new-enemy tip is built from the enemy:
## its portrait, name, one line, and the units it is weak to and shrugs off.
func _tip_pages(p: TipDirector.Pending) -> Array[TipLayer.Page]:
	var out: Array[TipLayer.Page] = []
	if p.def.trigger == &"new_enemy":
		var e: EnemyDef = null
		for d: EnemyDef in WaveSchedule.new_enemies(config.waves, run.wave_index):
			if d.id == p.arg:
				e = d
		if e == null:
			for w: WaveDef in config.waves:
				for entry: SpawnEntry in w.spawns:
					if entry.enemy.id == p.arg:
						e = entry.enemy
		var pg := TipLayer.Page.new()
		pg.title = "New threat: %s" % e.display_name if e != null else "New threat"
		if e != null:
			pg.body = e.description
			pg.picture = EnemyIcon.make(e, 72)
			var rows := VBoxContainer.new()
			rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rows.add_child(TipLayer.unit_row("WEAK TO", Counters.units_strong_vs(config, e),
					UiTheme.look.good))
			var bad: Array[UnitDef] = Counters.units_weak_vs(config, e)
			if not bad.is_empty():
				rows.add_child(TipLayer.unit_row("SHRUGS OFF", bad, UiTheme.look.threat))
			pg.extra = rows
		out.append(pg)
		return out
	if p.def.trigger == &"ability_picked":
		var a: AbilityDef = base_config.ability_by_id(p.arg)
		if a != null:
			return ability_pages(a)
	for c: TipCard in p.def.cards:
		var pg := TipLayer.Page.new()
		pg.title = c.title
		pg.body = c.body
		if c.icon != "":
			pg.picture = UiTheme.icon(c.icon, 64)
		pg.clip = c.clip
		pg.focus = focus_rect(c.focus, p.arg)
		pg.focus_key = c.focus
		pg.focus_arg = p.arg
		pg.wait_for = c.wait_for if pg.focus.size.x > 0.0 else &""
		out.append(pg)
	return out


## The first-time tutorial of special attack `a`: what it does (with its clip) and its numbers,
## then how to call it and how it reloads.
static func ability_pages(a: AbilityDef) -> Array[TipLayer.Page]:
	var what := TipLayer.Page.new()
	what.title = a.display_name
	what.body = a.description
	what.picture = UiTheme.icon(a.icon, 64)
	what.clip = a.clip
	what.extra = UiTheme.label(AbilityPicker.summary(a), &"caption", UiTheme.look.coin)
	var how := TipLayer.Page.new()
	how.title = "How to use it"
	how.body = ("During a wave, tap %s at the top right, then tap the field where it should land."
			if a.targeted() else "During a wave, tap %s at the top right. It works at once.") \
			% a.short_name
	how.picture = UiTheme.icon(a.icon, 64)
	how.extra = UiTheme.label("Ready when each wave starts, then reloads in %d s." \
			% roundi(a.cooldown), &"caption", UiTheme.look.text_dim)
	how.extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return [what, how]


## Where `focus` is on screen (canvas coordinates), for tip argument `arg` (a plot or path
## index). A zero rectangle when there is nothing to point at.
func focus_rect(focus: StringName, arg: StringName = &"") -> Rect2:
	var o: Vector2 = field_origin()
	var idx: int = int(String(arg)) if String(arg).is_valid_int() else -1
	match focus:
		&"empty_pad":
			var best: int = -1
			var best_d: float = INF
			var aim := Vector2(config.playfield_width() / 2.0, config.wall_y * 0.62)
			for p: CombatSim.Plot in run.plots:
				if p.is_empty() and run.plot_open(p.index):
					var d: float = p.position.distance_squared_to(aim)
					if d < best_d:
						best_d = d
						best = p.index
			return _around(o + run.plots[best].position, 36.0) if best >= 0 else Rect2()
		&"built_unit", &"jammed_unit", &"lost_pad", &"locked_pad", &"high_ground":
			if idx < 0:
				for p: CombatSim.Plot in run.plots:
					if not p.is_empty():
						idx = p.index
						break
			return _around(o + run.plots[idx].position, 36.0) if idx >= 0 else Rect2()
		&"crate":
			return _around(o + _tip_crate.pos(), 38.0) if _tip_crate != null else Rect2()
		&"gate":
			return Rect2(o + Vector2(0, config.wall_y - FieldView.WALL_TOP_OFFSET - 10),
					Vector2(config.playfield_width(), 64))
		&"portal":
			var paths: Array[PathDef] = config.map.paths
			if idx >= 0 and idx < paths.size() and not paths[idx].points.is_empty():
				var pt: Vector2 = paths[idx].points[0]
				return _around(o + Vector2(clampf(pt.x, 24.0, config.playfield_width() - 24.0),
						maxf(pt.y, 4.0) + 6.0), 40.0)
		&"barricade_slot":
			if not config.map.barricade_slots.is_empty():
				return _around(o + config.map.barricade_slots[0], 44.0)
		&"gate_hp":
			return hud.wall_bar.get_global_rect().grow(8)
		&"coins":
			return hud.coin_icon.get_global_rect().grow(8)
		&"start_wave":
			return build_bar.start_button.get_global_rect().grow(6)
		&"repair_gate":
			return build_bar.repair_button.get_global_rect().grow(6)
		&"card_offer":
			return card_picker.cards_rect().grow(8)
		&"ability_button":
			return ability_button.area().grow(6) if ability_button.visible else Rect2()
	return Rect2()


static func _around(center: Vector2, half: float) -> Rect2:
	return Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)


# --- input ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		_aim_pos = event.position - field_origin()
		ability_view.aim_seen = true
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
	if aiming:
		fire_ability(fp)
		return
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


## DEV ONLY (--demo): one staged wave for a special attack's tutorial clip: a pack of Drones,
## then a few Brutes and Skitters, down the middle path, nothing built (the attack does the
## work), and plenty of coins. Repair Drones get a battered gate and units to patch instead.
## DEV ONLY (--showcase): one wave on the current map with 8 of each enemy in `ids` (loaded from
## data/enemies/, on random open paths, one type after another) among 24 Drones, and 400
## coins to build with. For meeting enemies before a sector puts them in its waves.
static func showcase_config(base: RunConfig, ids: PackedStringArray) -> RunConfig:
	var cfg: RunConfig = base.duplicate(false)
	var wave := WaveDef.new()
	var grunt: EnemyDef = load("res://data/enemies/grunt.tres")
	var drones := SpawnEntry.new()
	drones.enemy = grunt
	drones.count = 24
	drones.interval = 1.2
	drones.path = -1
	wave.spawns.append(drones)
	for i: int in ids.size():
		var path: String = "res://data/enemies/%s.tres" % ids[i].strip_edges()
		if not ResourceLoader.exists(path):
			push_warning("--showcase: no enemy '%s'" % ids[i])
			continue
		var entry := SpawnEntry.new()
		entry.enemy = load(path)
		entry.count = 8
		entry.start = 3.0 + i * 6.0
		entry.interval = 2.2
		entry.path = -1
		wave.spawns.append(entry)
	cfg.waves = [wave]
	cfg.start_gold = 400
	return cfg


static func demo_config(base: RunConfig) -> RunConfig:
	var cfg: RunConfig = base.duplicate(false)
	var kinds: Dictionary = {}
	for m: MapDef in base.maps:
		for w: WaveDef in m.waves:
			for sp: SpawnEntry in w.spawns:
				kinds[sp.enemy.id] = sp.enemy
	var wave := WaveDef.new()
	var middle: int = base.map.paths.size() / 2
	# The Drones lead as one pack; Brutes come after (small ones bunch up behind a big one,
	# which would slow the pack) and Skitters last (they'd sprint ahead of it).
	for spec: Array in [[&"grunt", 14, 0.0, 0.32], [&"brute", 2, 3.5, 1.6], [&"runner", 4, 5.0, 0.4]]:
		if not kinds.has(spec[0]):
			continue
		var entry := SpawnEntry.new()
		entry.enemy = kinds[spec[0]]
		entry.count = spec[1]
		entry.start = spec[2]
		entry.interval = spec[3]
		entry.path = middle
		wave.spawns.append(entry)
	cfg.waves = [wave]
	cfg.start_gold = 5000
	return cfg


func _demo_begin() -> void:
	tips.enabled = false
	if run.ability != null and run.ability.kind == AbilityDef.Kind.REPAIR:
		var near_gate: Array[int] = []
		for p: CombatSim.Plot in run.plots:
			if p.position.y > config.wall_y * 0.7 and near_gate.size() < 4:
				near_gate.append(p.index)
		for i: int in near_gate.size():
			run.build(near_gate[i], config.units[i % config.units.size()].id)
			run.plots[near_gate[i]].hp *= 0.3
		run.wall_damage_taken = run.wall_max() * 0.6
	start_wave()
	# Unrendered, and with nobody playing: walk the stream on until about a second before the
	# attack is due, so the clip's recording starts just before it.
	_skipping = true
	while run.phase == Run.Phase.WAVE and run.ticks < 60 * 30 and _demo_target(DEMO_EARLY) == null:
		run.step()
	_skipping = false
	_after_skip()


## Call the attack once the stream is where the clip wants it, and say where and when (the clip
## tool crops around that spot and trims around that frame); quit a few seconds later.
func _demo_tick() -> void:
	if run.ability == null:
		return
	if _demo_cast_tick >= 0:
		if run.ticks - _demo_cast_tick > roundi(DEMO_AFTER * config.tick_rate):
			get_tree().quit(0)
		return
	var at: Variant = _demo_target(0.0)
	if at == null:
		return
	run.call_ability(at)
	_demo_cast_tick = run.ticks
	var p: Vector2 = at
	print("DEMO %s field %.1f %.1f frame %d" % [run.ability.id, p.x, p.y, Engine.get_frames_drawn()])


## Where the demo calls its attack, once the stream is in place (null until then). `early`
## (field units) moves every threshold up the field: the fast-forward stops that much early.
func _demo_target(early: float) -> Variant:
	var a: AbilityDef = run.ability
	if a.kind == AbilityDef.Kind.REPAIR:
		return Vector2(config.playfield_width() / 2.0, config.wall_y - 110.0) \
				if run.ticks >= 40 else null
	# Aimed attacks go where the pack is: on it (a blast), or just ahead of it (fire, mines).
	bot.ability_threat = 4.0
	var hit: Array = bot.best_cluster(run, 70.0)
	if hit.is_empty():
		return null
	var c: CombatSim.Enemy = hit[0]
	match a.kind:
		AbilityDef.Kind.BURN:
			if c.y >= 300.0 - early:
				var road: PathGeo = run.combat.geos[c.path]
				return road.point_at(minf(c.d + 70.0, road.length - 1.0))
		AbilityDef.Kind.MINES:
			if c.y >= 260.0 - early:
				return Vector2(c.x, c.y + 90.0)
		_:
			if c.y >= 380.0 - early:
				return c.pos() + Vector2(0.0, c.speed * a.delay * 0.7)
	return null


## DEV ONLY: the performance budget's load (prototype plan §3): ~260 enemies alive at once,
## with every plot occupied and firing. A deep copy; the real config is untouched.
## The budget load: 260 unkillable, crawling Drones. With `mix` (--stress=mix), 40 of them are
## the Stage 2 rule enemies instead (8 Wardens, 12 Wasps, 10 Burrowers, 10 Bombardiers), so
## the shield, burrow and flying rules are measured at scale.
static func _stress_config(base: RunConfig, mix: bool = false) -> RunConfig:
	var cfg: RunConfig = base.duplicate(true)
	var tank: EnemyDef = null
	for w: WaveDef in cfg.waves:
		for s: SpawnEntry in w.spawns:
			if s.enemy.id == &"grunt":
				tank = s.enemy.duplicate()
	var kinds: Array = [[tank, 220 if mix else 260]]
	if mix:
		for pair: Array in [["warden", 8], ["wasp", 12], ["burrower", 10], ["bombardier", 10]]:
			kinds.append([(load("res://data/enemies/%s.tres" % pair[0]) as EnemyDef).duplicate(),
					pair[1]])
	var wave := WaveDef.new()
	for pair: Array in kinds:
		var def: EnemyDef = pair[0]
		def.hp = 1e9
		def.speed = 6.0
		var entry := SpawnEntry.new()
		entry.enemy = def
		entry.count = pair[1]
		entry.interval = 0.03 * 260.0 / pair[1]
		wave.spawns.append(entry)
	cfg.waves = [wave]
	cfg.start_gold = 100000
	return cfg


func _fill_plots_for_stress() -> void:
	for i: int in run.plots.size():
		run.build(i, config.units[i % config.units.size()].id)
	run.start_wave()


## Skill-tree modifiers for `--tree=`: "all", "none", or node ids joined by commas (unknown
## ids are skipped with a warning; tier prerequisites are not checked: this is a dev switch).
static func tree_from_arg(tree: SkillTreeDef, arg: String) -> RunModifiers:
	var owned := SkillTree.new()
	for s: SkillDef in tree.skills:
		if arg == "all":
			owned.owned[s.id] = true
	if arg != "all" and arg != "none":
		for id: String in arg.split(",", false):
			if tree.skill_by_id(StringName(id)) == null:
				push_warning("--tree: unknown skill '%s'" % id)
			owned.owned[StringName(id)] = true
	return owned.to_modifiers(tree)


static func parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a: String in args:
		if not a.begins_with("--"):
			continue
		var kv: PackedStringArray = a.substr(2).split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return out
