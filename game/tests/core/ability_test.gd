extends GdUnitTestSuite
## Special attacks (AbilityDef, Run.call_ability, CombatSim casts): the pick before the first
## wave, the cooldown, and each effect kind. Fixture map: straight paths down x = 90, 270, 450.


## A run carrying `a`: wave 1 is one tanky, armoured enemy on path 0 (100 HP, armour 50, speed
## `speed`); wave 2 is a weak one, so the wave can be cleared.
func _run(a: AbilityDef, speed: float = 1.0) -> Run:
	var e := Fixtures.enemy(100, speed, 5)
	e.armor = 50.0
	var cfg := Fixtures.config([Fixtures.wave([Fixtures.spawn(e, 1, 0.0, 1.0, 0)]),
			Fixtures.wave([Fixtures.spawn(Fixtures.enemy(1, 100, 0), 1, 0.0)])])
	cfg.abilities = [a]
	return Run.new(cfg, 1)


func _enemy(run: Run) -> CombatSim.Enemy:
	for group: Array in run.combat.path_enemies:
		if not group.is_empty():
			return group[0]
	return null


## Start wave 1 and step until its enemy has walked to y >= `y`.
func _walk_to(run: Run, y: float) -> CombatSim.Enemy:
	run.start_wave()
	run.step()
	var e := _enemy(run)
	while e.y < y:
		run.step()
	return e


func _steps(run: Run, n: int) -> void:
	for i: int in n:
		run.step()


# --- the pick and the cooldown ------------------------------------------------------------

func test_a_run_starts_with_the_first_ability_and_picks_only_before_wave_one() -> void:
	var run := _run(Fixtures.ability())
	var other := Fixtures.ability(AbilityDef.Kind.FREEZE, &"other")
	assert_str(String(run.ability.id)).is_equal("ab")
	assert_bool(run.choose_ability(other)).is_true()
	assert_object(run.ability).is_same(other)
	run.start_wave()
	assert_bool(run.choose_ability(Fixtures.ability())).is_false()
	assert_object(run.ability).is_same(other)


func test_without_an_ability_there_is_nothing_to_call() -> void:
	var cfg := Fixtures.config([Fixtures.wave([Fixtures.spawn(Fixtures.enemy(), 1)])])
	var run := Run.new(cfg, 1)
	run.start_wave()
	assert_object(run.ability).is_null()
	assert_bool(run.ability_ready()).is_false()
	assert_bool(run.call_ability(Vector2(90, 10))).is_false()


func test_not_outside_a_wave() -> void:
	var run := _run(Fixtures.ability())
	assert_bool(run.ability_ready()).is_false()
	assert_bool(run.call_ability(Vector2(90, 50))).is_false()


func test_ready_again_at_the_next_wave_and_fire_mission_shortens_it() -> void:
	var run := _run(Fixtures.ability())
	run.start_wave()
	run.step()
	run.call_ability(Vector2(90, 0))
	assert_float(run.ability_cooldown_left).is_equal_approx(10.0, 1e-4)
	run.mods.ability_cooldown_bonus = 0.3
	assert_float(run.ability_cooldown()).is_equal_approx(7.0, 1e-4)
	Fixtures.sentinel(run)
	Fixtures.run_wave(run)
	if run.phase == Run.Phase.CARD:
		run.pick_card(0)
	run.start_wave()
	assert_bool(run.ability_ready()).is_true()


func test_deterministic() -> void:
	for kind: AbilityDef.Kind in AbilityDef.Kind.values():
		var hashes: Array[String] = []
		for k: int in 2:
			var a := Fixtures.ability(kind)
			a.duration = 2.0
			a.length = 40.0
			a.mine_count = 3
			var run := _run(a, 40.0)
			run.start_wave()
			_steps(run, 30)
			run.call_ability(Vector2(90, 60))
			_steps(run, 120)
			hashes.append(run.state_hash())
		assert_str(hashes[0]).override_failure_message("kind %d" % kind).is_equal(hashes[1])


# --- STRIKE ------------------------------------------------------------------------------

func test_a_strike_lands_after_the_delay_through_armour_then_cools_down() -> void:
	var run := _run(Fixtures.ability())
	run.start_wave()
	run.step()
	var e := _enemy(run)
	assert_bool(run.ability_ready()).is_true()
	assert_bool(run.call_ability(e.pos() + Vector2(30, 0))).is_true()
	assert_bool(run.ability_ready()).is_false()
	_steps(run, 25)  # < 0.5 s
	assert_float(e.hp).is_equal(100.0)
	_steps(run, 10)
	assert_float(e.hp).is_equal_approx(70.0, 1e-4)  # armour 50 would have floored a normal hit
	assert_float(run.ability_cooldown_left).is_greater(0.0)
	_steps(run, 60 * 10)
	assert_bool(run.ability_ready()).is_true()


