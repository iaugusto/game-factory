extends GdUnitTestSuite
## The balance bot's building blocks: every preset exists and differs where it should, and a
## BalanceRun record has every field the report reads (tools/src/gf_tools/balance/report.py).


func test_every_preset_builds_a_bot_and_unknown_names_do_not() -> void:
	for name: String in Autoplay.PRESETS:
		assert_object(Autoplay.preset(name)).override_failure_message(name).is_not_null()
	assert_object(Autoplay.preset("nope")).is_null()
	assert_int(Autoplay.preset("no_ability").ability_every_ticks).is_equal(0)
	assert_bool(Autoplay.preset("no_loot").chase_crates).is_false()
	assert_bool(Autoplay.preset("heavy").counter_pick).is_false()
	assert_float(Autoplay.preset("casual").taps_per_second) \
			.is_less(Autoplay.preset("smart").taps_per_second)


func test_profiles_give_the_tree_modifiers() -> void:
	var base: RunConfig = load("res://data/run_config.tres")
	assert_float(BalanceRun.profile_mods(base, "T0").wall_hp_bonus).is_equal(0.0)
	assert_float(BalanceRun.profile_mods(base, "T3").wall_hp_bonus).is_greater(0.0)


func test_a_record_has_every_field_the_report_reads() -> void:
	var cfg := Fixtures.config([Fixtures.wave([Fixtures.spawn(Fixtures.enemy(1, 100, 5), 3)])])
	cfg.units = [Fixtures.unit(&"rifleman")]
	cfg.start_gold = 50
	var rec: Dictionary = BalanceRun.play(cfg, RunModifiers.new(), 1, "smart", 60 * 60)
	for key: String in ["map", "strategy", "seed", "won", "waves", "gate", "ticks", "ability", "casts",
			"links", "unspent", "crates", "kills", "leaks", "units"]:
		assert_bool(rec.has(key)).override_failure_message("missing " + key).is_true()
	assert_str(String(rec["strategy"])).is_equal("smart")
