extends GdUnitTestSuite
## Combat rules, driven through Run with tiny explicit configs (Fixtures). Every unit is fixed
## on a plot; crates are broken only by the player's taps (Run.tap).
## Fixture plots: 0 = (180, 700), 1 = (360, 700), 2 = (180, 300), 3 = (360, 300).


func _single_wave_run(spawns: Array[SpawnEntry], crates: Array[CrateSpawn] = [],
		wall: float = 100.0) -> Run:
	var cfg := Fixtures.config([Fixtures.wave(spawns, crates)], wall)
	var run := Run.new(cfg, 1)
	run.start_wave()
	return run


func _steps(run: Run, n: int) -> void:
	for i: int in n:
		run.step()


## An enemy that keeps the wave open without ever mattering: it spawns late, far away.
func _keep_open() -> SpawnEntry:
	return Fixtures.spawn(Fixtures.enemy(1, 1, 0), 1, 600.0, 1.0, 0)


## The only crate on the field.
func _crate(run: Run) -> CombatSim.Crate:
	for lane: Array in run.combat.path_crates:
		if not lane.is_empty():
			return lane[0]
	return null


## Tap the (only) crate `n` times, one tick apart.
func _tap_crate(run: Run, n: int) -> void:
	for i: int in n:
		var c: CombatSim.Crate = _crate(run)
		if c == null:
			return
		run.tap(c.pos())
		run.step()


# --- the gate siege ---------------------------------------------------------------------

## Step until the first enemy of lane `lane` is at the gate; returns it.
func _until_sieging(run: Run, lane: int, max_ticks: int = 60 * 30) -> CombatSim.Enemy:
	for i: int in max_ticks:
		var enemies: Array = run.combat.path_enemies[lane]
		if not enemies.is_empty() and (enemies[0] as CombatSim.Enemy).sieging:
			return enemies[0]
		run.step()
	return null


func test_an_enemy_at_the_gate_stops_and_strikes_once_per_interval() -> void:
	# Speed 100 from y = 0 reaches 860 on tick 516; strikes then land every 60 ticks.
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(3, 100, 5), 1, 0, 1, 1)])
	var strikes: Array[float] = []
	run.combat.enemy_struck.connect(func(_e: CombatSim.Enemy, d: float) -> void: strikes.append(d))
	var e: CombatSim.Enemy = _until_sieging(run, 1)
	assert_object(e).is_not_null()
	assert_float(e.y).is_equal(run.config.wall_y)
	assert_bool(e.alive).is_true()
	assert_float(run.wall_hp()).is_equal_approx(95.0, 0.0001)  # the first strike, on arrival
	_steps(run, 59)
	assert_int(strikes.size()).is_equal(1)
	assert_float(e.y).is_equal(run.config.wall_y)  # it doesn't move on
	_steps(run, 1)
	assert_int(strikes.size()).is_equal(2)
	_steps(run, 120)
	assert_int(strikes.size()).is_equal(4)
	assert_float(run.wall_hp()).is_equal_approx(80.0, 0.0001)
	assert_int(run.phase).is_equal(Run.Phase.WAVE)  # a sieging enemy holds the wave open


func test_killing_the_sieger_stops_the_damage_and_ends_the_wave() -> void:
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(3, 100, 5), 1, 0, 1, 1)])
	var e: CombatSim.Enemy = _until_sieging(run, 1)
	assert_float(run.wall_hp()).is_equal_approx(95.0, 0.0001)
	Fixtures.sentinel(run)
	_steps(run, 2)
	assert_bool(e.alive).is_false()
	assert_float(run.wall_hp()).is_equal_approx(95.0, 0.0001)
	assert_int(run.phase).is_equal(Run.Phase.WON)


