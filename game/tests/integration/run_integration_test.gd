extends GdUnitTestSuite
## Whole-run behaviour on the real content, headless, driven by Autoplay.

const CONFIG_PATH: String = "res://data/run_config.tres"


## The run config for map `index` of RunConfig.maps.
func _config(index: int = 0) -> RunConfig:
	var base: RunConfig = load(CONFIG_PATH)
	return base.for_map(base.maps[index])


func _play(run_seed: int, bot: Autoplay = Autoplay.new(), map_index: int = 0) -> Dictionary:
	var cfg: RunConfig = _config(map_index)
	var run := Run.new(cfg, run_seed)
	var peak_shots: int = 0
	var t0: int = Time.get_ticks_msec()
	while not run.is_over() and run.ticks < 60 * 60 * 30:
		match run.phase:
			Run.Phase.WAVE:
				bot.step_wave(run)
				peak_shots = maxi(peak_shots, run.combat.shots.size())
			Run.Phase.BUILD:
				bot.play_build(run)
				run.start_wave()
			Run.Phase.CARD:
				run.pick_card(0)
	return {"run": run, "hash": run.state_hash(), "peak_shots": peak_shots,
			"ms": Time.get_ticks_msec() - t0}


func test_autoplay_clears_wave_one_and_breaks_crates() -> void:
	var run := Run.new(_config(), 1)
	var bot := Autoplay.new()
	bot.play_build(run)
	run.start_wave()
	while run.phase == Run.Phase.WAVE:
		bot.step_wave(run)
	assert_int(run.waves_cleared).is_equal(1)
	assert_int(run.combat.crates_broken).is_greater(0)
	assert_int(run.gold).is_greater(0)


func test_full_run_is_deterministic() -> void:
	var a: Dictionary = _play(11)
	var b: Dictionary = _play(11)
	var run: Run = a["run"]
	assert_bool(run.is_over()).is_true()
	assert_str(a["hash"]).is_equal(b["hash"])
	assert_int(run.ticks).is_equal((b["run"] as Run).ticks)
	prints("full headless run: %d ticks (%.0f s of play) in %d ms; peak shots %d; %s at wave %d"
			% [run.ticks, run.ticks / 60.0, a["ms"], a["peak_shots"],
			Run.Phase.keys()[run.phase], run.waves_cleared])


func test_different_seeds_diverge() -> void:
	assert_str(_play(1)["hash"]).is_not_equal(_play(2)["hash"])


func test_shots_stay_inside_the_budget() -> void:
	# Plan §3 budgeted ≤600 projectiles on screen; with the squad gone only units fire, a few
	# shots in flight per plot at most.
	assert_int(_play(3)["peak_shots"]).is_less_equal(20 * _config().plot_count())


## Bot wins over seeds 1..8 on map `map_index` with tree profile `profile`; every run must end.
func _wins(map_index: int, profile: String) -> int:
	var mods: RunModifiers = BalanceRun.profile_mods(load(CONFIG_PATH), profile)
	var wins: int = 0
	for s: int in range(1, 9):
		var run := Run.new(_config(map_index), s, mods)
		Autoplay.new().play(run)
		assert_bool(run.is_over()).is_true()
		wins += 1 if run.phase == Run.Phase.WON else 0
	return wins


func test_the_campaign_curve() -> void:
	# The difficulty curve against the skill tree. Sector 1 is winnable with no tree but no
	# stroll; sector 2 needs the stars sector 1 gives; sector 3 needs more; and on one map more
	# tree never wins less.
	var outpost_t0: int = _wins(0, "T0")
	var canyon: Array[int] = [_wins(1, "T0"), _wins(1, "T3"), _wins(1, "T6")]
	var switchback: Array[int] = [_wins(2, "T0"), _wins(2, "T6")]
	prints("campaign curve, bot wins of 8: outpost T0 %d | canyon T0/T3/T6 %s | switchback T0/T6 %s"
			% [outpost_t0, canyon, switchback])
	assert_int(outpost_t0).is_between(1, 7)
	assert_int(canyon[0]).is_less_equal(1)
	assert_int(canyon[1]).is_greater_equal(1)
	assert_bool(canyon[0] <= canyon[1] and canyon[1] <= canyon[2]).is_true()
	assert_int(switchback[0]).is_less_equal(mini(1, outpost_t0))
	assert_int(switchback[1]).is_greater_equal(maxi(1, switchback[0]))
