extends GdUnitTestSuite
## Destroyable units, the Ravager, the Splitter, the Mender and elites
## (docs/2026-09-26-new-enemies-and-destroyable-units/). Fixture plots: 0 = (180, 700),
## 1 = (360, 700), 2 = (180, 300), 3 = (360, 300); paths down x = 90, 270, 450.


func _ravager(reach: float = 100.0, dmg: float = 10.0) -> EnemyDef:
	var e := Fixtures.enemy(1000, 200, 1, 0, false, &"ravager")
	e.unit_reach = reach
	e.unit_damage = dmg
	e.attack_interval = 0.5
	return e


func _run(spawns: Array[SpawnEntry]) -> Run:
	var cfg := Fixtures.config([Fixtures.wave(spawns)])
	cfg.units = [Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, PackedInt32Array([10]),
			0.0001, 100.0, 10.0)]
	cfg.units[0].hp = 50.0
	var run := Run.new(cfg, 1)
	run.gold = 1000
	return run


func test_a_ravager_mauls_the_unit_beside_its_path_then_walks_on() -> void:
	# Path 0 is x = 90; plot 2 (180, 300) is 90 away, within reach 100.
	var run := _run([Fixtures.spawn(_ravager(), 1, 0, 1, 0)])
	run.build(2, &"gun")
	run.start_wave()
	var destroyed: Array[int] = []
	run.combat.unit_destroyed.connect(func(p: CombatSim.Plot, _d: UnitDef) -> void: destroyed.append(p.index))
	var e: CombatSim.Enemy = null
	for i: int in 60 * 3:
		run.step()
		if not run.combat.path_enemies[0].is_empty():
			e = run.combat.path_enemies[0][0]
			if e.target_plot != null:
				break
	assert_object(e.target_plot).is_same(run.plots[2])
	assert_float(e.y).is_less(330.0)  # it stopped beside the pad
	for i: int in 60 * 3:
		run.step()
	assert_array(destroyed).is_equal([2])  # 50 HP / 10 per 0.5 s
	assert_bool(run.plots[2].is_empty()).is_true()
	assert_int(run.sell_value(2)).is_equal(-1)  # nothing to sell: no refund for a fallen unit
	assert_object(e.target_plot).is_null()
	assert_float(e.y).is_greater(400.0)  # and it walked on


func test_it_ignores_empty_and_far_pads_and_the_barricade_comes_first() -> void:
	var run := _run([Fixtures.spawn(_ravager(50.0), 1, 0, 1, 0)])
	run.build(2, &"gun")  # 90 away: out of reach 50
	run.start_wave()
	for i: int in 60 * 2:
		run.step()
	assert_float(run.plots[2].hp).is_equal(50.0)
	# The barricade on path 0 stops it before any unit near the wall.
	var run2 := _run([Fixtures.spawn(_ravager(), 1, 0, 1, 0)])
	run2.build(0, &"gun")  # (180, 700): 90 from the path, near the barricade at y 770
	run2.build_barricade(0)
	run2.start_wave()
	for i: int in 60 * 6:
		run2.step()
	var e: CombatSim.Enemy = run2.combat.path_enemies[0][0]
	assert_bool(e.at_barricade or e.target_plot == run2.plots[0]).is_true()


func test_repair_restores_a_damaged_unit_for_coins() -> void:
	var run := _run([])
	run.build(0, &"gun")
	var p: CombatSim.Plot = run.plots[0]
	assert_int(run.unit_repair_cost(0)).is_equal(-1)
	p.hp = 20.0
	var cost: int = run.unit_repair_cost(0)
	assert_int(cost).is_equal(ceili(30.0 * run.config.unit_repair_cost_per_hp))
	var gold: int = run.gold
	assert_bool(run.repair_unit(0)).is_true()
	assert_float(p.hp).is_equal(50.0)
	assert_int(run.gold).is_equal(gold - cost)