func test_the_gate_breaks_and_the_run_is_lost() -> void:
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(3, 400, 30), 1, 0, 1, 1)], [], 100.0)
	Fixtures.run_wave(run)
	assert_int(run.phase).is_equal(Run.Phase.LOST)
	assert_float(run.wall_hp()).is_less_equal(0.0)
	assert_int(run.combat.enemy_count()).is_equal(1)  # it was never killed: it broke through


func test_a_queen_breaks_the_gate_in_one_strike() -> void:
	var queen := Fixtures.enemy(100, 400, 999)
	var run := _single_wave_run([Fixtures.spawn(queen, 1, 0, 1, 1)], [], 300.0)
	_until_sieging(run, 1)
	run.step()
	assert_int(run.phase).is_equal(Run.Phase.LOST)


func test_unit_kills_earn_gold() -> void:
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(3, 100, 5, 2), 1, 0, 1, 1)])
	Fixtures.place(run, 1, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 3.0, 0.5))
	Fixtures.run_wave(run)
	assert_int(run.combat.kills).is_equal(1)
	assert_int(run.gold).is_equal(2)
	assert_float(run.wall_hp()).is_equal(100.0)


# --- crates: the player's taps ------------------------------------------------------------

func test_taps_break_a_crate_for_coins() -> void:
	var run := _single_wave_run([_keep_open()], [Fixtures.crate_spawn(Fixtures.crate(5, 10, 20), 0, 1)])
	var broken: Array[int] = []
	var tapped: Array[int] = []
	run.combat.crate_broken.connect(func(_c: CombatSim.Crate, coins: int) -> void: broken.append(coins))
	run.combat.crate_tapped.connect(func(c: CombatSim.Crate) -> void: tapped.append(c.id))
	run.step()
	_tap_crate(run, 4)
	assert_array(broken).is_empty()
	assert_int(tapped.size()).is_equal(4)
	assert_float(_crate(run).hp).is_equal(1.0)
	_tap_crate(run, 1)
	assert_array(broken).is_equal([10])
	assert_int(run.gold).is_equal(10)
	assert_int(run.combat.crate_count()).is_equal(0)


func test_a_tap_beside_the_crate_misses() -> void:
	var run := _single_wave_run([_keep_open()], [Fixtures.crate_spawn(Fixtures.crate(5, 10, 20), 0, 1)])
	run.step()
	var c: CombatSim.Crate = _crate(run)
	assert_bool(run.tap(c.pos() + Vector2(c.def.radius + 1.0, 0))).is_false()
	assert_bool(run.tap(c.pos() + Vector2(c.def.radius - 1.0, 0))).is_true()
	assert_float(c.hp).is_equal(4.0)


func test_tap_slop_widens_the_target() -> void:
	var run := _single_wave_run([_keep_open()], [Fixtures.crate_spawn(Fixtures.crate(5, 10, 20), 0, 1)])
	run.config.tap_slop = 10.0
	run.step()
	var c: CombatSim.Crate = _crate(run)
	assert_bool(run.tap(c.pos() + Vector2(c.def.radius + 9.0, 0))).is_true()


func test_a_tap_hits_the_crate_under_the_finger() -> void:
	var run := _single_wave_run([_keep_open()], [
		Fixtures.crate_spawn(Fixtures.crate(5, 10, 20), 0, 0),
		Fixtures.crate_spawn(Fixtures.crate(5, 10, 20), 0, 2),
	])
	run.step()
	var right: CombatSim.Crate = run.combat.path_crates[2][0]
	assert_bool(run.tap(right.pos())).is_true()
	assert_float(right.hp).is_equal(4.0)
	assert_float((run.combat.path_crates[0][0] as CombatSim.Crate).hp).is_equal(5.0)


func test_taps_do_nothing_outside_a_wave() -> void:
	var cfg := Fixtures.config([Fixtures.wave([_keep_open()],
			[Fixtures.crate_spawn(Fixtures.crate(5, 10, 20), 0, 1)])])
	var run := Run.new(cfg, 1)
	assert_bool(run.tap(Vector2(270, 0))).is_false()


