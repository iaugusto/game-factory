extends GdUnitTestSuite
## Content expansion Stage 2 (docs/2026-09-27-content-expansion/): the Wasp (flying), the
## Warden (a shield aura), the Burrower (dives underground) and the Bombardier (a siege from
## range). Fixture map: straight paths down x = 90, 270, 450 to the gate at y = 860; plots
## 0 = (180, 700), 1 = (360, 700), 2 = (180, 300), 3 = (360, 300); barricade slots at y = 770.


func _run(spawns: Array[SpawnEntry]) -> Run:
	var run := Run.new(Fixtures.config([Fixtures.wave(spawns)]), 1)
	run.gold = 1000
	return run


func _steps(run: Run, n: int) -> void:
	for i: int in n:
		run.step()


func _first(run: Run, path: int = 0) -> CombatSim.Enemy:
	return run.combat.path_enemies[path][0] if not run.combat.path_enemies[path].is_empty() \
			else null


# --- Wasp: flying ---------------------------------------------------------------------------

func _wasp(hp: float = 1000.0, speed: float = 200.0) -> EnemyDef:
	var e := Fixtures.enemy(hp, speed, 5, 1, false, &"wasp")
	e.flying = true
	return e


func test_a_wasp_flies_over_the_barricade_that_stops_the_ground() -> void:
	var tank := Fixtures.enemy(1000, 200, 5)
	var run := _run([Fixtures.spawn(_wasp(), 1, 0, 1, 1), Fixtures.spawn(tank, 1, 0.1, 1, 1)])
	run.build_barricade(1)
	run.start_wave()
	_steps(run, 60 * 6)
	var wasp: CombatSim.Enemy = null
	var walker: CombatSim.Enemy = null
	for e: CombatSim.Enemy in run.combat.path_enemies[1]:
		if e.def.flying:
			wasp = e
		else:
			walker = e
	assert_bool(walker.at_barricade).is_true()
	assert_bool(wasp.sieging and not wasp.at_barricade).is_true()  # at the gate itself
	assert_float(wasp.y).is_equal_approx(860.0, 0.01)


func test_mortars_neither_aim_at_nor_splash_a_wasp_but_guns_hit_it() -> void:
	var run := _run([Fixtures.spawn(_wasp(1000, 5), 1, 0, 1, 0),
			Fixtures.spawn(Fixtures.enemy(1000, 5), 1, 0, 1, 0)])
	var mortar := Fixtures.unit(&"mortar", UnitDef.Attack.SHELL, 10, PackedInt32Array(), 5.0,
			0.5, 2000.0)
	mortar.splash_radius = 80.0
	mortar.projectile_speed = 800.0
	Fixtures.place(run, 2, mortar)
	run.start_wave()
	_steps(run, 60 * 4)
	var wasp: CombatSim.Enemy = null
	var walker: CombatSim.Enemy = null
	for e: CombatSim.Enemy in run.combat.path_enemies[0]:
		if e.def.flying:
			wasp = e
		else:
			walker = e
	assert_float(walker.hp).is_less(1000.0)  # side by side: the splash hit only the walker
	assert_float(wasp.hp).is_equal(1000.0)
	assert_bool(CombatSim.can_target(run.plots[2], wasp)).is_false()
	var gun := Fixtures.place(run, 3, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN))
	assert_bool(CombatSim.can_target(gun, wasp)).is_true()


func test_ground_effects_miss_a_wasp() -> void:
	var fire := Fixtures.ability(AbilityDef.Kind.BURN)
	fire.length = 200.0
	fire.damage = 50.0
	fire.duration = 5.0
	fire.delay = 0.0
	var cfg := Fixtures.config([Fixtures.wave([Fixtures.spawn(_wasp(1000, 10), 1, 0, 1, 0)])])
	var mud := ZoneDef.new()
	mud.kind = ZoneDef.Kind.MUD
	mud.center = Vector2(90, 400)
	mud.radius = 1000.0
	mud.value = 0.1
	cfg.map.zones = [mud]
	cfg.abilities = [fire]
	var run := Run.new(cfg, 1)
	run.start_wave()
	run.step()
	var wasp := _first(run)
	run.call_ability(wasp.pos())
	var y0: float = wasp.y
	_steps(run, 60)
	assert_float(wasp.hp).is_equal(1000.0)  # no fire under a flyer
	assert_float(wasp.y - y0).is_equal_approx(10.0, 0.5)  # full speed through the mud


# --- Warden: a shield aura --------------------------------------------------------------------