func test_a_strike_misses_outside_its_radius() -> void:
	var run := _run(Fixtures.ability())
	run.start_wave()
	run.step()
	var e := _enemy(run)
	run.call_ability(e.pos() + Vector2(200, 0))
	_steps(run, 40)
	assert_float(e.hp).is_equal(100.0)


func test_damage_scales_with_the_wave() -> void:
	var run := _run(Fixtures.ability())
	run.config.waves[0].hp_scale = 2.0
	run.start_wave()
	run.step()
	var e := _enemy(run)
	run.call_ability(e.pos())
	_steps(run, 40)
	assert_float(e.hp).is_equal_approx(200.0 - 60.0, 1e-3)


# --- FREEZE ------------------------------------------------------------------------------

func _freeze() -> AbilityDef:
	var a := Fixtures.ability(AbilityDef.Kind.FREEZE)
	a.damage = 0.0
	a.duration = 2.0
	a.slow = 0.5
	a.slow_time = 1.0
	return a


func test_a_freeze_stops_everything_in_it_then_slows_it() -> void:
	var run := _run(_freeze(), 60.0)
	var e := _walk_to(run, 100.0)
	run.call_ability(e.pos())
	_steps(run, 32)  # it lands at 0.5 s
	var frozen_at: float = e.d
	assert_float(e.stun).is_greater(0.0)
	_steps(run, 60)  # a second later: not an inch
	assert_float(e.d).is_equal(frozen_at)
	assert_float(e.hp).is_equal(100.0)
	_steps(run, 68)  # thawed (2 s), still slowed (1 s more)
	var before: float = e.d
	_steps(run, 10)
	assert_float(e.d - before).is_equal_approx(60.0 * 0.5 * 10.0 / 60.0, 1e-3)
	_steps(run, 60)
	before = e.d
	_steps(run, 10)
	assert_float(e.d - before).is_equal_approx(60.0 * 10.0 / 60.0, 1e-3)


func test_a_frozen_sieger_stops_striking_the_gate() -> void:
	var run := _run(_freeze(), 400.0)
	run.start_wave()
	var e: CombatSim.Enemy = null
	while e == null or not e.sieging:
		run.step()
		e = _enemy(run)
	run.call_ability(e.pos())
	_steps(run, 31)
	var taken: float = run.wall_damage_taken
	_steps(run, 100)  # frozen for 2 s: its 1 s strikes don't land
	assert_float(run.wall_damage_taken).is_equal(taken)
	_steps(run, 90)
	assert_float(run.wall_damage_taken).is_greater(taken)


# --- BURN --------------------------------------------------------------------------------

func _burn() -> AbilityDef:
	var a := Fixtures.ability(AbilityDef.Kind.BURN)
	a.length = 40.0
	a.damage = 12.0  # a second
	a.duration = 1.0
	return a


func test_a_burning_strip_burns_whoever_is_in_it_until_it_goes_out() -> void:
	var run := _run(_burn())
	var e := _walk_to(run, 1.0)  # crawling at 1/s: it stays inside
	run.call_ability(e.pos())
	_steps(run, 31)  # lands
	assert_int(run.combat.hazards.size()).is_equal(1)
	_steps(run, 30)
	assert_float(e.hp).is_equal_approx(100.0 - 6.0, 0.25)  # past armour, like every ability
	_steps(run, 40)
	assert_int(run.combat.hazards.size()).is_equal(0)
	var hp: float = e.hp
	assert_float(hp).is_equal_approx(100.0 - 12.0, 0.25)
	_steps(run, 30)
	assert_float(e.hp).is_equal(hp)


func test_a_burning_strip_misses_what_is_outside_it() -> void:
	var run := _run(_burn())
	var e := _walk_to(run, 1.0)
	run.call_ability(e.pos() + Vector2(0, 80))  # 80 below: out of a 40-long stretch
	_steps(run, 90)
	assert_float(e.hp).is_equal(100.0)