func test_crowbars_make_taps_hit_harder() -> void:
	var run := _single_wave_run([_keep_open()], [Fixtures.crate_spawn(Fixtures.crate(5, 10, 20), 0, 1)])
	run.mods.crate_damage_bonus = 1.5
	run.step()
	_tap_crate(run, 1)
	assert_float(_crate(run).hp).is_equal(2.5)
	_tap_crate(run, 1)
	assert_int(run.combat.crates_broken).is_equal(1)


func test_crate_reward_bonus_applies() -> void:
	var mods := RunModifiers.new()
	mods.crate_reward_bonus = 0.5
	var cfg := Fixtures.config([Fixtures.wave([_keep_open()],
			[Fixtures.crate_spawn(Fixtures.crate(1, 10, 20), 0, 1)])])
	var run := Run.new(cfg, 1, mods)
	run.start_wave()
	run.step()
	_tap_crate(run, 1)
	assert_int(run.gold).is_equal(15)


func test_unbroken_crate_is_lost_at_the_wall() -> void:
	var run := _single_wave_run([_keep_open()], [Fixtures.crate_spawn(Fixtures.crate(5, 10, 500), 0, 1)])
	var lost: Array[int] = []
	run.combat.crate_lost.connect(func(c: CombatSim.Crate) -> void: lost.append(c.id))
	_steps(run, 180)
	assert_int(lost.size()).is_equal(1)
	assert_int(run.gold).is_equal(0)
	assert_float(run.wall_hp()).is_equal(100.0)


func test_boost_crate_speeds_up_every_unit_for_its_duration_only() -> void:
	var run := _single_wave_run([_keep_open()],
			[Fixtures.crate_spawn(Fixtures.crate(1, 0, 20, 2.0, 1.0), 0, 1)])
	var gun := Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 1.0, 1.0)
	run.step()
	_tap_crate(run, 1)
	assert_float(run.combat.boost_rate_mult()).is_equal_approx(2.0, 0.0001)
	assert_float(run.combat.reload_of(gun, 1)).is_equal_approx(0.5, 0.0001)
	_steps(run, 61)
	assert_float(run.combat.boost_time).is_equal(0.0)
	assert_float(run.combat.reload_of(gun, 1)).is_equal_approx(1.0, 0.0001)


func test_units_never_shoot_crates() -> void:
	var run := _single_wave_run([_keep_open()], [Fixtures.crate_spawn(Fixtures.crate(5, 10, 50), 0, 0)])
	var plot := Fixtures.place(run, 0, Fixtures.unit())
	_steps(run, 120)
	assert_int(plot.shots_fired).is_equal(0)
	assert_float((run.combat.path_crates[0][0] as CombatSim.Crate).hp).is_equal(5.0)


# --- units on plots ---------------------------------------------------------------------

func test_unit_fires_once_per_reload() -> void:
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(1000, 1, 5), 1, 0, 1, 0)])
	var plot := Fixtures.place(run, 0, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 1.0, 0.5))
	_steps(run, 90)  # shots on ticks 1, 31 and 61
	assert_int(plot.shots_fired).is_equal(3)
	assert_float((run.combat.path_enemies[0][0] as CombatSim.Enemy).hp).is_equal(997.0)


func test_levels_and_overclock_shorten_the_reload() -> void:
	var u := Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [5, 5], 2.0, 1.0)
	assert_float(u.reload_at(2)).is_equal_approx(0.85, 0.0001)
	assert_float(u.damage_at(3)).is_equal_approx(4.0, 0.0001)
	var run := _single_wave_run([_keep_open()])
	assert_float(run.combat.reload_of(u, 1)).is_equal_approx(1.0, 0.0001)
	run.mods.unit_rate_bonus = 0.25
	assert_float(run.combat.reload_of(u, 1)).is_equal_approx(0.8, 0.0001)


