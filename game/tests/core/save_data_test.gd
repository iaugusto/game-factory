extends GdUnitTestSuite


func after_test() -> void:
	clean_temp_dir()


func _cfg() -> RunConfig:
	var c := RunConfig.new()
	c.star_thresholds = PackedFloat32Array([0.5, 0.9])
	c.consolation_waves = 5
	return c


func _sample() -> SaveData:
	var s := SaveData.new()
	s.record_result(&"outpost", true, 10, 0.95, _cfg())
	s.record_result(&"canyon", false, 7, 0.0, _cfg())
	s.tree.owned[&"drill"] = true
	return s


func test_dict_round_trip() -> void:
	var back := SaveData.from_dict(_sample().to_dict())
	assert_int(back.campaign.stars_at(&"outpost")).is_equal(3)
	assert_int(back.campaign.stars_at(&"canyon")).is_equal(1)
	assert_bool(back.campaign.cleared.has(&"outpost")).is_true()
	assert_bool(back.campaign.cleared.has(&"canyon")).is_false()
	assert_bool(back.campaign.consoled.has(&"canyon")).is_true()
	assert_bool(back.tree.has(&"drill")).is_true()
	assert_int(back.runs).is_equal(2)
	assert_int(back.wins).is_equal(1)
	assert_int(back.best_wave).is_equal(10)
	assert_bool(back.legacy.is_empty()).is_true()


func test_file_round_trip_is_atomic() -> void:
	var path: String = create_temp_dir("save") + "/save.json"
	assert_int(_sample().save_to(path)).is_equal(OK)
	assert_bool(FileAccess.file_exists(path + ".tmp")).is_false()
	var back := SaveData.load_from(path)
	assert_str(back.load_warning).is_empty()
	assert_int(back.campaign.stars_total()).is_equal(4)


func test_stars_free_is_earned_minus_spent() -> void:
	var tree := SkillTreeDef.new()
	var drill := SkillDef.new()
	drill.id = &"drill"
	drill.cost = 1
	tree.skills = [drill]
	assert_int(_sample().stars_free(tree)).is_equal(3)


func test_v1_migrates_to_current_with_bricks_kept_as_legacy() -> void:
	var v1: Dictionary = {"version": 1, "bricks": 30, "meta": {"salvage": 3}}
	var s := SaveData.from_dict(v1)
	assert_object(s).is_not_null()
	assert_int(int(s.legacy["bricks"])).is_equal(30)
	assert_int(int(s.legacy["levels"]["salvage"])).is_equal(3)
	assert_int(s.runs).is_equal(0)
	assert_int(int(SaveData.migrate(v1)["version"])).is_equal(SaveData.CURRENT_VERSION)


func test_v2_refunds_removed_gate_era_upgrades_in_v3() -> void:
	var v2: Dictionary = {"version": 2,
			"meta": {"bricks": 5, "levels": {"recruits": 1, "gate_lore": 2, "fifth_slot": 1}},
			"stats": {"runs": 4, "wins": 1, "best_wave": 9}}
	var s := SaveData.from_dict(v2)
	assert_object(s).is_not_null()
	# v3 refunds the gate upgrades; v4 then refunds "recruits" (level 1 cost 5); v5 keeps the
	# result as legacy.
	assert_int(int(s.legacy["bricks"])).is_equal(5 + 15 + 35 + 60 + 5)
	assert_bool((s.legacy["levels"] as Dictionary).is_empty()).is_true()
	assert_int(s.runs).is_equal(4)
	assert_int(s.best_wave).is_equal(9)


func test_v3_refunds_the_squad_era_recruits_in_v4() -> void:
	var v3: Dictionary = {"version": 3,
			"meta": {"bricks": 2, "levels": {"recruits": 3, "salvage": 1}},
			"stats": {"runs": 2, "wins": 0, "best_wave": 6}}
	var s := SaveData.from_dict(v3)
	assert_object(s).is_not_null()
	assert_int(int(s.legacy["bricks"])).is_equal(2 + 5 + 10 + 20)
	assert_bool((s.legacy["levels"] as Dictionary).has("recruits")).is_false()
	assert_int(int(s.legacy["levels"]["salvage"])).is_equal(1)
	assert_int(s.runs).is_equal(2)


