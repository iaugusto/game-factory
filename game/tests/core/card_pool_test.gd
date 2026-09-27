extends GdUnitTestSuite


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _cards() -> Array[CardDef]:
	return [
		Fixtures.card(&"a", &"gold_bonus", 0.1),
		Fixtures.card(&"b", &"gold_bonus", 0.1),
		Fixtures.card(&"c", &"gold_bonus", 0.1),
		Fixtures.card(&"d", &"gold_bonus", 0.1),
		Fixtures.card(&"never", &"gold_bonus", 0.1, 0.0),
	]


func test_offer_has_no_duplicates() -> void:
	for s: int in 50:
		var offer := CardPool.draw(_cards(), {}, 3, _rng(s))
		assert_int(offer.size()).is_equal(3)
		var ids: Dictionary = {}
		for c: CardDef in offer:
			ids[c.id] = true
		assert_int(ids.size()).is_equal(3)


func test_zero_weight_and_maxed_cards_are_never_offered() -> void:
	var taken: Dictionary[StringName, int] = {&"a": 1}
	for s: int in 100:
		for c: CardDef in CardPool.draw(_cards(), taken, 3, _rng(s)):
			assert_str(String(c.id)).is_not_equal("never")
			assert_str(String(c.id)).is_not_equal("a")


func test_small_pool_gives_short_offer() -> void:
	var taken: Dictionary[StringName, int] = {&"a": 1, &"b": 1, &"c": 1}
	assert_int(CardPool.draw(_cards(), taken, 3, _rng(1)).size()).is_equal(1)


func test_seeded_draw_is_deterministic() -> void:
	var ids := func(offer: Array[CardDef]) -> Array:
		return offer.map(func(c: CardDef) -> StringName: return c.id)
	assert_array(ids.call(CardPool.draw(_cards(), {}, 3, _rng(5)))) \
			.is_equal(ids.call(CardPool.draw(_cards(), {}, 3, _rng(5))))


func test_weights_bias_the_draw() -> void:
	var heavy: Array[CardDef] = [
		Fixtures.card(&"heavy", &"gold_bonus", 0.1, 50.0),
		Fixtures.card(&"light", &"gold_bonus", 0.1, 1.0),
	]
	var heavy_first: int = 0
	for s: int in 200:
		if CardPool.draw(heavy, {}, 1, _rng(s))[0].id == &"heavy":
			heavy_first += 1
	assert_int(heavy_first).is_greater(180)