func test_enemies_out_of_reach_are_ignored() -> void:
	# Plot 0 is at (180, 700); lane 0's centre is x = 90. With reach 150 an enemy there comes
	# into reach once 700 - y <= 120, i.e. at y >= 580.
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(1000, 100, 5), 1, 0, 1, 0)])
	var plot := Fixtures.place(run, 0, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 1, 1, 150))
	var e: CombatSim.Enemy = null
	while e == null or e.y < 570.0:
		run.step()
		e = run.combat.path_enemies[0][0] if not run.combat.path_enemies[0].is_empty() else null
	assert_int(plot.shots_fired).is_equal(0)
	while e.y < 590.0:
		run.step()
	assert_int(plot.shots_fired).is_equal(1)


func test_targets_the_enemy_nearest_the_wall() -> void:
	var run := _single_wave_run([
		Fixtures.spawn(Fixtures.enemy(100, 10, 5), 1, 0, 1, 0),
		Fixtures.spawn(Fixtures.enemy(100, 100, 5), 1, 0, 1, 2),
	])
	var plot := Fixtures.place(run, 3, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 1.0, 5.0))
	_steps(run, 30)
	assert_int(plot.shots_fired).is_equal(1)
	assert_float((run.combat.path_enemies[0][0] as CombatSim.Enemy).hp).is_equal(100.0)
	assert_float((run.combat.path_enemies[2][0] as CombatSim.Enemy).hp).is_equal(99.0)


func _mortar() -> UnitDef:
	var m := Fixtures.unit(&"mortar", UnitDef.Attack.SHELL, 10, [], 5.0, 100.0)
	m.projectile_speed = 1000.0
	m.splash_radius = 20.0
	return m


## Fire one shell at a lone enemy of `speed` and return its hp once the shell has landed.
func _hp_after_one_shell(speed: float) -> float:
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(100, speed, 5), 1, 0, 1, 0), _keep_open()])
	Fixtures.place(run, 0, _mortar())
	var landed: Array[bool] = []
	run.combat.shell_landed.connect(func(_s: CombatSim.Shot) -> void: landed.append(true))
	while landed.is_empty() and run.ticks < 600:
		run.step()
	assert_bool(landed.is_empty()).is_false()
	return (run.combat.path_enemies[0][0] as CombatSim.Enemy).hp


func test_shell_hits_a_slow_enemy_but_a_fast_one_walks_out() -> void:
	# The shell flies ~0.7 s to where the target was. A slow enemy moves ~3.5 units (inside the
	# 20-unit splash); a fast one moves ~210 and is missed.
	assert_float(_hp_after_one_shell(5.0)).is_equal(95.0)
	assert_float(_hp_after_one_shell(300.0)).is_equal(100.0)


func test_shell_splash_hits_the_whole_pack() -> void:
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(100, 5, 5), 3, 0, 0.0, 0), _keep_open()])
	Fixtures.place(run, 0, _mortar())
	_steps(run, 60)
	for e: CombatSim.Enemy in run.combat.path_enemies[0]:
		assert_float(e.hp).is_equal(95.0)


func test_beam_hits_every_enemy_in_the_target_lane_only() -> void:
	var run := _single_wave_run([
		Fixtures.spawn(Fixtures.enemy(100, 10, 5), 3, 0, 0.0, 0),
		Fixtures.spawn(Fixtures.enemy(100, 5, 5), 1, 0, 1, 1),
	])
	Fixtures.place(run, 0, Fixtures.unit(&"rail", UnitDef.Attack.BEAM, 10, [], 10.0, 100.0))
	_steps(run, 20)
	for e: CombatSim.Enemy in run.combat.path_enemies[0]:
		assert_float(e.hp).is_equal(90.0)
	assert_float((run.combat.path_enemies[1][0] as CombatSim.Enemy).hp).is_equal(100.0)