func test_the_fire_lies_on_the_nearest_road_and_not_between_roads() -> void:
	var a := _burn()
	a.length = 100.0
	var crawler := Fixtures.enemy(100, 1.0, 5)
	var cfg := Fixtures.config([Fixtures.wave([Fixtures.spawn(crawler, 1, 0.0, 1.0, 0),
			Fixtures.spawn(crawler, 1, 0.0, 1.0, 1)])])
	cfg.abilities = [a]
	var run := Run.new(cfg, 1)
	run.start_wave()
	run.step()
	var left: CombatSim.Enemy = run.combat.path_enemies[0][0]
	var mid: CombatSim.Enemy = run.combat.path_enemies[1][0]
	run.call_ability(Vector2(150, 60))  # 60 from path 0 (x = 90), 120 from path 1
	_steps(run, 31)
	var h: CombatSim.Hazard = run.combat.hazards[0]
	assert_int(h.stretches.size()).is_equal(1)
	var st: CombatSim.Stretch = h.stretches[0]
	assert_int(st.path).is_equal(0)
	assert_float(st.d_lo).is_equal_approx(10.0, 0.01)  # centred on (90, 60), 100 long
	assert_float(st.d_hi).is_equal_approx(110.0, 0.01)
	for p: Vector2 in st.points:
		assert_float(p.x).is_equal(90.0)
	_steps(run, 30)
	assert_float(left.hp).is_less(100.0)
	assert_float(mid.hp).is_equal(100.0)  # a 200-wide strip would have caught it


## Two roads bend into one trunk at (270, 500) (as in paths_test): fire on the trunk burns
## walkers from both.
func test_fire_on_a_merged_trunk_burns_walkers_from_every_path_on_it() -> void:
	var a := _burn()
	a.length = 100.0
	a.damage = 60.0
	a.duration = 30.0
	var walker := Fixtures.enemy(1000, 100.0, 5)
	var cfg := Fixtures.config([Fixtures.wave([Fixtures.spawn(walker, 1, 0.0, 1.0, 0),
			Fixtures.spawn(walker, 1, 0.0, 1.0, 1)])])
	cfg.map.paths.resize(2)
	cfg.map.paths[0].points = PackedVector2Array([Vector2(100, 0), Vector2(100, 200),
			Vector2(270, 500), Vector2(270, 860)])
	cfg.map.paths[1].points = PackedVector2Array([Vector2(440, 0), Vector2(440, 200),
			Vector2(270, 500), Vector2(270, 860)])
	cfg.abilities = [a]
	var run := Run.new(cfg, 1)
	run.start_wave()
	run.step()
	var e0: CombatSim.Enemy = run.combat.path_enemies[0][0]
	var e1: CombatSim.Enemy = run.combat.path_enemies[1][0]
	run.call_ability(Vector2(270, 700))
	_steps(run, 60 * 10)  # both walk past the fire
	# In it for 100 of road + the fire's edge (8) and half the body (9) at each end: 1.25 s.
	for e: CombatSim.Enemy in [e0, e1]:
		assert_float(e.hp).is_equal_approx(1000.0 - 75.0, 3.0)


## One road forks at (270, 300): fire at the fork runs down both branches, and on the shared
## stem it is one stretch, not two.
func test_fire_at_a_fork_runs_down_every_branch() -> void:
	var a := _burn()
	a.length = 100.0
	var cfg := Fixtures.config([Fixtures.wave([Fixtures.spawn(Fixtures.enemy(), 1)])])
	cfg.map.paths.resize(2)
	cfg.map.paths[0].points = PackedVector2Array([Vector2(270, 0), Vector2(270, 300),
			Vector2(120, 450), Vector2(120, 860)])
	cfg.map.paths[1].points = PackedVector2Array([Vector2(270, 0), Vector2(270, 300),
			Vector2(420, 450), Vector2(420, 860)])
	var run := Run.new(cfg, 1)
	var road: Array[CombatSim.Stretch] = run.combat.burn_layout(a, Vector2(262, 290))  # the stem
	assert_int(road.size()).is_equal(2)
	assert_float(road[0].points[road[0].points.size() - 1].x).is_less(270.0)  # left branch
	assert_float(road[1].points[road[1].points.size() - 1].x).is_greater(270.0)  # right
	var stem: Array[CombatSim.Stretch] = run.combat.burn_layout(a, Vector2(270, 100))
	assert_int(stem.size()).is_equal(1)  # the same stretch on both paths: kept once
	# A tap already inside one branch burns only that one: the player picks the branch.
	var right: Array[CombatSim.Stretch] = run.combat.burn_layout(a, Vector2(330, 350))
	assert_int(right.size()).is_equal(1)
	assert_int(right[0].path).is_equal(1)


