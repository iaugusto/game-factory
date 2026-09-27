extends GdUnitTestSuite
## The counter chart, masteries, selling and the wave helpers
## (docs/2026-09-26-counters-and-coin-sinks/).

const K := UnitDef.DamageType.KINETIC
const X := UnitDef.DamageType.EXPLOSIVE
const P := UnitDef.DamageType.PIERCING
const C := UnitDef.DamageType.CRYO


func _cfg() -> RunConfig:
	return Fixtures.config([Fixtures.wave()])


func _enemy(weak: int = 0, resist: int = 0, armor: float = 0.0) -> EnemyDef:
	var e := Fixtures.enemy(1000, 1, 5)
	e.weak_to = weak
	e.resists = resist
	e.armor = armor
	return e


# --- the chart ----------------------------------------------------------------------------

func test_weakness_doubles_and_resistance_halves() -> void:
	var cfg := _cfg()
	var e := _enemy(1 << P, 1 << K)
	assert_float(CombatSim.effective_damage(cfg, e, 10.0, P)).is_equal(20.0)
	assert_float(CombatSim.effective_damage(cfg, e, 10.0, K)).is_equal(5.0)
	assert_float(CombatSim.effective_damage(cfg, e, 10.0, X)).is_equal(10.0)


func test_armor_blunts_light_hits_down_to_a_floor() -> void:
	var cfg := _cfg()
	var e := _enemy(1 << P, 0, 3.0)
	assert_float(CombatSim.effective_damage(cfg, e, 18.0, P)).is_equal(30.0)  # (18-3)×2
	assert_float(CombatSim.effective_damage(cfg, e, 1.0, K)).is_equal_approx(0.15, 0.0001)
	assert_float(CombatSim.effective_damage(cfg, e, 1.0, K, 1.0)).is_equal(1.0)  # AP rounds


func test_hits_go_through_the_chart_and_report_it() -> void:
	var weak := _enemy(1 << K)
	var run := Run.new(Fixtures.config([Fixtures.wave([Fixtures.spawn(weak, 1, 0, 1, 0)])]), 1)
	run.start_wave()
	var effects: Array[int] = []
	run.combat.enemy_hit.connect(func(_e: CombatSim.Enemy, _a: float, fx: int) -> void: effects.append(fx))
	Fixtures.place(run, 0, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 3.0, 5.0))
	run.step()
	assert_float((run.combat.path_enemies[0][0] as CombatSim.Enemy).hp).is_equal(994.0)
	assert_array(effects).is_equal([1])


func test_counters_queries() -> void:
	var cfg := _cfg()
	var sniper := Fixtures.unit(&"sniper")
	sniper.damage_type = P
	sniper.damage = 18.0
	var mg := Fixtures.unit(&"mg")
	mg.damage_type = K
	cfg.units = [sniper, mg]
	var tank := _enemy(1 << P, 0, 3.0)
	assert_array(Counters.units_strong_vs(cfg, tank)).contains_exactly([sniper])
	assert_array(Counters.units_weak_vs(cfg, tank)).contains_exactly([mg])  # armour blunts it
	cfg.waves = [Fixtures.wave([Fixtures.spawn(tank)])]
	assert_array(Counters.enemies_countered_by(cfg, sniper)).contains_exactly([tank])


# --- masteries, selling --------------------------------------------------------------------

func _maxed_run() -> Run:
	var cfg := _cfg()
	var gun := Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, PackedInt32Array([10]), 2.0, 1.0)
	var over := MasteryDef.new()
	over.id = &"overcharge"
	over.damage_bonus = 0.25
	var fast := MasteryDef.new()
	fast.id = &"fast"
	fast.reload_bonus = 1.0
	gun.masteries = [over, fast]
	gun.mastery_cost = 30
	cfg.units = [gun]
	var run := Run.new(cfg, 1)
	run.gold = 100
	return run