func test_bullet_travels_then_slows() -> void:
	var frost := Fixtures.unit(&"frost", UnitDef.Attack.BULLET, 10, [], 0.5, 5.0)
	frost.projectile_speed = 2000.0
	frost.slow_factor = 0.5
	frost.slow_duration = 2.0
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(100, 20, 5), 1, 0, 1, 1)])
	Fixtures.place(run, 1, frost)
	run.step()
	assert_int(run.combat.shots.size()).is_equal(1)
	_steps(run, 59)
	assert_int(run.combat.shots.size()).is_equal(0)
	var e: CombatSim.Enemy = run.combat.path_enemies[1][0]
	assert_float(e.hp).is_equal(99.5)
	assert_float(e.slow_factor).is_equal_approx(0.5, 0.0001)
	assert_float(e.slow_timer).is_greater(0.0)


func test_bullet_fizzles_when_its_target_dies_first() -> void:
	var slow := Fixtures.unit(&"slowgun", UnitDef.Attack.BULLET, 10, [], 1.0, 100.0)
	slow.projectile_speed = 50.0
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(2, 10, 5, 0), 1, 0, 1, 1), _keep_open()])
	Fixtures.place(run, 3, slow)
	# A hitscan unit kills the target on its first shot; the slow bullet (~6 s of flight) flies
	# on to where the target was and vanishes there without hitting anything.
	Fixtures.place(run, 1, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 5.0, 100.0))
	_steps(run, 480)
	assert_int(run.combat.kills).is_equal(1)
	assert_int(run.combat.shots.size()).is_equal(0)


# --- run modifiers on units ---------------------------------------------------------------

func test_unit_damage_bonus_scales_every_shot() -> void:
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(1000, 1, 5), 1, 0, 1, 0)])
	run.mods.unit_damage_bonus = 0.5
	Fixtures.place(run, 0, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 2.0, 5.0))
	_steps(run, 1)
	assert_float((run.combat.path_enemies[0][0] as CombatSim.Enemy).hp).is_equal(997.0)


func test_reach_bonus_lets_a_unit_fire_sooner() -> void:
	# Plot 0 at (180, 700) with reach 150 can't touch an enemy on path 0 (x = 90) at y = 300:
	# the distance is ~410. With +200% reach (450) it can.
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(1000, 0.001, 5), 1, 0, 1, 0)])
	var gun := Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 1, 1, 150)
	var plot := Fixtures.place(run, 0, gun)
	_steps(run, 1)
	var e: CombatSim.Enemy = run.combat.path_enemies[0][0]
	e.d = 300.0  # the path runs straight down from y = 0, so d is y
	_steps(run, 2)
	assert_int(plot.shots_fired).is_equal(0)
	run.mods.unit_reach_bonus = 2.0
	assert_float(run.combat.reach_of(gun)).is_equal_approx(450.0, 0.001)
	_steps(run, 1)
	assert_int(plot.shots_fired).is_equal(1)


func test_crits_multiply_unit_damage() -> void:
	var run := _single_wave_run([Fixtures.spawn(Fixtures.enemy(1000, 1, 5), 1, 0, 1, 0)])
	run.mods.crit_chance = 1.0
	run.mods.crit_mult_bonus = 1.0
	Fixtures.place(run, 0, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 2.0, 5.0))
	_steps(run, 1)
	# crit_multiplier 2 + bonus 1 = ×3.
	assert_float((run.combat.path_enemies[0][0] as CombatSim.Enemy).hp).is_equal(994.0)


# --- spitters ----------------------------------------------------------------------------

## A near-stationary spitter (it sits at y ~ 0) with range `reach`, spitting every `interval`.
func _spitter(reach: float = 150.0, interval: float = 2.0) -> EnemyDef:
	var e := Fixtures.enemy(1000, 0.001, 1, 0, false, &"spitter")
	e.spit_interval = interval
	e.spit_range = reach
	e.spit_speed = 10000.0
	e.disable_duration = 3.0
	return e