func test_the_fire_follows_the_road_round_a_bend() -> void:
	var a := _burn()
	a.length = 100.0
	var cfg := Fixtures.config([Fixtures.wave([Fixtures.spawn(Fixtures.enemy(), 1)])])
	cfg.map.paths[0].points = PackedVector2Array([Vector2(90, 0), Vector2(90, 300),
			Vector2(190, 400), Vector2(190, 860)])
	var run := Run.new(cfg, 1)
	var road: Array[CombatSim.Stretch] = run.combat.burn_layout(a, Vector2(80, 300))  # the bend
	assert_int(road.size()).is_equal(1)
	assert_int(road[0].path).is_equal(0)
	var pts: PackedVector2Array = road[0].points
	assert_int(pts.size()).is_equal(3)
	assert_vector(pts[1]).is_equal(Vector2(90, 300))  # it turns the corner with the road
	assert_vector(pts[0]).is_equal_approx(Vector2(90, 250), Vector2.ONE * 0.01)


# --- MINES -------------------------------------------------------------------------------

func _mines() -> AbilityDef:
	var a := Fixtures.ability(AbilityDef.Kind.MINES)
	a.radius = 30.0
	a.damage = 20.0
	a.mine_count = 3
	a.mine_spacing = 40.0
	a.delay = 0.1
	return a


func test_mines_are_laid_along_the_nearest_path() -> void:
	var run := _run(_mines(), 100.0)
	run.start_wave()
	run.call_ability(Vector2(120, 400))  # nearest path 0 (x = 90)
	_steps(run, 7)
	assert_int(run.combat.mines.size()).is_equal(3)
	for m: CombatSim.Mine in run.combat.mines:
		assert_int(m.path).is_equal(0)
		assert_float(m.pos.x).is_equal(90.0)
	assert_float(run.combat.mines[0].d).is_equal_approx(360.0, 1e-3)
	assert_float(run.combat.mines[2].d).is_equal_approx(440.0, 1e-3)


func test_each_mine_goes_off_under_the_first_enemy_to_reach_it() -> void:
	var run := _run(_mines(), 100.0)
	run.start_wave()
	run.call_ability(Vector2(90, 400))
	_steps(run, 7)
	var e := _enemy(run)
	while e.y < 340.0:
		run.step()
	assert_int(run.combat.mines.size()).is_equal(3)
	_steps(run, 20)  # onto the first mine (360)
	assert_int(run.combat.mines.size()).is_equal(2)
	assert_float(e.hp).is_equal_approx(80.0, 1e-3)
	_steps(run, 60)  # over the other two
	assert_int(run.combat.mines.size()).is_equal(0)
	assert_float(e.hp).is_equal_approx(40.0, 1e-3)


func test_mines_behind_a_walker_wait_for_the_next_one() -> void:
	var run := _run(_mines(), 100.0)
	var e := _walk_to(run, 500.0)
	run.call_ability(Vector2(90, 300))  # well behind it
	_steps(run, 30)
	assert_int(run.combat.mines.size()).is_equal(3)
	assert_float(e.hp).is_equal(100.0)


# --- REPAIR ------------------------------------------------------------------------------

func test_repair_heals_the_gate_units_and_barricade_without_aim() -> void:
	var a := Fixtures.ability(AbilityDef.Kind.REPAIR)
	a.delay = 0.0
	a.gate_heal = 25.0
	a.unit_heal = 0.5
	assert_bool(a.targeted()).is_false()
	var run := _run(a)
	var plot := Fixtures.place(run, 0, Fixtures.unit())
	plot.max_hp = 100.0
	plot.hp = 20.0
	run.gold = 999
	run.build_barricade(0)
	run.barricade().hp = 1.0
	run.start_wave()
	run.wall_damage_taken = 40.0
	assert_bool(run.call_ability(Vector2.ZERO)).is_true()
	run.step()
	assert_float(run.wall_damage_taken).is_equal_approx(15.0, 1e-3)
	assert_float(plot.hp).is_equal_approx(70.0, 1e-3)
	assert_float(run.barricade().hp).is_equal_approx(1.0 + run.barricade().max_hp * 0.5, 1e-3)
	# Never past full.
	_steps(run, 60 * 11)
	run.call_ability(Vector2.ZERO)
	run.step()
	assert_float(run.wall_damage_taken).is_equal(0.0)
	assert_float(plot.hp).is_equal(100.0)
