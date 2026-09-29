extends GdUnitTestSuite
## Campaign: stars per sector, unlocking in order, the one consolation star.

var cfg: RunConfig
var maps: Array[MapDef] = []


func before_test() -> void:
	cfg = RunConfig.new()
	cfg.star_thresholds = PackedFloat32Array([0.5, 0.9])
	cfg.consolation_waves = 5
	maps.clear()
	for id: StringName in [&"s1", &"s2", &"s3"]:
		var m := MapDef.new()
		m.id = id
		maps.append(m)


func test_stars_by_gate_left() -> void:
	var t := PackedFloat32Array([0.5, 0.9])
	assert_int(Campaign.stars_for(false, 1.0, t)).is_equal(0)
	assert_int(Campaign.stars_for(true, 0.1, t)).is_equal(1)
	assert_int(Campaign.stars_for(true, 0.5, t)).is_equal(2)
	assert_int(Campaign.stars_for(true, 0.89, t)).is_equal(2)
	assert_int(Campaign.stars_for(true, 0.9, t)).is_equal(3)


func test_sectors_unlock_in_order_on_a_win() -> void:
	var c := Campaign.new()
	assert_bool(c.is_unlocked(maps, 0)).is_true()
	assert_bool(c.is_unlocked(maps, 1)).is_false()
	c.record(&"s1", true, 10, 0.3, cfg)
	assert_bool(c.is_unlocked(maps, 1)).is_true()
	assert_bool(c.is_unlocked(maps, 2)).is_false()
	assert_bool(c.is_unlocked(maps, 3)).is_false()


func test_best_stars_are_kept_and_only_gains_count() -> void:
	var c := Campaign.new()
	var r: Dictionary = c.record(&"s1", true, 10, 0.6, cfg)
	assert_int(r["stars"]).is_equal(2)
	assert_int(r["gained"]).is_equal(2)
	r = c.record(&"s1", true, 10, 0.2, cfg)
	assert_int(r["gained"]).is_equal(0)
	assert_bool(r["new_best"]).is_false()
	assert_int(c.stars_at(&"s1")).is_equal(2)
	r = c.record(&"s1", true, 10, 1.0, cfg)
	assert_int(r["gained"]).is_equal(1)
	assert_int(c.stars_total()).is_equal(3)


func test_a_deep_loss_gives_one_consolation_star_once_without_unlocking() -> void:
	var c := Campaign.new()
	assert_int(c.record(&"s1", false, 4, 0.0, cfg)["gained"]).is_equal(0)
	var r: Dictionary = c.record(&"s1", false, 5, 0.0, cfg)
	assert_bool(r["consolation"]).is_true()
	assert_int(r["gained"]).is_equal(1)
	assert_int(c.record(&"s1", false, 9, 0.0, cfg)["gained"]).is_equal(0)
	assert_bool(c.is_unlocked(maps, 1)).is_false()
	# Winning later still adds the stars beyond it.
	assert_int(c.record(&"s1", true, 10, 0.95, cfg)["gained"]).is_equal(2)
	assert_bool(c.is_unlocked(maps, 1)).is_true()


func test_no_consolation_on_a_sector_already_won() -> void:
	var c := Campaign.new()
	c.record(&"s1", true, 10, 0.1, cfg)
	assert_bool(c.record(&"s1", false, 8, 0.0, cfg)["consolation"]).is_false()