func _warden(amount: float = 10.0, regen: float = 5.0, radius: float = 60.0) -> EnemyDef:
	var e := Fixtures.enemy(100, 1, 5, 1, false, &"warden")
	e.shield_radius = radius
	e.shield_amount = amount
	e.shield_regen = regen
	return e


func test_a_warden_shields_itself_and_its_neighbours_up_to_its_cap() -> void:
	var ally := Fixtures.enemy(100, 1)
	var run := _run([Fixtures.spawn(_warden(), 1, 0, 1, 0), Fixtures.spawn(ally, 1, 0, 1, 0),
			Fixtures.spawn(ally, 1, 0, 1, 2)])  # the last on a far path
	run.start_wave()
	_steps(run, 60)  # 1 s at 5 a second
	var near: Array = run.combat.path_enemies[0]
	for e: CombatSim.Enemy in near:
		assert_float(e.shield).is_equal_approx(5.0, 0.1)
	assert_float(_first(run, 2).shield).is_equal(0.0)
	_steps(run, 60 * 3)
	for e: CombatSim.Enemy in near:
		assert_float(e.shield).is_equal_approx(10.0, 1e-3)  # capped


func test_a_shield_soaks_damage_before_hp_and_refills_only_near_a_warden() -> void:
	var run := _run([Fixtures.spawn(_warden(), 1, 0, 1, 0),
			Fixtures.spawn(Fixtures.enemy(100, 1), 1, 0, 1, 0)])
	run.start_wave()
	_steps(run, 60 * 3)
	var warden: CombatSim.Enemy = null
	var ally: CombatSim.Enemy = null
	for e: CombatSim.Enemy in run.combat.path_enemies[0]:
		if e.def.shield_amount > 0.0:
			warden = e
		else:
			ally = e
	run.combat._apply_damage(ally, 4.0)
	assert_float(ally.shield).is_equal_approx(6.0, 1e-3)
	assert_float(ally.hp).is_equal(100.0)
	run.combat._apply_damage(ally, 10.0)
	assert_float(ally.shield).is_equal(0.0)
	assert_float(ally.hp).is_equal_approx(96.0, 1e-3)  # the rest went through
	# The Warden falls: the shields stay where they are, but no longer refill.
	run.combat._apply_damage(warden, 1000.0)
	_steps(run, 60)
	assert_float(ally.shield).is_equal(0.0)
	assert_int(run.combat._wardens).is_equal(0)


func test_a_wardens_shield_grows_with_the_waves_hp_scale() -> void:
	var cfg := Fixtures.config([Fixtures.wave([Fixtures.spawn(_warden(), 1, 0, 1, 0)])])
	cfg.waves[0].hp_scale = 2.0
	var run := Run.new(cfg, 1)
	run.start_wave()
	_steps(run, 60 * 5)
	assert_float(_first(run).shield).is_equal_approx(20.0, 1e-3)


# --- Burrower: dives underground ------------------------------------------------------------

func _burrower(every: float = 1.0, length: float = 100.0, speed: float = 100.0) -> EnemyDef:
	var e := Fixtures.enemy(1000, speed, 5, 1, false, &"burrower")
	e.burrow_every = every
	e.burrow_length = length
	return e


func test_a_burrower_dives_out_of_reach_then_surfaces_further_on() -> void:
	var run := _run([Fixtures.spawn(_burrower(), 1, 0, 1, 0)])
	var gun := Fixtures.place(run, 2, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10,
			PackedInt32Array(), 0.001, 0.1, 2000.0))
	var dived: Array[float] = []
	var surfaced: Array[float] = []
	run.combat.enemy_burrowed.connect(func(e: CombatSim.Enemy) -> void: dived.append(e.d))
	run.combat.enemy_surfaced.connect(func(e: CombatSim.Enemy) -> void: surfaced.append(e.d))
	run.start_wave()
	_steps(run, 61)  # 1 s on the surface: it dives at d ~100
	var e := _first(run)
	assert_bool(e.burrowed()).is_true()
	assert_float(dived[0]).is_equal_approx(100.0, 2.0)
	assert_object(run.combat.first_in_reach(gun)).is_null()
	var hp: float = e.hp
	_steps(run, 30)
	assert_float(e.hp).is_equal(hp)  # nothing reaches it underground
	_steps(run, 31)
	assert_bool(e.burrowed()).is_false()
	assert_float(surfaced[0]).is_equal_approx(200.0, 2.0)
	assert_object(run.combat.first_in_reach(gun)).is_same(e)