func test_a_spitter_disables_the_nearest_unit_in_range() -> void:
	# The spitter sits in lane 0 (x = 90) at y ~ 0; plots 2 (180, 300) and 3 (360, 300) are
	# ~313 and ~402 away. With range 350 only plot 2 is in reach.
	var run := _single_wave_run([Fixtures.spawn(_spitter(350.0), 1, 0, 1, 0)])
	var near := Fixtures.place(run, 2, Fixtures.unit())
	var far := Fixtures.place(run, 3, Fixtures.unit())
	var disabled: Array[int] = []
	run.combat.unit_disabled.connect(func(p: CombatSim.Plot, _d: float) -> void: disabled.append(p.index))
	_steps(run, 3)
	assert_array(disabled).is_equal([2])
	assert_bool(near.is_disabled()).is_true()
	assert_bool(far.is_disabled()).is_false()


func test_a_disabled_unit_holds_fire_until_it_recovers() -> void:
	# Plot 2 (180, 300) with a gun: the spitter jams it on tick 2 for 3 s; it must not fire
	# while jammed, then fires again (the spitter's next glob is 100 s away).
	var run := _single_wave_run([Fixtures.spawn(_spitter(350.0, 100.0), 1, 0, 1, 0)])
	var gun := Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 0.001, 0.25)
	var plot := Fixtures.place(run, 2, gun)
	_steps(run, 3)
	assert_bool(plot.is_disabled()).is_true()
	var fired: int = plot.shots_fired
	_steps(run, 60 * 2)
	assert_int(plot.shots_fired).is_equal(fired)
	_steps(run, 60 + 30)  # recovered at ~3 s, then the paused reload (~14 ticks) finishes
	assert_bool(plot.is_disabled()).is_false()
	assert_int(plot.shots_fired).is_greater(fired)


func test_spitters_ignore_empty_disabled_and_out_of_range_plots() -> void:
	var run := _single_wave_run([Fixtures.spawn(_spitter(100.0), 1, 0, 1, 0)])
	Fixtures.place(run, 2, Fixtures.unit())
	_steps(run, 30)
	assert_int(run.combat.spits.size()).is_equal(0)  # nothing within 100
	var e: CombatSim.Enemy = run.combat.path_enemies[0][0]
	e.d = 300.0  # straight path from y = 0: d is y
	e.y = 300.0  # now plot 2 is 90 away, plot 0 (empty) is 400 away
	run.combat.plots[2].disabled = 5.0
	assert_object(run.combat.spit_target(e)).is_null()  # the only unit in range is jammed
	run.combat.plots[2].disabled = 0.0
	assert_object(run.combat.spit_target(e)).is_same(run.combat.plots[2])


func test_spits_are_cleared_with_the_wave() -> void:
	var run := _single_wave_run([Fixtures.spawn(_spitter(350.0), 1, 0, 1, 0)])
	var plot := Fixtures.place(run, 2, Fixtures.unit())
	_steps(run, 3)
	assert_bool(plot.is_disabled()).is_true()
	run.combat.end_wave()
	assert_bool(plot.is_disabled()).is_false()
	assert_int(run.combat.spits.size()).is_equal(0)


func test_a_spitter_at_the_gate_stops_spitting() -> void:
	# It spits while it walks (a unit is always in its huge range), but once at the gate it
	# only strikes: spitting point-blank at the wall's spots made a death spiral.
	var walker := _spitter(5000.0, 0.5)
	walker.speed = 400.0
	var run := _single_wave_run([Fixtures.spawn(walker, 1, 0, 1, 1)])
	Fixtures.place(run, 2, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 0.0001, 100.0))
	var fired: Array[int] = []
	run.combat.spit_fired.connect(func(sp: CombatSim.Spit) -> void: fired.append(sp.id))
	assert_object(_until_sieging(run, 1)).is_not_null()
	assert_int(fired.size()).is_greater(0)
	var before: int = fired.size()
	_steps(run, 120)
	assert_int(fired.size()).is_equal(before)
