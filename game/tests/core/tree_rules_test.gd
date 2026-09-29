extends GdUnitTestSuite
## The skill-tree nodes that are rules rather than plain bonuses
## (docs/2026-09-27-sectors-and-skill-tree/): Last Stand, Iron Gate, Veteran Crews, Reinforced
## Pads, Field Barricade, Masons, Overwatch, Supply Drop, Fourth Card, and +10% loot.
## Fixture plots: 0 = (180, 700), 1 = (360, 700), 2 = (180, 300), 3 = (360, 300); paths down
## x = 90, 270, 450.


func _mods(key: StringName, value: float) -> RunModifiers:
	var m := RunModifiers.new()
	m.add(key, value)
	return m


func _cfg(spawns: Array[SpawnEntry] = []) -> RunConfig:
	var cfg := Fixtures.config([Fixtures.wave(spawns), Fixtures.wave(spawns)])
	var gun := Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, PackedInt32Array([10, 10]),
			0.0001, 100.0, 10.0)
	gun.hp = 50.0
	gun.mastery_cost = 40
	gun.masteries = [MasteryDef.new()]
	cfg.units = [gun]
	return cfg


func _ravager() -> EnemyDef:
	var e := Fixtures.enemy(1000, 200, 1, 0, false, &"ravager")
	e.unit_reach = 100.0
	e.unit_damage = 100.0
	e.attack_interval = 0.5
	return e


func test_last_stand_a_fallen_unit_blasts_enemies_near_its_pad() -> void:
	# A Ravager (1000 HP) mauls the level-2 gun on plot 2 from ~100 away until it falls; the
	# blast (25 × level 2 = 50, explosive, radius 100 here) hits it.
	var cfg := _cfg([Fixtures.spawn(_ravager(), 1, 0, 1, 0)])
	cfg.death_blast_radius = 100.0
	var run := Run.new(cfg, 1, _mods(&"death_blast", 25.0))
	run.gold = 1000
	run.build(2, &"gun")
	run.upgrade(2)
	var blasts: Array[Vector2] = []
	run.combat.unit_blast.connect(func(p: Vector2, _r: float) -> void: blasts.append(p))
	run.start_wave()
	for i: int in 60 * 3:
		run.step()
		if run.plots[2].is_empty():
			break  # the blast, queued in the move pass, resolved in the same step
	assert_bool(run.plots[2].is_empty()).is_true()
	assert_int(blasts.size()).is_equal(1)
	var e: CombatSim.Enemy = run.combat.path_enemies[0][0]
	assert_float(e.hp).is_equal_approx(1000.0 - 50.0, 1e-3)


func test_without_last_stand_there_is_no_blast() -> void:
	var run := Run.new(_cfg([Fixtures.spawn(_ravager(), 1, 0, 1, 0)]), 1)
	run.gold = 1000
	run.build(2, &"gun")
	run.start_wave()
	for i: int in 60 * 3:
		run.step()
	assert_bool(run.plots[2].is_empty()).is_true()
	assert_float(run.combat.path_enemies[0][0].hp).is_equal(1000.0)


func test_iron_gate_bites_back_at_its_attackers() -> void:
	# An enemy (50 HP, strikes every 1 s) pounds the gate; thorns deal 5/s → 5 per strike.
	var e := Fixtures.enemy(50, 400, 1)
	e.attack_interval = 1.0
	var run := Run.new(_cfg([Fixtures.spawn(e, 1, 0, 1, 0)]), 1, _mods(&"gate_thorns", 5.0))
	run.start_wave()
	for i: int in 60 * 5:
		run.step()
	var besieger: CombatSim.Enemy = run.combat.path_enemies[0][0]
	assert_bool(besieger.sieging).is_true()
	var strikes: int = roundi(run.wall_damage_taken)
	assert_float(besieger.hp).is_equal_approx(50.0 - 5.0 * strikes, 1e-3)
	# Thorns kill it eventually, and the kill pays like any other.
	for i: int in 60 * 12:
		run.step()
	assert_int(run.combat.kills).is_equal(1)


