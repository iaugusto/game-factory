extends GdUnitTestSuite


func test_buy_charges_and_levels_up_until_max() -> void:
	var up := Fixtures.meta(&"walls", &"wall_hp_bonus", 1, PackedInt32Array([5, 10]))
	var meta := MetaProgress.new()
	meta.bricks = 20
	assert_bool(meta.buy(up)).is_true()
	assert_int(meta.bricks).is_equal(15)
	assert_bool(meta.buy(up)).is_true()
	assert_int(meta.bricks).is_equal(5)
	assert_int(meta.level(up)).is_equal(2)
	assert_int(meta.next_cost(up)).is_equal(-1)
	assert_bool(meta.buy(up)).is_false()


func test_cannot_buy_without_bricks() -> void:
	var up := Fixtures.meta(&"x", &"gold_bonus", 0.1, PackedInt32Array([5]))
	var meta := MetaProgress.new()
	meta.bricks = 4
	assert_bool(meta.buy(up)).is_false()
	assert_int(meta.bricks).is_equal(4)


func test_levels_become_starting_modifiers() -> void:
	var a := Fixtures.meta(&"a", &"wall_hp_bonus", 1, PackedInt32Array([1, 1, 1]))
	var b := Fixtures.meta(&"b", &"gold_bonus", 0.1, PackedInt32Array([1]))
	var meta := MetaProgress.new()
	meta.levels = {&"a": 3}
	var mods := meta.to_modifiers([a, b])
	assert_float(mods.wall_hp_bonus).is_equal(3.0)
	assert_float(mods.gold_bonus).is_equal(0.0)
