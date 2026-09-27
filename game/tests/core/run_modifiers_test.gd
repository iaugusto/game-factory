extends GdUnitTestSuite


func test_known_and_unknown_keys() -> void:
	assert_bool(RunModifiers.has_key(&"gold_bonus")).is_true()
	assert_bool(RunModifiers.has_key(&"no_such_bonus")).is_false()


func test_add_accumulates() -> void:
	var m := RunModifiers.new()
	assert_bool(m.add(&"gold_bonus", 0.25)).is_true()
	m.add(&"gold_bonus", 0.25)
	assert_float(m.gold_bonus).is_equal_approx(0.5, 0.0001)


func test_add_unknown_key_changes_nothing() -> void:
	var m := RunModifiers.new()
	var result: Array[bool] = []
	await assert_error(func() -> void: result.append(m.add(&"nope", 1.0))) \
			.is_push_error("RunModifiers: unknown key 'nope'")
	assert_bool(result[0]).is_false()


func test_duplicate_is_independent() -> void:
	var m := RunModifiers.new()
	m.crit_chance = 0.1
	var copy := m.duplicate_mods()
	copy.crit_chance = 0.5
	assert_float(m.crit_chance).is_equal_approx(0.1, 0.0001)
	assert_float(copy.crit_chance).is_equal_approx(0.5, 0.0001)
