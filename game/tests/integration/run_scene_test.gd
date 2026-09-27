extends GdUnitTestSuite
## The real run scene, headless. Real-time processing is switched off; the test advances the
## simulation with tick() and pulls views with sync_views(), so every assertion is exact.

const SCENE: String = "res://scenes/run.tscn"

var scene: RunController


func before_test() -> void:
	scene = auto_free(load(SCENE).instantiate())
	add_child(scene)
	scene.set_physics_process(false)
	scene.set_process(false)
	scene.start_run(4242)


func after_test() -> void:
	Engine.time_scale = 1.0


func _tick_until(predicate: Callable, max_ticks: int = 60 * 120) -> void:
	for i: int in max_ticks:
		if predicate.call():
			return
		scene.tick(1)


## Canvas position of a field point.
func _screen(field_pos: Vector2) -> Vector2:
	return scene.field_origin() + field_pos


func _press(pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	return e


func _release(pos: Vector2) -> InputEventMouseButton:
	var e := _press(pos)
	e.pressed = false
	return e


## Play whole phases the way the autoplayer would, pressing the UI's buttons.
func _play_until_over(max_ticks: int = 60 * 60 * 30) -> void:
	scene.autoplay = true
	while not scene.run.is_over() and scene.run.ticks < max_ticks:
		match scene.run.phase:
			Run.Phase.BUILD:
				scene.bot.play_build(scene.run)
				scene.start_wave()
			Run.Phase.CARD:
				scene.card_picker.pick(0)
			Run.Phase.WAVE:
				scene.tick(1)


func test_run_opens_in_build_with_the_start_bar_and_pads() -> void:
	assert_int(scene.run.phase).is_equal(Run.Phase.BUILD)
	assert_bool(scene.build_bar.visible).is_true()
	assert_int(scene.plot_field.views.size()).is_equal(scene.run.plots.size())
	scene.build_bar.start_pressed.emit()
	assert_int(scene.run.phase).is_equal(Run.Phase.WAVE)
	assert_bool(scene.build_bar.visible).is_false()


func test_tapping_a_plot_opens_the_menu_and_building_from_it_works() -> void:
	var plot: CombatSim.Plot = scene.run.plots[2]
	scene.handle_pointer(_press(_screen(plot.position + Vector2(10, -8))))
	assert_bool(scene.build_menu.is_open()).is_true()
	assert_int(scene.build_menu.plot).is_equal(2)
	assert_int(scene.plot_field.selected).is_equal(2)
	var gold: int = scene.run.gold
	var unit: UnitDef = scene.config.units[0]
	scene.build_menu.build_requested.emit(2, unit.id)
	assert_object(plot.def).is_same(unit)
	assert_int(scene.run.gold).is_equal(gold - scene.run.unit_cost(unit.id))
	assert_bool(scene.build_menu.is_open()).is_false()
	assert_int(scene.plot_field.selected).is_equal(-1)


func test_menu_offers_every_unit_and_greys_the_unaffordable() -> void:
	scene.run.gold = 30
	scene.open_plot(0)
	scene.build_menu.sync(scene.run)
	for u: UnitDef in scene.config.units:
		var b: Button = scene.build_menu._unit_buttons[u.id]
		assert_bool(b.disabled).is_equal(scene.run.unit_cost(u.id) > 30)


func test_built_plot_opens_the_upgrade_card() -> void:
	scene.run.gold = 500
	var unit: UnitDef = scene.config.units[0]
	scene.run.build(1, unit.id)
	scene.open_plot(1)
	assert_object(scene.build_menu._upgrade).is_not_null()
	assert_bool(scene.build_menu._upgrade.disabled).is_false()
	scene.build_menu.upgrade_requested.emit(1)
	assert_int(scene.run.plots[1].level).is_equal(2)


func test_menu_slows_time_mid_wave_and_closing_restores_it() -> void:
	scene.start_wave()
	scene.open_plot(3)
	assert_float(Engine.time_scale).is_equal_approx(scene.config.build_menu_time_scale, 0.0001)
	scene.build_menu.close()
	assert_float(Engine.time_scale).is_equal(1.0)


func test_wall_spots_can_be_built_on() -> void:
	var wall_spot: int = -1
	for plot: CombatSim.Plot in scene.run.plots:
		if plot.position.y > scene.config.wall_y:
			wall_spot = plot.index
	assert_int(wall_spot).is_greater_equal(0)
	# Drawn above the wall sprite, or the wall hides it.
	assert_int(scene.plot_field.views[wall_spot].z_index).is_greater(scene.field_view.wall.z_index)
	scene.handle_pointer(_press(_screen(scene.run.plots[wall_spot].position)))
	assert_int(scene.build_menu.plot).is_equal(wall_spot)
	var unit: UnitDef = scene.config.units[0]
	scene.build_menu.build_requested.emit(wall_spot, unit.id)
	assert_object(scene.run.plots[wall_spot].def).is_same(unit)


## Start a wave and step until a crate is on the field; returns it.
func _first_crate() -> CombatSim.Crate:
	scene.start_wave()
	_tick_until(func() -> bool: return scene.run.combat.crate_count() > 0)
	for lane: Array in scene.run.combat.path_crates:
		if not lane.is_empty():
			return lane[0]
	return null


func test_a_press_on_a_crate_taps_it() -> void:
	var c: CombatSim.Crate = _first_crate()
	assert_object(c).is_not_null()
	var hp: float = c.hp
	scene.handle_pointer(_press(_screen(c.pos())))
	assert_float(c.hp).is_equal(hp - scene.config.tap_damage)
	assert_bool(scene.build_menu.is_open()).is_false()
	scene.handle_pointer(_release(_screen(c.pos())))
	assert_float(c.hp).is_equal(hp - scene.config.tap_damage)  # releases don't tap


func test_tapping_a_crate_to_zero_pays_out() -> void:
	var c: CombatSim.Crate = _first_crate()
	var gold: int = scene.run.gold
	var taps: int = ceili(c.hp / scene.config.tap_damage)
	for i: int in taps:
		var t := InputEventScreenTouch.new()
		t.pressed = true
		t.position = _screen(c.pos())
		scene.handle_pointer(t)
	scene.tick(1)
	assert_bool(c.alive).is_false()
	assert_int(scene.run.gold).is_greater_equal(gold + c.def.reward)
	assert_bool(scene.crate_field.views.has(c.id)).is_false()


func test_a_press_on_empty_ground_does_nothing() -> void:
	scene.start_wave()
	scene.handle_pointer(_press(_screen(Vector2(270, 120))))
	assert_bool(scene.build_menu.is_open()).is_false()


func test_emulated_mouse_from_touch_is_ignored() -> void:
	var c: CombatSim.Crate = _first_crate()
	var hp: float = c.hp
	var e := _press(_screen(c.pos()))
	e.device = InputEvent.DEVICE_ID_EMULATION
	scene.handle_pointer(e)
	assert_float(c.hp).is_equal(hp)


func test_autoplay_ignores_the_pointer() -> void:
	scene.autoplay = true
	scene.handle_pointer(_press(_screen(scene.run.plots[0].position)))
	assert_bool(scene.build_menu.is_open()).is_false()


func test_build_bar_covers_no_build_spot() -> void:
	assert_bool(scene.build_bar.visible).is_true()
	var bar: Rect2 = scene.build_bar.get_global_rect()
	assert_float(bar.size.y).is_greater(0.0)
	for plot: CombatSim.Plot in scene.run.plots:
		var r := Rect2(_screen(plot.position) - Vector2(28, 28), Vector2(56, 56))
		assert_bool(bar.intersects(r)).override_failure_message(
				"build bar covers plot %d" % plot.index).is_false()


func test_views_mirror_core_state() -> void:
	scene.autoplay = true
	scene.bot.play_build(scene.run)
	scene.start_wave()
	var sim: CombatSim = scene.run.combat
	scene.tick(60 * 3)
	_tick_until(func() -> bool: return sim.enemy_count() >= 1)
	scene.sync_views()
	assert_int(sim.enemy_count()).is_greater(0)
	assert_int(scene.enemy_field.drawn_count()).is_equal(sim.enemy_count())
	assert_int(scene.crate_field.views.size()).is_equal(sim.crate_count())
	for lane: Array in sim.path_crates:
		for c: CombatSim.Crate in lane:
			assert_object(scene.crate_field.views[c.id].crate).is_same(c)
	for i: int in scene.run.plots.size():
		assert_object(scene.plot_field.views[i].plot).is_same(scene.run.plots[i])


func test_wave_clear_shows_cards_then_the_build_bar() -> void:
	scene.autoplay = true
	scene.bot.play_build(scene.run)
	scene.start_wave()
	_tick_until(func() -> bool: return scene.run.phase != Run.Phase.WAVE)
	assert_int(scene.run.phase).is_equal(Run.Phase.CARD)
	assert_bool(scene.card_picker.visible).is_true()
	assert_int(scene.card_picker._buttons.size()).is_equal(scene.run.card_offer.size())
	assert_int(scene.crate_field.views.size()).is_equal(0)  # leftover loot went with the wave
	scene.autoplay = false
	scene.card_picker.pick(0)
	assert_int(scene.run.phase).is_equal(Run.Phase.BUILD)
	assert_int(scene.run.wave_index).is_equal(1)
	assert_bool(scene.card_picker.visible).is_false()
	assert_bool(scene.build_bar.visible).is_true()


func test_a_jammed_unit_shows_it_and_recovers() -> void:
	scene.run.gold = 500
	scene.run.build(2, scene.config.units[0].id)
	scene.start_wave()
	var plot: CombatSim.Plot = scene.run.plots[2]
	plot.disabled = 2.0
	scene.sync_views(0.016)
	assert_float(scene.plot_field.views[2]._disabled).is_equal_approx(2.0, 0.001)
	scene.tick(60 * 2 + 1)
	scene.sync_views(0.016)
	assert_bool(plot.is_disabled()).is_false()
	assert_float(scene.plot_field.views[2]._disabled).is_equal(0.0)


func test_losing_plays_the_breach_then_the_result() -> void:
	scene.start_wave()
	scene.run.wall_damage_taken = scene.run.wall_max() - 0.5
	_tick_until(func() -> bool: return scene.run.phase == Run.Phase.LOST, 60 * 60)
	assert_int(scene.run.phase).is_equal(Run.Phase.LOST)
	assert_bool(scene.overlay.is_result()).is_true()
	assert_str(scene.overlay.title.text).is_equal("THE GATE FELL")
	# The breach: slow motion, the result transparent and unclickable until it has played.
	assert_float(Engine.time_scale).is_equal_approx(RunController.BREACH_TIME_SCALE, 0.001)
	assert_bool(scene.overlay.button.disabled).is_true()
	scene.overlay._process(RunController.BREACH_TIME * RunController.BREACH_TIME_SCALE)
	scene.overlay._process(PhaseOverlay.FADE_TIME * RunController.BREACH_TIME_SCALE)
	assert_bool(scene.overlay.button.disabled).is_false()
	scene._process(RunController.BREACH_TIME * RunController.BREACH_TIME_SCALE)
	assert_float(Engine.time_scale).is_equal(1.0)
	scene.start_run(7)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_the_unit_card_sells_and_offers_masteries_at_max() -> void:
	scene.run.gold = 2000
	var unit: UnitDef = scene.config.units[0]
	scene.run.build(1, unit.id)
	scene.open_plot(1)
	assert_bool(scene.build_menu._masteries[0].visible).is_false()
	while scene.run.upgrade_cost(1) >= 0:
		scene.run.upgrade(1)
	scene.build_menu.sync(scene.run)
	assert_bool(scene.build_menu._masteries[0].visible).is_true()
	scene.build_menu.mastery_requested.emit(1, 0)
	assert_object(scene.run.plots[1].mastery).is_same(unit.masteries[0])
	scene.open_plot(1)
	var gold: int = scene.run.gold
	var refund: int = scene.run.sell_value(1)
	scene.build_menu.sell_requested.emit(1)
	assert_bool(scene.run.plots[1].is_empty()).is_true()
	assert_int(scene.run.gold).is_equal(gold + refund)


func test_barricade_slots_open_the_barricade_card() -> void:
	scene.run.gold = 500
	var slot_pos: Vector2 = scene.config.map.barricade_slots[1]
	scene.handle_pointer(_press(_screen(slot_pos)))
	assert_bool(scene.barricade_menu.is_open()).is_true()
	assert_int(scene.barricade_menu.slot).is_equal(1)
	scene.barricade_menu.build_requested.emit(1)
	assert_int(scene.run.barricade().slot).is_equal(1)
	scene.open_barricade(1)
	scene.barricade_menu.upgrade_requested.emit()
	assert_int(scene.run.barricade().level).is_equal(2)
	scene.open_barricade(0)
	scene.barricade_menu.build_requested.emit(0)  # a move, between waves
	assert_int(scene.run.barricade().slot).is_equal(0)
	assert_int(scene.run.barricade().level).is_equal(2)


func test_the_build_bar_previews_the_wave_and_repairs_the_gate() -> void:
	var counts: Dictionary = WaveSchedule.enemy_counts(scene.config.waves[0])
	assert_int(scene.build_bar.previewed_count()).is_equal(counts.size())
	scene.run.gold = 100
	scene.run.wall_damage_taken = 50.0
	scene.build_bar.sync(scene.run)
	assert_bool(scene.build_bar.repair_button.disabled).is_false()
	scene.build_bar.repair_pressed.emit()
	assert_float(scene.run.wall_hp()).is_equal(scene.run.wall_max() - 50.0 + scene.config.gate_repair_hp)


func test_intel_cards_introduce_new_enemies_before_their_wave() -> void:
	# The run opens on wave 1's build phase: its enemies are all new.
	assert_bool(scene.intel_card.visible).is_true()
	for e: EnemyDef in WaveSchedule.new_enemies(scene.config.waves, 0):
		assert_bool(scene.intel_card.shown.has(e.id)).is_true()
	scene.intel_card.close()
	assert_bool(scene.intel_card.visible).is_false()
	# Skip to a wave that brings nothing new: no card.
	var plain: int = -1
	for i: int in range(1, scene.config.waves.size()):
		if WaveSchedule.new_enemies(scene.config.waves, i).is_empty():
			plain = i
			break
	assert_int(plain).is_greater(0)
	scene.fast_forward_to_wave(plain + 1)
	if scene.run.phase == Run.Phase.BUILD and scene.run.wave_index == plain:
		assert_bool(scene.intel_card.visible).is_false()


func test_switching_to_the_canyon_rebuilds_the_field() -> void:
	var canyon: MapDef = scene.next_map()
	assert_str(String(canyon.id)).is_equal("canyon")
	scene.switch_map(canyon)
	scene.start_run(5)
	assert_object(scene.config.map).is_same(canyon)
	assert_int(scene.run.plots.size()).is_equal(canyon.plots.size())
	assert_int(scene.plot_field.views.size()).is_equal(canyon.plots.size())
	assert_object(scene.field_view.ground.texture).is_same(Art.tex("field/ground_canyon"))
	# A pad locked until wave 4 won't open its menu yet.
	var locked: int = -1
	for i: int in canyon.plots.size():
		if canyon.plot_unlock_wave(i) > 1:
			locked = i
			break
	scene.handle_pointer(_press(_screen(canyon.plots[locked])))
	assert_bool(scene.build_menu.is_open()).is_false()
	scene.open_plot(0)
	assert_bool(scene.build_menu.is_open()).is_true()


func test_the_result_screen_offers_the_other_map() -> void:
	scene.start_wave()
	scene.run.wall_damage_taken = scene.run.wall_max() - 0.5
	_tick_until(func() -> bool: return scene.run.phase == Run.Phase.LOST, 60 * 60)
	assert_bool(scene.overlay.map_button.visible).is_true()
	scene.overlay.next_map_pressed.emit()
	assert_str(String(scene.config.map.id)).is_equal("canyon")
	assert_int(scene.run.phase).is_equal(Run.Phase.BUILD)


func test_the_card_repairs_a_damaged_unit_and_a_fallen_one_leaves_an_empty_pad() -> void:
	scene.run.gold = 500
	var unit: UnitDef = scene.config.units[0]
	scene.run.build(1, unit.id)
	var p: CombatSim.Plot = scene.run.plots[1]
	p.hp = p.max_hp * 0.5
	scene.open_plot(1)
	assert_bool(scene.build_menu._repair.visible).is_true()
	scene.build_menu.repair_requested.emit(1)
	assert_float(p.hp).is_equal(p.max_hp)
	scene.run.combat.destroy_unit(p)
	scene.sync_views(0.016)
	assert_bool(p.is_empty()).is_true()
	scene.open_plot(1)
	assert_int(scene.build_menu._unit_buttons.size()).is_equal(scene.config.units.size())


func test_full_run_ends_on_result_and_restart_resets() -> void:
	scene.fast_forward_to_wave(9)
	_play_until_over()
	assert_bool(scene.run.is_over()).is_true()
	assert_bool(scene.overlay.is_result()).is_true()
	scene.overlay.restart_pressed.emit()
	scene.overlay.visible = false
	assert_int(scene.run.phase).is_equal(Run.Phase.BUILD)
	assert_int(scene.run.wave_index).is_equal(0)
	scene.sync_views()
	assert_int(scene.enemy_field.drawn_count()).is_equal(0)
	assert_int(scene.crate_field.views.size()).is_equal(0)


func test_enemies_render_in_one_batch_per_type() -> void:
	scene.fast_forward_to_wave(10)
	scene.bot.play_build(scene.run)
	scene.start_wave()
	scene.autoplay = true
	scene.tick(60 * 15)
	scene.sync_views()
	var types: Dictionary = {}
	for w: WaveDef in scene.config.waves:
		for s: SpawnEntry in w.spawns:
			types[s.enemy.id] = true
	assert_int(scene.enemy_field.batch_count()).is_less_equal(types.size())
	# Shadows (1) + a batch per type + the HP bar layer: never a node per enemy.
	assert_int(scene.enemy_field.get_child_count()).is_less_equal(types.size() + 2)


func test_crate_views_are_pooled_not_leaked() -> void:
	scene.autoplay = true
	for w: int in 3:
		scene.bot.play_build(scene.run)
		scene.start_wave()
		_tick_until(func() -> bool: return scene.run.phase != Run.Phase.WAVE)
		if scene.run.phase == Run.Phase.CARD:
			scene.card_picker.pick(0)
	assert_int(scene.crate_field.views.size()).is_equal(0)
	assert_int(scene.crate_field.pooled_count()).is_less_equal(6)


func test_popups_stay_inside_the_playfield() -> void:
	scene.fx.popup("+100 VERY WIDE TEXT", Vector2(-50, 300), Color.WHITE, 30)
	scene.fx.popup("+100 VERY WIDE TEXT", Vector2(scene.config.playfield_width() + 50, 300),
			Color.WHITE, 30)
	for child: Node in scene.fx.get_children():
		if child is Label and (child as Label).visible:
			var l: Label = child
			assert_float(l.position.x).is_greater_equal(0.0)
			assert_float(l.position.x + l.size.x).is_less_equal(scene.config.playfield_width())
