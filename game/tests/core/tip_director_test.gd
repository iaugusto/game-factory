extends GdUnitTestSuite
## TipDirector: triggers, priority order, per-argument tips, never twice, and off.


func _tip(id: StringName, trigger: StringName, priority: int = 0,
		per_arg: bool = false) -> TipDef:
	var t := TipDef.new()
	t.id = id
	t.trigger = trigger
	t.priority = priority
	t.per_arg = per_arg
	t.cards = [TipCard.new()]
	return t


func _director(seen: Dictionary = {}) -> TipDirector:
	var tips: Array[TipDef] = [_tip(&"build", &"run_started", 80),
			_tip(&"enemy", &"new_enemy", 90, true), _tip(&"crates", &"crate_spawned", 60)]
	return TipDirector.new(tips, seen)


func test_nothing_waits_until_its_event() -> void:
	var d := _director()
	assert_object(d.pending()).is_null()
	d.notify(&"unit_built")
	assert_object(d.pending()).is_null()
	d.notify(&"crate_spawned")
	assert_str(String(d.pending().def.id)).is_equal("crates")


func test_higher_priority_shows_first() -> void:
	var d := _director()
	d.notify(&"crate_spawned")
	d.notify(&"run_started")
	d.notify(&"new_enemy", &"grunt")
	assert_str(String(d.pending().def.id)).is_equal("enemy")
	d.done(d.pending())
	assert_str(String(d.pending().def.id)).is_equal("build")
	d.done(d.pending())
	assert_str(String(d.pending().def.id)).is_equal("crates")
	d.done(d.pending())
	assert_object(d.pending()).is_null()


func test_a_seen_tip_never_comes_back() -> void:
	var seen: Dictionary = {}
	var d := _director(seen)
	d.notify(&"run_started")
	d.done(d.pending())
	d.notify(&"run_started")
	assert_object(d.pending()).is_null()
	# The seen set is the caller's (the save's): a new director on it remembers.
	assert_bool(seen.has("build")).is_true()
	var again := _director(seen)
	again.notify(&"run_started")
	assert_object(again.pending()).is_null()


func test_per_argument_tips_show_once_per_argument() -> void:
	var d := _director()
	d.notify(&"new_enemy", &"grunt")
	d.notify(&"new_enemy", &"grunt")
	d.notify(&"new_enemy", &"runner")
	assert_str(d.pending().key()).is_equal("enemy:grunt")
	d.done(d.pending())
	assert_str(d.pending().key()).is_equal("enemy:runner")
	d.done(d.pending())
	d.notify(&"new_enemy", &"grunt")
	assert_object(d.pending()).is_null()
	assert_bool(d.has_seen("enemy:runner")).is_true()


func test_a_disabled_director_queues_nothing() -> void:
	var d := _director()
	d.enabled = false
	d.notify(&"run_started")
	assert_object(d.pending()).is_null()


func test_clear_queue_drops_waiting_tips_but_not_seen_ones() -> void:
	var d := _director()
	d.notify(&"run_started")
	d.notify(&"crate_spawned")
	d.done(d.pending())
	d.clear_queue()
	assert_object(d.pending()).is_null()
	d.notify(&"crate_spawned")
	assert_str(String(d.pending().def.id)).is_equal("crates")
	d.notify(&"run_started")
	assert_str(String(d.pending().def.id)).is_equal("crates")