func test_v4_moves_the_brick_meta_to_legacy_and_starts_the_campaign() -> void:
	var v4: Dictionary = {"version": 4,
			"meta": {"bricks": 12, "levels": {"drill": 2, "war_chest": 1}},
			"stats": {"runs": 9, "wins": 2, "best_wave": 10}}
	var s := SaveData.from_dict(v4)
	assert_object(s).is_not_null()
	assert_int(int(s.legacy["bricks"])).is_equal(12)
	assert_int(int(s.legacy["levels"]["drill"])).is_equal(2)
	assert_int(s.campaign.stars_total()).is_equal(0)
	assert_bool(s.tree.owned.is_empty()).is_true()
	assert_int(s.runs).is_equal(9)
	assert_int(s.wins).is_equal(2)
	# The legacy block survives a save and reload.
	assert_int(int(SaveData.from_dict(s.to_dict()).legacy["bricks"])).is_equal(12)


func test_v5_gains_tips_with_none_seen() -> void:
	var v5: Dictionary = {"version": 5,
			"campaign": {"best": {"outpost": 2}, "cleared": ["outpost"], "consoled": []},
			"tree": {"owned": ["drill"]}, "stats": {"runs": 3, "wins": 1, "best_wave": 10}}
	var s := SaveData.from_dict(v5)
	assert_object(s).is_not_null()
	assert_bool(s.tips_seen.is_empty()).is_true()
	assert_bool(s.tips_off).is_false()
	assert_int(s.campaign.stars_at(&"outpost")).is_equal(2)
	assert_bool(s.tree.has(&"drill")).is_true()


func test_tips_round_trip() -> void:
	var s := _sample()
	s.tips_seen["first_build"] = true
	s.tips_seen["new_enemy:grunt"] = true
	s.tips_off = true
	var back := SaveData.from_dict(s.to_dict())
	assert_bool(back.tips_seen.has("first_build")).is_true()
	assert_bool(back.tips_seen.has("new_enemy:grunt")).is_true()
	assert_bool(back.tips_off).is_true()


func test_v6_gains_abilities_starting_on_the_strike() -> void:
	var v6: Dictionary = {"version": 6,
			"campaign": {"best": {"outpost": 3}, "cleared": ["outpost"], "consoled": []},
			"tree": {"owned": []}, "stats": {"runs": 1, "wins": 1, "best_wave": 10},
			"tips": {"seen": ["strike"], "off": false}}
	var migrated: Dictionary = SaveData.migrate(v6)
	assert_int(int(migrated["version"])).is_equal(7)
	var s := SaveData.from_dict(v6)
	assert_str(String(s.last_ability)).is_equal("strike")
	assert_bool(s.tips_seen.has("strike")).is_true()
	assert_bool(s.campaign.cleared.has(&"outpost")).is_true()


func test_last_ability_round_trips() -> void:
	var s := _sample()
	s.last_ability = &"napalm"
	assert_str(String(SaveData.from_dict(s.to_dict()).last_ability)).is_equal("napalm")


func test_abilities_unlock_with_the_sector_that_names_them() -> void:
	var free := AbilityDef.new()
	free.id = &"strike"
	var gated := AbilityDef.new()
	gated.id = &"napalm"
	gated.unlocked_by = &"outpost"
	var cfg := _cfg()
	cfg.abilities = [free, gated]
	var s := SaveData.new()
	assert_array(s.campaign.abilities_unlocked(cfg)).is_equal([free])
	s.record_result(&"outpost", false, 7, 0.0, cfg)  # a consolation star is not a clear
	assert_bool(s.campaign.ability_unlocked(gated)).is_false()
	s.record_result(&"outpost", true, 10, 0.5, cfg)
	assert_array(s.campaign.abilities_unlocked(cfg)).is_equal([free, gated])


func test_unknown_versions_are_rejected() -> void:
	assert_object(SaveData.from_dict({"version": 99})).is_null()
	assert_object(SaveData.from_dict({"bricks": 3})).is_null()


func test_missing_file_is_a_fresh_save() -> void:
	var s := SaveData.load_from(create_temp_dir("save") + "/none.json")
	assert_int(s.campaign.stars_total()).is_equal(0)
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
