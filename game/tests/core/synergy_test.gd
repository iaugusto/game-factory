extends GdUnitTestSuite
## Unit links (Synergies): found in either order, only in range, each distinct synergy once
## per unit, recomputed on build, sell and destruction, and every bonus field applied.
## Fixture plots: 0 = (180, 700), 1 = (360, 700) (180 apart), 2 = (180, 300) (400 from 0).


func _bonus(fields: Dictionary) -> StatBonus:
	var b := StatBonus.new()
	for k: String in fields:
		b.set(k, fields[k])
	return b


func _syn(id: StringName, a: StringName, b: StringName, ba: Dictionary,
		bb: Dictionary = {}) -> SynergyDef:
	var s := SynergyDef.new()
	s.id = id
	s.title = String(id)
	s.unit_a = a
	s.unit_b = b
	s.bonus_a = _bonus(ba)
	s.bonus_b = _bonus(bb) if a != b else s.bonus_a
	return s


func _run(synergies: Array[SynergyDef], units: Array[UnitDef]) -> Run:
	var cfg := Fixtures.config([Fixtures.wave([Fixtures.spawn(Fixtures.enemy(1, 1, 0), 1,
			600.0)])])
	cfg.synergy_range = 200.0
	cfg.synergies = synergies
	cfg.units = units
	cfg.start_gold = 1000
	return Run.new(cfg, 1)


func test_pairs_are_found_in_either_order() -> void:
	var cfg := RunConfig.new()
	var s := _syn(&"x", &"gun", &"cannon", {"damage": 0.1})
	cfg.synergies = [s]
	assert_object(Synergies.find(cfg, &"gun", &"cannon")).is_same(s)
	assert_object(Synergies.find(cfg, &"cannon", &"gun")).is_same(s)
	assert_object(Synergies.find(cfg, &"gun", &"gun")).is_null()


func test_units_in_range_link_and_far_ones_do_not() -> void:
	var gun := Fixtures.unit(&"gun")
	var cannon := Fixtures.unit(&"cannon")
	var run := _run([_syn(&"pair", &"gun", &"cannon", {"damage": 0.2}, {"reach": 0.5})],
			[gun, cannon])
	assert_bool(run.build(0, &"gun")).is_true()
	assert_bool(run.build(2, &"cannon")).is_true()  # 400 away: no link
	assert_bool(run.plots[0].links.is_empty()).is_true()
	assert_bool(run.build(1, &"cannon")).is_true()  # 180 away: a link
	assert_int(run.plots[0].links.size()).is_equal(1)
	assert_int(run.plots[1].links.size()).is_equal(1)
	assert_float(run.combat.plot_damage(run.plots[0])).is_equal_approx(1.2, 1e-5)
	assert_float(run.combat.plot_reach(run.plots[1])).is_equal_approx(1500.0, 1e-3)
	assert_float(run.plots[2].syn.reach).is_equal(0.0)


func test_a_synergy_counts_once_per_unit_however_many_partners() -> void:
	var gun := Fixtures.unit(&"gun")
	var run := _run([_syn(&"twins", &"gun", &"gun", {"damage": 0.1})], [gun])
	run.config.synergy_range = 1000.0
	for i: int in 4:
		run.build(i, &"gun")
	assert_int(run.plots[0].links.size()).is_equal(3)
	assert_float(run.plots[0].syn.damage).is_equal_approx(0.1, 1e-6)


func test_links_go_away_on_sell_and_destruction() -> void:
	var gun := Fixtures.unit(&"gun")
	var run := _run([_syn(&"twins", &"gun", &"gun", {"reload": 0.5})], [gun])
	run.build(0, &"gun")
	run.build(1, &"gun")
	assert_float(run.combat.plot_reload(run.plots[0])).is_equal_approx(1.0 / 1.5, 1e-5)
	run.sell(1)
	assert_bool(run.plots[0].links.is_empty()).is_true()
	assert_float(run.combat.plot_reload(run.plots[0])).is_equal_approx(1.0, 1e-5)
	run.build(1, &"gun")
	run.combat.destroy_unit(run.plots[1])
	assert_float(run.plots[0].syn.reload).is_equal(0.0)


