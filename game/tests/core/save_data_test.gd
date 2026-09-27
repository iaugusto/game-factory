extends GdUnitTestSuite


func after_test() -> void:
	clean_temp_dir()


func _sample() -> SaveData:
	var s := SaveData.new()
	s.meta.bricks = 42
	s.meta.levels = {&"drill": 2, &"salvage": 1}
	s.record_run(7, false, 3)
	return s


func test_dict_round_trip() -> void:
	var back := SaveData.from_dict(_sample().to_dict())
	assert_int(back.meta.bricks).is_equal(45)
	assert_int(back.meta.levels[&"drill"]).is_equal(2)
	assert_int(back.runs).is_equal(1)
	assert_int(back.best_wave).is_equal(7)


func test_file_round_trip_is_atomic() -> void:
	var path: String = create_temp_dir("save") + "/save.json"
	assert_int(_sample().save_to(path)).is_equal(OK)
	assert_bool(FileAccess.file_exists(path + ".tmp")).is_false()
	var back := SaveData.load_from(path)
	assert_str(back.load_warning).is_empty()
	assert_int(back.meta.bricks).is_equal(45)


func test_v1_migrates_to_v2() -> void:
	var v1: Dictionary = {"version": 1, "bricks": 30, "meta": {"salvage": 3}}
	var s := SaveData.from_dict(v1)
	assert_object(s).is_not_null()
	assert_int(s.meta.bricks).is_equal(30)
	assert_int(s.meta.levels[&"salvage"]).is_equal(3)
	assert_int(s.runs).is_equal(0)
	assert_int(int(SaveData.migrate(v1)["version"])).is_equal(SaveData.CURRENT_VERSION)


func test_v2_refunds_removed_gate_era_upgrades_in_v3() -> void:
	var v2: Dictionary = {"version": 2,
			"meta": {"bricks": 5, "levels": {"recruits": 1, "gate_lore": 2, "fifth_slot": 1}},
			"stats": {"runs": 4, "wins": 1, "best_wave": 9}}
	var s := SaveData.from_dict(v2)
	assert_object(s).is_not_null()
	# v3 refunds the gate upgrades; v4 then refunds "recruits" (level 1 cost 5).
	assert_int(s.meta.bricks).is_equal(5 + 15 + 35 + 60 + 5)
	assert_bool(s.meta.levels.has(&"gate_lore")).is_false()
	assert_bool(s.meta.levels.has(&"fifth_slot")).is_false()
	assert_bool(s.meta.levels.has(&"recruits")).is_false()
	assert_int(s.runs).is_equal(4)
	assert_int(s.best_wave).is_equal(9)


func test_v3_refunds_the_squad_era_recruits_in_v4() -> void:
	var v3: Dictionary = {"version": 3,
			"meta": {"bricks": 2, "levels": {"recruits": 3, "salvage": 1}},
			"stats": {"runs": 2, "wins": 0, "best_wave": 6}}
	var s := SaveData.from_dict(v3)
	assert_object(s).is_not_null()
	assert_int(s.meta.bricks).is_equal(2 + 5 + 10 + 20)
	assert_bool(s.meta.levels.has(&"recruits")).is_false()
	assert_int(s.meta.levels[&"salvage"]).is_equal(1)
	assert_int(s.runs).is_equal(2)


func test_unknown_versions_are_rejected() -> void:
	assert_object(SaveData.from_dict({"version": 99})).is_null()
	assert_object(SaveData.from_dict({"bricks": 3})).is_null()


func test_missing_file_is_a_fresh_save() -> void:
	var s := SaveData.load_from(create_temp_dir("save") + "/none.json")
	assert_int(s.meta.bricks).is_equal(0)
	assert_str(s.load_warning).is_empty()


func test_corrupt_file_is_kept_aside_not_lost() -> void:
	var path: String = create_temp_dir("save") + "/save.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var s := SaveData.load_from(path)
	assert_str(s.load_warning).is_not_empty()
	assert_bool(FileAccess.file_exists(path + ".bad")).is_true()
	assert_str(FileAccess.get_file_as_string(path + ".bad")).is_equal("{not json")
