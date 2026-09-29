extends GdUnitTestSuite
## SkillTree: buying needs the tier above and enough stars; reset refunds everything.

var tree: SkillTreeDef


func before_test() -> void:
	tree = SkillTreeDef.new()
	tree.branch_titles = PackedStringArray(["A", "B"])
	tree.skills = [
		Fixtures.skill(&"a1", 0, 1, 1, &"unit_rate_bonus", 0.08),
		Fixtures.skill(&"a2", 0, 2, 2, &"unit_damage_bonus", 0.1),
		Fixtures.skill(&"b1", 1, 1, 1, &"wall_hp_bonus", 40.0),
	]


func test_a_node_needs_the_tier_above_it() -> void:
	var t := SkillTree.new()
	assert_bool(t.can_buy(tree, tree.skill_by_id(&"a2"), 10)).is_false()
	assert_bool(t.buy(tree, tree.skill_by_id(&"a1"), 10)).is_true()
	assert_bool(t.can_buy(tree, tree.skill_by_id(&"a2"), 10)).is_true()


func test_stars_limit_what_can_be_bought() -> void:
	var t := SkillTree.new()
	assert_bool(t.buy(tree, tree.skill_by_id(&"a1"), 2)).is_true()
	assert_int(t.spent(tree)).is_equal(1)
	# a2 costs 2 and only 1 star is left.
	assert_bool(t.buy(tree, tree.skill_by_id(&"a2"), 2)).is_false()
	assert_bool(t.buy(tree, tree.skill_by_id(&"b1"), 2)).is_true()
	assert_bool(t.buy(tree, tree.skill_by_id(&"b1"), 5)).is_false()  # owned already


func test_reset_frees_every_star() -> void:
	var t := SkillTree.new()
	t.buy(tree, tree.skill_by_id(&"a1"), 5)
	t.buy(tree, tree.skill_by_id(&"a2"), 5)
	assert_int(t.spent(tree)).is_equal(3)
	t.reset()
	assert_int(t.spent(tree)).is_equal(0)
	assert_bool(t.has(&"a1")).is_false()


func test_owned_nodes_become_run_modifiers() -> void:
	var t := SkillTree.new()
	t.buy(tree, tree.skill_by_id(&"a1"), 5)
	t.buy(tree, tree.skill_by_id(&"b1"), 5)
	var mods: RunModifiers = t.to_modifiers(tree)
	assert_float(mods.unit_rate_bonus).is_equal_approx(0.08, 1e-6)
	assert_float(mods.wall_hp_bonus).is_equal(40.0)
	assert_float(mods.unit_damage_bonus).is_equal(0.0)


func test_ids_no_longer_in_the_tree_cost_and_give_nothing() -> void:
	var t := SkillTree.new()
	t.owned[&"removed_node"] = true
	assert_int(t.spent(tree)).is_equal(0)
	assert_float(t.to_modifiers(tree).gold_bonus).is_equal(0.0)