func test_veteran_crews_arrive_levels_up_for_the_level_one_price() -> void:
	var run := Run.new(_cfg(), 1, _mods(&"veteran_level", 1.0))
	run.gold = 100
	assert_bool(run.build(0, &"gun")).is_true()
	assert_int(run.plots[0].level).is_equal(2)
	assert_int(run.gold).is_equal(90)
	assert_int(run.plots[0].spent).is_equal(10)
	assert_float(run.plots[0].max_hp).is_equal(run.config.units[0].hp_at(2))
	# Never past max level (3 here).
	var big := Run.new(_cfg(), 1, _mods(&"veteran_level", 5.0))
	big.gold = 100
	big.build(0, &"gun")
	assert_int(big.plots[0].level).is_equal(3)


func test_reinforced_pads_raise_unit_hp_on_build_and_upgrade() -> void:
	var run := Run.new(_cfg(), 1, _mods(&"unit_hp_bonus", 0.3))
	run.gold = 100
	run.build(0, &"gun")
	var gun: UnitDef = run.config.units[0]
	assert_float(run.plots[0].max_hp).is_equal_approx(gun.hp_at(1) * 1.3, 1e-4)
	run.upgrade(0)
	assert_float(run.plots[0].max_hp).is_equal_approx(gun.hp_at(2) * 1.3, 1e-4)
	assert_float(run.plots[0].hp).is_equal_approx(run.plots[0].max_hp, 1e-4)


func test_field_barricade_stands_from_the_start() -> void:
	var run := Run.new(_cfg(), 1, _mods(&"start_barricade", 1.0))
	var b: CombatSim.Barricade = run.barricade()
	assert_bool(b.is_standing()).is_true()
	assert_int(b.level).is_equal(1)
	assert_int(b.slot).is_equal(0)
	assert_bool(b.blocks(0)).is_true()
	# It's the one barricade: moving it is free, building a second isn't a thing.
	assert_bool(run.build_barricade(1)).is_true()
	assert_int(run.gold).is_equal(0)
	assert_bool(Run.new(_cfg(), 1).barricade().is_built()).is_false()


func test_masons_heal_more_per_gate_repair() -> void:
	var run := Run.new(_cfg(), 1, _mods(&"gate_repair_bonus", 0.5))
	run.gold = 100
	run.wall_damage_taken = 60.0
	assert_bool(run.repair_gate()).is_true()
	assert_float(run.wall_damage_taken).is_equal_approx(60.0 - run.config.gate_repair_hp * 1.5,
			1e-4)


func test_overwatch_halves_mastery_prices() -> void:
	var run := Run.new(_cfg(), 1, _mods(&"mastery_discount", 0.5))
	run.gold = 1000
	run.build(0, &"gun")
	run.upgrade(0)
	run.upgrade(0)
	assert_int(run.mastery_cost(0)).is_equal(20)


func test_fourth_card_and_supply_drop_reroll() -> void:
	var cards: Array[CardDef] = []
	for i: int in 8:
		cards.append(Fixtures.card(StringName("c%d" % i), &"gold_bonus", 0.1))
	var mods := _mods(&"extra_cards", 1.0)
	mods.add(&"card_rerolls", 1.0)
	var cfg := _cfg()
	cfg.cards = cards
	var run := Run.new(cfg, 1, mods)
	Fixtures.sentinel(run)
	Fixtures.run_wave(run)
	assert_int(run.phase).is_equal(Run.Phase.CARD)
	assert_int(run.card_offer.size()).is_equal(4)
	assert_int(run.rerolls_left).is_equal(1)
	var first: Array[CardDef] = run.card_offer.duplicate()
	assert_bool(run.reroll_cards()).is_true()
	assert_int(run.card_offer.size()).is_equal(4)
	for c: CardDef in run.card_offer:
		assert_bool(first.has(c)).override_failure_message("reroll repeated %s" % c.id).is_false()
	assert_bool(run.reroll_cards()).is_false()  # one per offer
	assert_bool(run.pick_card(3)).is_true()


func test_loot_raises_crate_and_kill_coins() -> void:
	var mods := _mods(&"loot_bonus", 0.1)
	assert_int(Economy.crate_reward(Fixtures.crate(5.0, 20), mods)).is_equal(22)
	assert_int(Economy.kill_reward(Fixtures.enemy(3, 100, 5, 10), mods)).is_equal(11)
