extends GdUnitTestSuite


func test_events_are_time_ordered_with_counts() -> void:
	var e := Fixtures.enemy()
	var w := Fixtures.wave(
			[Fixtures.spawn(e, 3, 2.0, 1.0, 0), Fixtures.spawn(e, 2, 0.5, 2.0, 1)],
			[Fixtures.crate_spawn(Fixtures.crate(), 1.0, 2)])
	var events := WaveSchedule.build(w, PackedInt32Array([0, 1, 2]), RandomNumberGenerator.new())
	assert_int(events.size()).is_equal(6)
	var times: Array[float] = []
	for ev: WaveSchedule.Event in events:
		times.append(ev.time)
	assert_array(times).is_equal([0.5, 1.0, 2.0, 2.5, 3.0, 4.0])
	assert_int(WaveSchedule.enemy_count(w)).is_equal(5)
	assert_int(events[1].type).is_equal(WaveSchedule.EventType.CRATE)
	assert_int(events[1].path).is_equal(2)


func test_same_time_keeps_authored_order() -> void:
	var a := Fixtures.enemy(1, 1, 1, 1, false, &"a")
	var b := Fixtures.enemy(1, 1, 1, 1, false, &"b")
	var w := Fixtures.wave([Fixtures.spawn(a, 1, 1.0), Fixtures.spawn(b, 1, 1.0)])
	var events := WaveSchedule.build(w, PackedInt32Array([0, 1, 2]), RandomNumberGenerator.new())
	assert_str(String(events[0].enemy.id)).is_equal("a")
	assert_str(String(events[1].enemy.id)).is_equal("b")


func test_random_paths_are_open_ones_and_seeded() -> void:
	var w := Fixtures.wave([Fixtures.spawn(Fixtures.enemy(), 50, 0.0, 0.1, -1)])
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 9
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 9
	var open := PackedInt32Array([0, 2])  # path 1's portal is still sealed
	var a := WaveSchedule.build(w, open, rng_a)
	var b := WaveSchedule.build(w, open, rng_b)
	var seen: Dictionary = {}
	for i: int in a.size():
		assert_bool(open.has(a[i].path)).is_true()
		assert_int(a[i].path).is_equal(b[i].path)
		seen[a[i].path] = true
	assert_int(seen.size()).is_equal(2)


func test_a_fixed_path_is_kept_as_authored() -> void:
	var w := Fixtures.wave([Fixtures.spawn(Fixtures.enemy(), 1, 0.0, 1.0, 1)])
	assert_int(WaveSchedule.build(w, PackedInt32Array([0, 1, 2]), RandomNumberGenerator.new())[0].path).is_equal(1)
