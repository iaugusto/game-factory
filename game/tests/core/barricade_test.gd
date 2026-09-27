extends GdUnitTestSuite
## The barricade: one, on a slot in front of the wall; enemies on the paths through it stop and
## strike it until it breaks, then walk on. Fixture slots: 0 = (90, 770), 1 = (270, 770), 2 = (450, 770).


func _run(spawns: Array[SpawnEntry] = []) -> Run:
	var run := Run.new(Fixtures.config([Fixtures.wave(spawns)]), 1)
	run.gold = 1000
	return run


func test_one_barricade_built_upgraded_and_priced() -> void:
	var run := _run()
	var def: BarricadeDef = run.config.barricade
	assert_int(run.barricade_cost()).is_equal(def.costs[0])
	assert_bool(run.build_barricade(1)).is_true()
	var b: CombatSim.Barricade = run.barricade()
	assert_int(b.level).is_equal(1)
	assert_float(b.hp).is_equal(def.hp_at(1))
	assert_bool(b.blocks(1)).is_true()
	assert_bool(b.blocks(0) or b.blocks(2)).is_false()
	assert_int(run.barricade_cost()).is_equal(def.costs[1])
	assert_bool(run.upgrade_barricade()).is_true()
	assert_bool(run.upgrade_barricade()).is_true()
	assert_float(b.hp).is_equal(def.hp_at(3))
	assert_int(run.barricade_cost()).is_equal(-1)
	assert_bool(run.upgrade_barricade()).is_false()
	assert_int(run.gold).is_equal(1000 - def.costs[0] - def.costs[1] - def.costs[2])


func test_it_moves_between_waves_only_keeping_level_and_hp() -> void:
	var run := _run([Fixtures.spawn(Fixtures.enemy(1, 1, 1), 1, 600, 1, 0)])
	run.build_barricade(0)
	run.upgrade_barricade()
	run.barricade().hp = 50.0
	var gold: int = run.gold
	assert_bool(run.build_barricade(2)).is_true()  # a move, free
	assert_int(run.gold).is_equal(gold)
	assert_bool(run.barricade().blocks(2)).is_true()
	assert_bool(run.barricade().blocks(0)).is_false()
	assert_int(run.barricade().level).is_equal(2)
	assert_float(run.barricade().hp).is_equal(50.0)
	run.start_wave()
	assert_bool(run.build_barricade(1)).is_false()  # no moving mid-wave
	assert_int(run.barricade().slot).is_equal(2)


func test_it_stops_its_path_only_and_takes_the_strikes() -> void:
	var tank := Fixtures.enemy(1000, 200, 10)
	var run := _run([Fixtures.spawn(tank, 1, 0, 1, 1), Fixtures.spawn(tank, 1, 0, 1, 2)])
	run.build_barricade(1)
	run.start_wave()
	var struck: Array[float] = []
	run.combat.barricade_struck.connect(func(_e: CombatSim.Enemy, d: float) -> void: struck.append(d))
	for i: int in 60 * 5:
		run.step()
	var blocked: CombatSim.Enemy = run.combat.path_enemies[1][0]
	var free: CombatSim.Enemy = run.combat.path_enemies[2][0]
	assert_bool(blocked.at_barricade).is_true()
	assert_float(blocked.y).is_less(770.0)
	assert_bool(free.sieging and not free.at_barricade).is_true()  # path 2 reached the gate
	assert_int(struck.size()).is_greater(0)
	assert_float(run.barricade().hp).is_equal(60.0 - 10.0 * struck.size())


func test_when_it_breaks_they_walk_on_and_repair_restores_it() -> void:
	var run := _run([Fixtures.spawn(Fixtures.enemy(1000, 200, 30), 1, 0, 1, 1)])
	run.build_barricade(1)
	run.start_wave()
	var broke: Array[bool] = []
	run.combat.barricade_broken.connect(func() -> void: broke.append(true))
	for i: int in 60 * 6:
		run.step()
	assert_int(broke.size()).is_equal(1)
	assert_bool(run.barricade().is_standing()).is_false()
	var e: CombatSim.Enemy = run.combat.path_enemies[1][0]
	assert_bool(e.at_barricade).is_false()
	assert_float(e.y).is_equal(run.config.wall_y)  # it went on to the gate
	var cost: int = run.barricade_repair_cost()
	assert_int(cost).is_equal(ceili(60.0 * run.config.barricade.repair_cost_per_hp))
	var gold: int = run.gold
	assert_bool(run.repair_barricade()).is_true()
	assert_int(run.gold).is_equal(gold - cost)
	assert_bool(run.barricade().is_standing()).is_true()
	assert_int(run.barricade_repair_cost()).is_equal(-1)


func test_small_enemies_bunch_up_behind_a_big_one() -> void:
	# A slow big enemy leads; a fast small one spawns behind it on the same path (no jitter,
	# so they overlap in x): it can't walk through, it trails.
	var big := Fixtures.enemy(1000, 20, 1)
	big.radius = 20.0
	var small := Fixtures.enemy(1000, 200, 1)
	var run := _run([Fixtures.spawn(big, 1, 0, 1, 0), Fixtures.spawn(small, 1, 0.5, 1, 0)])
	run.start_wave()
	for i: int in 60 * 4:
		run.step()
	var group: Array = run.combat.path_enemies[0]
	assert_object((group[0] as CombatSim.Enemy).def).is_same(big)
	assert_float((group[1] as CombatSim.Enemy).y).is_less((group[0] as CombatSim.Enemy).y)


func test_a_beam_hits_at_most_its_target_count() -> void:
	var run := _run([Fixtures.spawn(Fixtures.enemy(100, 5, 5), 5, 0, 0.0, 0)])
	run.start_wave()
	var rail := Fixtures.unit(&"rail", UnitDef.Attack.BEAM, 10, [], 10.0, 100.0)
	rail.beam_max_targets = 3
	Fixtures.place(run, 0, rail)
	run.step()
	var hit: int = 0
	for e: CombatSim.Enemy in run.combat.path_enemies[0]:
		hit += 1 if e.hp < 100.0 else 0
	assert_int(hit).is_equal(3)