func test_an_upgrade_keeps_the_damage_taken() -> void:
	var run := _run([])
	run.build(0, &"gun")
	var p: CombatSim.Plot = run.plots[0]
	p.hp = 30.0
	run.upgrade(0)
	assert_float(p.max_hp).is_equal_approx(65.0, 0.001)  # 50 × 1.3
	assert_float(p.hp).is_equal_approx(45.0, 0.001)


func test_a_splitter_bursts_into_its_brood_where_it_fell() -> void:
	var brood := Fixtures.enemy(3, 10, 1, 0, false, &"brood")
	var splitter := Fixtures.enemy(5, 20, 1, 0, false, &"splitter")
	splitter.split_into = brood
	splitter.split_count = 3
	var run := _run([Fixtures.spawn(splitter, 1, 0, 1, 1), Fixtures.spawn(Fixtures.enemy(1000, 1, 1), 1, 0, 1, 1)])
	run.start_wave()
	for i: int in 60:
		run.step()
	var parent: CombatSim.Enemy = run.combat.path_enemies[1][0]
	var at: float = parent.d
	run.combat._damage_enemy(parent, 100.0, UnitDef.DamageType.KINETIC)
	var group: Array = run.combat.path_enemies[1]
	var kids: int = 0
	for k: int in group.size():
		var e: CombatSim.Enemy = group[k]
		if e.def == brood:
			kids += 1
			assert_float(e.d).is_between(at - 20.0, at)
		if k > 0:
			assert_float(e.d).is_less_equal((group[k - 1] as CombatSim.Enemy).d)  # still sorted
	assert_int(kids).is_equal(3)


func test_a_mender_heals_its_neighbours_but_not_itself() -> void:
	var mender := Fixtures.enemy(100, 0.001, 1, 0, false, &"mender")
	mender.heal_radius = 80.0
	mender.heal_per_second = 0.5
	var near := Fixtures.enemy(100, 0.001, 1, 0, false, &"near")
	var run := _run([Fixtures.spawn(mender, 1, 0, 1, 1), Fixtures.spawn(near, 1, 0, 1, 1),
			Fixtures.spawn(near, 1, 0, 1, 2)])
	run.start_wave()
	run.step()
	var m: CombatSim.Enemy = null
	var buddy: CombatSim.Enemy = null
	for e: CombatSim.Enemy in run.combat.path_enemies[1]:
		if e.def == mender:
			m = e
		else:
			buddy = e
	var far: CombatSim.Enemy = run.combat.path_enemies[2][0]  # 180 away
	m.hp = 50.0
	buddy.hp = 50.0
	far.hp = 50.0
	for i: int in 60:
		run.step()
	assert_float(buddy.hp).is_equal_approx(100.0, 1.0)
	assert_float(m.hp).is_equal(50.0)
	assert_float(far.hp).is_equal(50.0)


func test_elites_change_one_property() -> void:
	var armoured := EliteDef.new()
	armoured.hp_mult = 2.0
	armoured.armor_bonus = 3.0
	var swift := EliteDef.new()
	swift.speed_mult = 2.0
	swift.regen = 0.1
	var a := Fixtures.spawn(Fixtures.enemy(100, 10, 1), 1, 0, 1, 0)
	a.elite = armoured
	var b := Fixtures.spawn(Fixtures.enemy(100, 10, 1), 1, 0, 1, 2)
	b.elite = swift
	var run := _run([a, b])
	run.start_wave()
	run.step()
	var ea: CombatSim.Enemy = run.combat.path_enemies[0][0]
	var eb: CombatSim.Enemy = run.combat.path_enemies[2][0]
	assert_float(ea.max_hp).is_equal(200.0)
	assert_float(eb.speed).is_equal(20.0)
	run.combat._damage_enemy(ea, 10.0, UnitDef.DamageType.KINETIC)
	assert_float(ea.hp).is_equal(193.0)  # 10 - 3 armour
	eb.hp = 50.0
	for i: int in 60:
		run.step()
	assert_float(eb.hp).is_equal_approx(60.0, 0.5)  # +10% of 100 a second
