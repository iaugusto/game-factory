extends GdUnitTestSuite
## The run's flow and spending rules: BUILD (prep) → WAVE → CARD → BUILD … → WON/LOST, and
## building and upgrading in BUILD and mid-WAVE.


func _two_wave_config(cards: Array[CardDef] = []) -> RunConfig:
	# Each wave's lone enemy pays 20 and is shot on spawn by the sentinel (_new_run).
	var e := Fixtures.enemy(1, 200, 1, 20)
	var cfg := Fixtures.config([
		Fixtures.wave([Fixtures.spawn(e, 1, 0, 1, 1)]),
		Fixtures.wave([Fixtures.spawn(e, 1, 0, 1, 1)]),
	])
	cfg.units = [Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, PackedInt32Array([8]))]
	cfg.cards = cards
	return cfg


## A run on `cfg` with the sentinel on the wall spot, so every wave ends.
func _new_run(cfg: RunConfig, meta: RunModifiers = null) -> Run:
	var run := Run.new(cfg, 1, meta)
	Fixtures.sentinel(run)
	return run


func test_run_opens_in_build_and_start_wave_begins_it() -> void:
	var run := _new_run(_two_wave_config())
	assert_int(run.phase).is_equal(Run.Phase.BUILD)
	assert_int(run.wave_index).is_equal(0)
	run.step()
	assert_int(run.ticks).is_equal(0)  # step() does nothing outside WAVE
	assert_bool(run.start_wave()).is_true()
	assert_int(run.phase).is_equal(Run.Phase.WAVE)
	assert_bool(run.start_wave()).is_false()


func test_wave_clear_without_cards_goes_to_build_for_the_next_wave() -> void:
	var run := _new_run(_two_wave_config())
	Fixtures.run_wave(run)
	assert_int(run.phase).is_equal(Run.Phase.BUILD)
	assert_int(run.waves_cleared).is_equal(1)
	assert_int(run.wave_index).is_equal(1)
	assert_int(run.gold).is_equal(20)
	assert_float(run.wall_hp()).is_equal(100.0)


func test_build_and_upgrade_rules() -> void:
	var run := _new_run(_two_wave_config())
	assert_bool(run.build(0, &"gun")).is_false()  # no coins yet
	Fixtures.run_wave(run)
	run.gold = 20
	assert_bool(run.build(0, &"nope")).is_false()
	assert_bool(run.build(9, &"gun")).is_false()
	assert_bool(run.build(0, &"gun")).is_true()
	assert_int(run.gold).is_equal(10)
	assert_bool(run.build(0, &"gun")).is_false()  # occupied
	assert_bool(run.upgrade(0)).is_true()
	assert_int(run.gold).is_equal(2)
	assert_int(run.plots[0].level).is_equal(2)
	assert_bool(run.upgrade(0)).is_false()  # maxed
	assert_bool(run.upgrade(1)).is_false()  # empty
	assert_bool(run.build(Fixtures.WALL_SPOT, &"gun")).is_false()  # the sentinel is there


func test_building_works_mid_wave_but_not_during_cards() -> void:
	var card := Fixtures.card(&"wall", &"wall_hp_bonus", 25)
	var run := _new_run(_two_wave_config([card]))
	run.gold = 50
	run.start_wave()
	assert_bool(run.build(1, &"gun")).is_true()
	assert_bool(run.upgrade(1)).is_true()
	Fixtures.run_wave(run)
	assert_int(run.phase).is_equal(Run.Phase.CARD)
	assert_bool(run.build(2, &"gun")).is_false()
	run.gold = 50
	assert_bool(run.build(2, &"gun")).is_false()


func test_card_pick_applies_and_returns_to_build() -> void:
	var card := Fixtures.card(&"wall", &"wall_hp_bonus", 25)
	var run := _new_run(_two_wave_config([card]))
	Fixtures.run_wave(run)
	assert_int(run.phase).is_equal(Run.Phase.CARD)
	assert_int(run.card_offer.size()).is_equal(1)
	assert_bool(run.pick_card(0)).is_true()
	assert_float(run.wall_hp()).is_equal(125.0)
	assert_int(run.cards_taken[&"wall"]).is_equal(1)
	assert_int(run.phase).is_equal(Run.Phase.BUILD)
	assert_int(run.wave_index).is_equal(1)


func test_last_wave_clear_wins_with_the_gate_intact() -> void:
	var run := _new_run(_two_wave_config())
	Fixtures.run_wave(run)
	Fixtures.run_wave(run)
	assert_int(run.phase).is_equal(Run.Phase.WON)
	assert_float(run.gate_fraction()).is_equal(1.0)


func test_wall_breaks_and_run_is_lost() -> void:
	var cfg := Fixtures.config([Fixtures.wave([Fixtures.spawn(Fixtures.enemy(3, 200, 5), 1, 0, 1, 0)])],
			4.0)
	var run := Run.new(cfg, 1)
	Fixtures.run_wave(run)
	assert_int(run.phase).is_equal(Run.Phase.LOST)
	assert_float(run.gate_fraction()).is_equal(0.0)


func test_wall_regenerates() -> void:
	var mods := RunModifiers.new()
	mods.wall_regen = 10.0
	var striker := Fixtures.enemy(3, 200, 5)
	striker.attack_interval = 1000.0  # one strike, then a long pause
	var cfg := Fixtures.config([Fixtures.wave([
		Fixtures.spawn(striker, 1, 0, 1, 0),
		Fixtures.spawn(Fixtures.enemy(3, 10, 5), 1, 0, 1, 2),
	])])
	var run := Run.new(cfg, 1, mods)
	run.start_wave()
	while run.combat.kills == 0 and run.wall_hp() == 100.0 and run.ticks < 600:
		run.step()
	for i: int in 60:
		run.step()
	assert_float(run.wall_hp()).is_equal(100.0)


func test_meta_modifiers_shape_the_start_but_are_not_mutated() -> void:
	var meta := RunModifiers.new()
	meta.wall_hp_bonus = 30
	meta.start_gold_bonus = 7
	var run := _new_run(_two_wave_config([Fixtures.card(&"g", &"gold_bonus", 1.0)]), meta)
	assert_float(run.wall_max()).is_equal(130.0)
	assert_int(run.gold).is_equal(7)
	Fixtures.run_wave(run)
	run.pick_card(0)
	assert_float(meta.gold_bonus).is_equal(0.0)


func test_plots_come_from_the_map() -> void:
	var run := _new_run(_two_wave_config())
	assert_int(run.plots.size()).is_equal(Fixtures.PLOTS.size())
	assert_vector(run.plots[2].position).is_equal(Fixtures.PLOTS[2])
	assert_bool(run.plots[0].is_empty()).is_true()


func test_state_hash_tracks_progress() -> void:
	var run := _new_run(_two_wave_config())
	run.start_wave()
	var before: String = run.state_hash()
	run.step()
	assert_str(run.state_hash()).is_not_equal(before)