func test_masteries_only_at_max_level_and_only_once() -> void:
	var run := _maxed_run()
	assert_bool(run.build(0, &"gun")).is_true()
	assert_int(run.mastery_cost(0)).is_equal(-1)
	assert_bool(run.buy_mastery(0, 0)).is_false()
	run.upgrade(0)
	assert_int(run.mastery_cost(0)).is_equal(30)
	assert_bool(run.buy_mastery(0, 5)).is_false()
	assert_bool(run.buy_mastery(0, 0)).is_true()
	assert_int(run.gold).is_equal(100 - 10 - 10 - 30)
	assert_int(run.mastery_cost(0)).is_equal(-1)
	assert_bool(run.buy_mastery(0, 1)).is_false()
	var plot: CombatSim.Plot = run.plots[0]
	# Level 2 of a 2-damage gun (+50%/level) = 3.0, then Overcharge +25%.
	assert_float(run.combat.plot_damage(plot)).is_equal_approx(3.75, 0.0001)


func test_a_mastery_can_speed_up_the_reload() -> void:
	var run := _maxed_run()
	run.build(0, &"gun")
	run.upgrade(0)
	var before: float = run.combat.plot_reload(run.plots[0])
	run.buy_mastery(0, 1)
	assert_float(run.combat.plot_reload(run.plots[0])).is_equal_approx(before / 2.0, 0.0001)


func test_selling_refunds_half_of_everything_spent() -> void:
	var run := _maxed_run()
	run.build(0, &"gun")
	run.upgrade(0)
	run.buy_mastery(0, 0)
	assert_int(run.sell_value(0)).is_equal(25)  # (10 + 10 + 30) / 2
	assert_int(run.sell(0)).is_equal(25)
	assert_int(run.gold).is_equal(50 + 25)
	assert_bool(run.plots[0].is_empty()).is_true()
	assert_object(run.plots[0].mastery).is_null()
	assert_int(run.sell(0)).is_equal(-1)
	assert_int(run.sell_value(0)).is_equal(-1)


func test_a_unit_built_mid_wave_needs_a_moment_to_set_up() -> void:
	var run := _maxed_run()
	run.build(0, &"gun")
	assert_float(run.plots[0].cooldown).is_equal(0.0)
	run.start_wave()
	run.build(1, &"gun")
	assert_float(run.plots[1].cooldown).is_equal(run.config.build_setup_time)


# --- the gate ------------------------------------------------------------------------------

func test_gate_repair_is_between_waves_only_and_needs_damage() -> void:
	var run := Run.new(_cfg(), 1)
	run.gold = 100
	assert_bool(run.repair_gate()).is_false()  # full HP
	run.wall_damage_taken = 40.0
	assert_bool(run.repair_gate()).is_true()
	assert_float(run.wall_hp()).is_equal(85.0)
	assert_int(run.gold).is_equal(100 - run.config.gate_repair_cost)
	run.start_wave()
	assert_bool(run.repair_gate()).is_false()


# --- the waves ------------------------------------------------------------------------------

func test_wave_counts_new_types_and_threat() -> void:
	var a := Fixtures.enemy(1, 1, 1, 1, false, &"a")
	var b := Fixtures.enemy(1, 1, 1, 1, false, &"b")
	b.threat = 5.0
	var w1 := Fixtures.wave([Fixtures.spawn(a, 3), Fixtures.spawn(a, 2)])
	var w2 := Fixtures.wave([Fixtures.spawn(a, 1), Fixtures.spawn(b, 2)])
	w2.hp_scale = 2.0
	assert_int(WaveSchedule.enemy_counts(w1)[a]).is_equal(5)
	var waves: Array[WaveDef] = [w1, w2]
	assert_array(WaveSchedule.new_enemies(waves, 0)).contains_exactly([a])
	assert_array(WaveSchedule.new_enemies(waves, 1)).contains_exactly([b])
	assert_float(WaveSchedule.threat(w2)).is_equal((1.0 + 2 * 5.0) * 2.0)