func test_preview_lists_what_a_build_would_form() -> void:
	var gun := Fixtures.unit(&"gun")
	var cannon := Fixtures.unit(&"cannon")
	var run := _run([_syn(&"pair", &"gun", &"cannon", {"damage": 0.2})], [gun, cannon])
	run.build(0, &"gun")
	assert_int(Synergies.preview(run.plots, run.config, 1, &"cannon").size()).is_equal(1)
	assert_int(Synergies.preview(run.plots, run.config, 1, &"gun").size()).is_equal(0)
	assert_int(Synergies.preview(run.plots, run.config, 2, &"cannon").size()).is_equal(0)


func test_shot_bonuses_reach_the_shots() -> void:
	# Splash, slow, chill and beam targets go into what a unit fires.
	var mortar := Fixtures.unit(&"mortar", UnitDef.Attack.SHELL)
	mortar.splash_radius = 40.0
	mortar.projectile_speed = 200.0
	var rifle := Fixtures.unit(&"rifle", UnitDef.Attack.BULLET)
	rifle.projectile_speed = 200.0
	var s := _syn(&"pair", &"mortar", &"rifle", {"splash": 0.5}, {"chill": 0.7, "chill_time": 2.0})
	var run := _run([s], [mortar, rifle])
	run.build(0, &"mortar")
	run.build(1, &"rifle")
	run.start_wave()
	var e := CombatSim.Enemy.new()
	e.def = Fixtures.enemy(100, 1, 0)
	e.hp = 100
	e.max_hp = 100
	e.alive = true
	run.combat._fire_plot(run.plots[0], e)
	run.combat._fire_plot(run.plots[1], e)
	assert_float(run.combat.shots[0].splash).is_equal_approx(60.0, 1e-4)
	assert_float(run.combat.shots[1].slow).is_equal_approx(0.7, 1e-6)
	assert_float(run.combat.shots[1].slow_time).is_equal_approx(2.0, 1e-6)


func test_beam_targets_and_armour_pierce_apply() -> void:
	var rail := Fixtures.unit(&"rail", UnitDef.Attack.BEAM)
	rail.beam_max_targets = 1
	var sniper := Fixtures.unit(&"sniper", UnitDef.Attack.HITSCAN, 10, [], 10.0)
	var s := _syn(&"pair", &"rail", &"sniper", {"beam_targets": 2}, {"pierce": 1.0})
	var run := _run([s], [rail, sniper])
	run.build(0, &"rail")
	run.build(1, &"sniper")
	run.start_wave()
	# Three enemies on the first path, in reach of the beam; an armoured one for the sniper.
	var hit: Array[CombatSim.Enemy] = []
	for i: int in 3:
		var e := CombatSim.Enemy.new()
		e.def = Fixtures.enemy(100, 1, 0)
		e.hp = 100
		e.max_hp = 100
		e.path = 0
		e.d = 500.0 - i * 10.0
		e.x = 90.0
		e.y = e.d
		run.combat.path_enemies[0].append(e)
		hit.append(e)
	run.combat._fire_plot(run.plots[0], hit[0])
	var damaged: int = 0
	for e: CombatSim.Enemy in hit:
		damaged += 1 if e.hp < 100 else 0
	assert_int(damaged).is_equal(3)
	var armoured := CombatSim.Enemy.new()
	armoured.def = Fixtures.enemy(100, 1, 0)
	armoured.def.armor = 5.0
	armoured.hp = 100
	armoured.max_hp = 100
	run.combat._fire_plot(run.plots[1], armoured)
	assert_float(armoured.hp).is_equal_approx(90.0, 1e-4)  # full 10, armour ignored
