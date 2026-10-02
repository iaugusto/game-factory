extends GdUnitTestSuite


func test_stub_rewards_and_records() -> void:
	var s := StubServices.new()
	var got: Array[bool] = []
	assert_bool(s.is_rewarded_ad_ready(&"double_bricks")).is_true()
	s.show_rewarded_ad(&"double_bricks", func(ok: bool) -> void: got.append(ok))
	assert_array(got).is_equal([true])
	assert_str(String(s.calls[-1][0])).is_equal("show_rewarded_ad")


func test_stub_purchase_and_failure_path() -> void:
	var s := StubServices.new()
	var got: Array[bool] = []
	s.purchase(&"remove_ads", func(ok: bool) -> void: got.append(ok))
	assert_bool(s.owns(&"remove_ads")).is_true()
	s.succeed = false
	s.purchase(&"bundle", func(ok: bool) -> void: got.append(ok))
	assert_array(got).is_equal([true, false])
	assert_bool(s.owns(&"bundle")).is_false()


func test_stub_achievements_and_events() -> void:
	var s := StubServices.new()
	s.unlock_achievement(&"first_win")
	s.log_event(&"run_end", {"wave": 4})
	assert_bool(s.achievements.has(&"first_win")).is_true()
	assert_array(s.calls[-1][1]).is_equal([&"run_end", {"wave": 4}])


func test_base_class_fails_safe() -> void:
	var base := PlatformServices.new()
	var got: Array[bool] = []
	base.show_rewarded_ad(&"x", func(ok: bool) -> void: got.append(ok))
	base.purchase(&"x", func(ok: bool) -> void: got.append(ok))
	assert_array(got).is_equal([false, false])


func test_registry_defaults_to_stub_and_falls_back() -> void:
	var registry: Node = auto_free(load("res://src/platform/services_registry.gd").new())
	assert_str(registry.api.provider_name()).is_equal("stub")
	var fallback: Array[PlatformServices] = []
	await assert_error(func() -> void: fallback.append(registry.create("nope"))) \
			.is_push_error("Services: unknown provider 'nope', using stub")
	assert_str(fallback[0].provider_name()).is_equal("stub")


func test_launch_args_parse_splits_on_any_whitespace() -> void:
	var got: PackedStringArray = LaunchArgs.parse("--autoplay  --stress\n--perf\t--map=hive\n")
	assert_array(Array(got)).is_equal(["--autoplay", "--stress", "--perf", "--map=hive"])
	assert_array(Array(LaunchArgs.parse(""))).is_empty()


func test_launch_args_ignore_the_file_off_android() -> void:
	# Desktop (and tests) take the command line only, even if a launch_args.txt exists.
	var f := FileAccess.open(LaunchArgs.ANDROID_FILE, FileAccess.WRITE)
	f.store_string("--stress")
	f.close()
	var got: PackedStringArray = LaunchArgs.get_args()
	DirAccess.remove_absolute(LaunchArgs.ANDROID_FILE)
	assert_bool(Array(got).has("--stress")).is_false()
