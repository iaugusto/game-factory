extends GdUnitTestSuite
## Maps from paths (docs/2026-09-26-maps-from-paths/): path geometry, bent and merged paths,
## portals that open later, terrain, and plots that unlock.


# --- PathGeo --------------------------------------------------------------------------------

func test_path_geometry() -> void:
	# An L: 100 down, then 100 across and down at 45° (length 141.4).
	var g := PathGeo.new(PackedVector2Array([Vector2(0, 0), Vector2(0, 100), Vector2(100, 200)]))
	assert_float(g.length).is_equal_approx(100.0 + sqrt(20000.0), 0.01)
	assert_vector(g.point_at(50.0)).is_equal_approx(Vector2(0, 50), Vector2.ONE * 0.01)
	assert_vector(g.point_at(100.0 + sqrt(20000.0) / 2.0)).is_equal_approx(Vector2(50, 150), Vector2.ONE * 0.01)
	assert_vector(g.point_at(1e9)).is_equal(Vector2(100, 200))
	assert_float(g.d_at_y(150.0)).is_equal_approx(100.0 + sqrt(20000.0) / 2.0, 0.01)
	assert_float(g.d_at_y(-5.0)).is_equal(0.0)
	var near: Vector2 = g.nearest(Vector2(20, 50))
	assert_float(near.x).is_equal_approx(50.0, 0.01)
	assert_float(near.y).is_equal_approx(20.0, 0.01)
	assert_vector(g.normal_at(10.0)).is_equal_approx(Vector2(-1, 0), Vector2.ONE * 0.01)


# --- a bent, merging map ----------------------------------------------------------------------

## Two paths that bend inward and merge into one trunk at (270, 500), and a short flank path
## that opens at wave 2. Plots: 0 beside the trunk, 1 far up the left, 2 locked until wave 2.
func _merge_config(waves: Array[WaveDef]) -> RunConfig:
	var c := Fixtures.config(waves)
	var m := MapDef.new()
	for pts: PackedVector2Array in [
			PackedVector2Array([Vector2(100, 0), Vector2(100, 200), Vector2(270, 500), Vector2(270, 860)]),
			PackedVector2Array([Vector2(440, 0), Vector2(440, 200), Vector2(270, 500), Vector2(270, 860)]),
			PackedVector2Array([Vector2(540, 600), Vector2(460, 700), Vector2(460, 860)])]:
		var p := PathDef.new()
		p.points = pts
		p.spread = 0.0
		m.paths.append(p)
	m.paths[2].opens_at_wave = 2
	m.plots = PackedVector2Array([Vector2(180, 700), Vector2(30, 100), Vector2(380, 780)])
	m.plot_unlock_waves = PackedInt32Array([1, 1, 2])
	m.barricade_slots = PackedVector2Array([Vector2(270, 770)])
	c.map = m
	return c


func test_enemies_follow_a_bent_path_to_the_gate() -> void:
	var cfg := _merge_config([Fixtures.wave([Fixtures.spawn(Fixtures.enemy(1000, 200, 5), 1, 0, 1, 0)])])
	var run := Run.new(cfg, 1)
	run.start_wave()
	var e: CombatSim.Enemy = null
	var xs: Array[float] = []
	for i: int in 60 * 8:
		run.step()
		if not run.combat.path_enemies[0].is_empty():
			e = run.combat.path_enemies[0][0]
			xs.append(e.x)
	assert_float(xs.min()).is_equal_approx(100.0, 0.5)  # it started down the left
	assert_bool(e.sieging).is_true()
	assert_vector(e.pos()).is_equal_approx(Vector2(270, 860), Vector2.ONE * 0.01)  # the gate


func test_a_barricade_on_the_merged_trunk_blocks_both_entrances() -> void:
	var tank := Fixtures.enemy(1000, 300, 1)
	var cfg := _merge_config([Fixtures.wave([Fixtures.spawn(tank, 1, 0, 1, 0), Fixtures.spawn(tank, 1, 0, 1, 1)])])
	var run := Run.new(cfg, 1)
	run.gold = 100
	run.build_barricade(0)
	assert_bool(run.barricade().blocks(0) and run.barricade().blocks(1)).is_true()
	assert_bool(run.barricade().blocks(2)).is_false()
	run.start_wave()
	for i: int in 60 * 6:
		run.step()
	for path: int in 2:
		var e: CombatSim.Enemy = run.combat.path_enemies[path][0]
		assert_bool(e.at_barricade).override_failure_message("path %d" % path).is_true()


