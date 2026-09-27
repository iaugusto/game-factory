extends GdUnitTestSuite


func _draws(streams: RngStreams, name: StringName, n: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in n:
		out.append(streams.stream(name).randi())
	return out


func test_same_seed_same_sequence() -> void:
	assert_array(_draws(RngStreams.new(42), &"spawn", 5)) \
			.is_equal(_draws(RngStreams.new(42), &"spawn", 5))


func test_different_seed_different_sequence() -> void:
	assert_array(_draws(RngStreams.new(1), &"spawn", 5)) \
			.is_not_equal(_draws(RngStreams.new(2), &"spawn", 5))


func test_streams_are_independent() -> void:
	# Drawing heavily from "cards" must not shift "spawn".
	var a := RngStreams.new(7)
	var b := RngStreams.new(7)
	_draws(b, &"cards", 100)
	assert_array(_draws(a, &"spawn", 5)).is_equal(_draws(b, &"spawn", 5))


func test_stream_is_reused() -> void:
	var s := RngStreams.new(3)
	assert_object(s.stream(&"cards")).is_same(s.stream(&"cards"))
