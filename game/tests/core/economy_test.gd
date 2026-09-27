extends GdUnitTestSuite


func test_kill_reward_bonuses() -> void:
	var mods := RunModifiers.new()
	var grunt := Fixtures.enemy(1, 1, 1, 4)
	var runner := Fixtures.enemy(1, 1, 1, 4, true)
	assert_int(Economy.kill_reward(grunt, mods)).is_equal(4)
	mods.gold_bonus = 0.5
	mods.runner_gold_bonus = 1.0
	assert_int(Economy.kill_reward(grunt, mods)).is_equal(6)
	assert_int(Economy.kill_reward(runner, mods)).is_equal(10)


func test_crate_reward_bonus_rounds_and_never_drops_below_base() -> void:
	var mods := RunModifiers.new()
	var crate := Fixtures.crate(5, 12)
	assert_int(Economy.crate_reward(crate, mods)).is_equal(12)
	mods.crate_reward_bonus = 0.3
	assert_int(Economy.crate_reward(crate, mods)).is_equal(16)  # 15.6 rounds to 16
	mods.crate_reward_bonus = -0.5
	assert_int(Economy.crate_reward(crate, mods)).is_equal(12)


func test_discount_rounds_up_and_is_capped() -> void:
	var mods := RunModifiers.new()
	mods.unit_cost_discount = 0.25
	assert_int(Economy.discounted(15, mods)).is_equal(12)  # 11.25 → 12
	mods.unit_cost_discount = 5.0
	assert_int(Economy.discounted(100, mods)).is_equal(10)  # capped at 90%
	assert_int(Economy.discounted(1, mods)).is_equal(1)


func test_unit_upgrade_cost_per_level_and_max() -> void:
	var mods := RunModifiers.new()
	var u := Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, PackedInt32Array([20, 30]))
	assert_int(u.max_level()).is_equal(3)
	assert_int(Economy.unit_cost(u, mods)).is_equal(10)
	assert_int(Economy.unit_upgrade_cost(u, 1, mods)).is_equal(20)
	assert_int(Economy.unit_upgrade_cost(u, 2, mods)).is_equal(30)
	assert_int(Economy.unit_upgrade_cost(u, 3, mods)).is_equal(-1)