func test_a_burrower_tunnels_under_the_barricade() -> void:
	# Dives at d ~700 for 140: under the barricade (~754), up at 840, then on to the gate.
	var run := _run([Fixtures.spawn(_burrower(7.0, 140.0), 1, 0, 1, 1)])
	run.build_barricade(1)
	run.start_wave()
	_steps(run, 60 * 10)
	var e := _first(run, 1)
	assert_bool(e.sieging and not e.at_barricade).is_true()
	assert_float(e.y).is_equal_approx(860.0, 0.01)


func test_a_slowed_burrower_cannot_dive_and_none_dives_at_the_gate() -> void:
	var run := _run([Fixtures.spawn(_burrower(1.0, 100.0, 50.0), 1, 0, 1, 0),
			Fixtures.spawn(_burrower(1.0, 100.0, 50.0), 1, 0, 1, 1)])
	run.start_wave()
	run.step()
	var chilled := _first(run, 0)
	chilled.slow_factor = 0.5
	chilled.slow_timer = 1000.0
	_steps(run, 60 * 3)
	assert_bool(chilled.burrowed()).is_false()
	# The other one walks to the gate diving on the way, but never ends underground there.
	var free := _first(run, 1)
	for i: int in 60 * 30:
		run.step()
		if free.sieging:
			break
	assert_bool(free.sieging).is_true()
	assert_bool(free.burrowed()).is_false()


# --- Bombardier: a siege from range ---------------------------------------------------------

func _bombardier(range_: float = 200.0, dmg: float = 7.0) -> EnemyDef:
	var e := Fixtures.enemy(1000, 200, dmg, 1, false, &"bombardier")
	e.siege_range = range_
	e.lob_time = 0.5
	e.attack_interval = 2.0
	return e


func test_a_bombardier_stops_short_and_its_globs_hit_the_gate_after_their_flight() -> void:
	var run := _run([Fixtures.spawn(_bombardier(), 1, 0, 1, 0)])
	run.start_wave()
	var e: CombatSim.Enemy = null
	while e == null or not e.sieging:
		run.step()
		e = _first(run)
	assert_bool(e.lobbing).is_true()
	assert_float(e.d).is_equal_approx(660.0, 1e-3)  # 200 short of the gate
	assert_int(run.combat.lobs.size()).is_equal(1)
	assert_float(run.wall_damage_taken).is_equal(0.0)  # still in the air
	_steps(run, 31)
	assert_float(run.wall_damage_taken).is_equal_approx(7.0, 1e-3)
	assert_int(run.combat.lobs.size()).is_equal(0)
	_steps(run, 120)  # the next one, 2 s after the first
	assert_float(run.wall_damage_taken).is_equal_approx(14.0, 1e-3)
	assert_float(e.d).is_equal_approx(660.0, 1e-3)


func test_a_glob_in_the_air_lands_even_if_its_thrower_dies() -> void:
	# A crawler on another path keeps the wave open (a wave's end clears what is in flight).
	var run := _run([Fixtures.spawn(_bombardier(), 1, 0, 1, 0),
			Fixtures.spawn(Fixtures.enemy(1000, 1), 1, 0, 1, 2)])
	run.start_wave()
	var e: CombatSim.Enemy = null
	while e == null or not e.sieging:
		run.step()
		e = _first(run)
	run.combat._apply_damage(e, 5000.0)
	_steps(run, 40)
	assert_float(run.wall_damage_taken).is_equal_approx(7.0, 1e-3)


func test_a_barricade_before_its_post_stops_a_bombardier_there() -> void:
	# Siege range 50: the post (810) is past the barricade (~754), which stops it first.
	var run := _run([Fixtures.spawn(_bombardier(50.0), 1, 0, 1, 1)])
	run.build_barricade(1)
	run.start_wave()
	_steps(run, 60 * 6)
	var e := _first(run, 1)
	assert_bool(e.at_barricade).is_true()
	assert_bool(e.lobbing).is_false()


func test_small_enemies_are_not_held_behind_a_standing_bombardier() -> void:
	var big := _bombardier()
	big.radius = 20.0
	var run := _run([Fixtures.spawn(big, 1, 0, 1, 0), Fixtures.spawn(Fixtures.enemy(1000, 200),
			1, 2.0, 1, 0)])
	run.start_wave()
	_steps(run, 60 * 9)
	var walker: CombatSim.Enemy = null
	for e: CombatSim.Enemy in run.combat.path_enemies[0]:
		if not e.lobbing:
			walker = e
	assert_float(walker.y).is_equal_approx(860.0, 0.01)  # walked past it to the gate
