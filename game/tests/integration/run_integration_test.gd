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


func test_zero_meta_is_not_a_stroll() -> void:
	# First-pass difficulty guard (B2 feedback: "not a stroll in the park"). The scripted bot
	# at zero meta must not win every run, and must get somewhere.
	var wins: int = 0
	var waves: Array[int] = []
	for s: int in range(1, 9):
		var run: Run = _play(s)["run"]
		wins += 1 if run.phase == Run.Phase.WON else 0
		waves.append(run.waves_cleared)
	prints("zero-meta bot, 8 seeds: waves cleared %s, wins %d" % [waves, wins])
	assert_int(wins).is_less(8)
	assert_int(waves.max()).is_greater_equal(3)


func test_the_canyon_is_harder_and_plays_to_the_end() -> void:
	# Sector 2: merged paths, flank breaches at waves 4 and 7. Its choke makes the early waves
	# gentler, so "harder" is measured where it bites: with a mid meta the bot wins fewer runs
	# there than on the Outpost. At zero meta it never wins, and every run ends (no stuck waves).
	var mid := RunModifiers.new()
	mid.wall_hp_bonus = 60
	mid.start_gold_bonus = 30
	mid.unit_cost_discount = 0.16
	mid.crate_reward_bonus = 0.2
	mid.unit_rate_bonus = 0.1
	var wins: Array[int] = [0, 0]
	var zero: Array[int] = []
	for s: int in range(1, 9):
		for map_index: int in 2:
			var run := Run.new(_config(map_index), s, mid)
			Autoplay.new().play(run)
			assert_bool(run.is_over()).is_true()
			wins[map_index] += 1 if run.phase == Run.Phase.WON else 0
		var z: Run = _play(s, Autoplay.new(), 1)["run"]
		assert_int(z.phase).is_equal(Run.Phase.LOST)
		zero.append(z.waves_cleared)
	prints("mid-meta wins over 8 seeds: outpost %d, canyon %d; canyon zero-meta %s" % [wins[0],
			wins[1], zero])
	assert_int(wins[1]).is_less_equal(wins[0])