func test_portals_open_on_their_wave_and_random_spawns_wait_for_them() -> void:
	var e := Fixtures.enemy(1, 300, 0)
	var many := Fixtures.spawn(e, 40, 0, 0.05, -1)
	var cfg := _merge_config([Fixtures.wave([many]), Fixtures.wave([many])])
	var run := Run.new(cfg, 1)
	Fixtures.sentinel_on(run, 0)
	assert_array(Array(run.open_paths())).contains_exactly([0, 1])
	assert_bool(run.newly_open_paths().is_empty()).is_true()
	var used: Dictionary = {}
	run.combat.enemy_spawned.connect(func(en: CombatSim.Enemy) -> void: used[en.path] = true)
	Fixtures.run_wave(run)
	assert_bool(used.has(2)).is_false()
	assert_array(Array(run.newly_open_paths())).contains_exactly([2])
	used.clear()
	Fixtures.run_wave(run)
	assert_bool(used.has(2)).is_true()


func test_plots_unlock_on_their_wave() -> void:
	var cfg := _merge_config([Fixtures.wave([Fixtures.spawn(Fixtures.enemy(1, 300, 0), 1)]),
			Fixtures.wave([Fixtures.spawn(Fixtures.enemy(1, 300, 0), 1)])])
	cfg.units = [Fixtures.unit()]
	var run := Run.new(cfg, 1)
	Fixtures.sentinel_on(run, 0)
	run.gold = 100
	assert_bool(run.plot_open(2)).is_false()
	assert_bool(run.build(2, &"gun")).is_false()
	Fixtures.run_wave(run)
	assert_bool(run.plot_open(2)).is_true()
	assert_bool(run.build(2, &"gun")).is_true()


func test_mud_slows_and_high_ground_reaches_further() -> void:
	var cfg := Fixtures.config([Fixtures.wave([Fixtures.spawn(Fixtures.enemy(1000, 100, 1), 1, 0, 1, 0)])])
	var mud := ZoneDef.new()
	mud.kind = ZoneDef.Kind.MUD
	mud.center = Vector2(90, 300)
	mud.radius = 100.0
	mud.value = 0.5
	var ridge := ZoneDef.new()
	ridge.kind = ZoneDef.Kind.HIGH_GROUND
	ridge.center = Vector2(180, 700)
	ridge.radius = 30.0
	ridge.value = 0.25
	cfg.map.zones = [mud, ridge]
	var run := Run.new(cfg, 1)
	run.start_wave()
	for i: int in 60:
		run.step()
	var e: CombatSim.Enemy = run.combat.path_enemies[0][0]
	assert_float(e.d).is_equal_approx(100.0, 2.0)  # a clear second at 100/s
	e.d = 250.0
	e.y = 250.0
	var before: float = e.d
	for i: int in 60:
		run.step()
	assert_float(e.d - before).is_equal_approx(50.0, 2.0)  # half speed in the mud
	var gun := Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 1, 1, 100)
	var on_ridge := Fixtures.place(run, 0, gun)  # (180, 700)
	var off_ridge := Fixtures.place(run, 1, gun)  # (360, 700)
	assert_float(run.combat.plot_reach(on_ridge)).is_equal_approx(125.0, 0.01)
	assert_float(run.combat.plot_reach(off_ridge)).is_equal_approx(100.0, 0.01)


func test_targets_the_enemy_with_the_least_way_to_go_across_paths() -> void:
	# Path 0 is long (it bends far left first), path 2 is short (a flank). An enemy far down
	# path 0 can still have more way to go than one early on the short flank.
	var cfg := _merge_config([Fixtures.wave([
		Fixtures.spawn(Fixtures.enemy(1000, 0.001, 1), 1, 0, 1, 0),
		Fixtures.spawn(Fixtures.enemy(1000, 0.001, 1), 1, 0, 1, 2),
	]), Fixtures.wave()])
	var run := Run.new(cfg, 1)
	cfg.map.paths[2].opens_at_wave = 1
	run.start_wave()
	run.step()
	var long_one: CombatSim.Enemy = run.combat.path_enemies[0][0]
	var flank: CombatSim.Enemy = run.combat.path_enemies[2][0]
	var g0: PathGeo = run.combat.geos[0]
	var g2: PathGeo = run.combat.geos[2]
	long_one.d = g0.length - 200.0  # 200 to go
	flank.d = g2.length - 150.0  # 150 to go
	for en: CombatSim.Enemy in [long_one, flank]:
		var p: Vector2 = run.combat.geos[en.path].point_at(en.d)
		en.x = p.x
		en.y = p.y
	var gun := Fixtures.place(run, 0, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 1, 1, 5000))
	assert_object(run.combat.first_in_reach(gun)).is_same(flank)
