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
	scene.offer_pick = false
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


func test_a_barricade_slot_is_tapped_by_its_shape() -> void:
	# The tap area is the barricade's footprint (what the slot ghost shows), not a circle: its
	# ends are wide of the centre, but a tap just above or below misses.
	var slot_pos: Vector2 = scene.config.map.barricade_slots[1]
	var size: Vector2 = Art.size(BarricadeField.SLOT_KEY)
	assert_float(size.x).is_greater(size.y * 2.0)
	var bf: BarricadeField = scene.barricade_field
	assert_int(bf.slot_at(slot_pos + Vector2(size.x * 0.45, 0))).is_equal(1)
	assert_int(bf.slot_at(slot_pos - Vector2(size.x * 0.45, size.y * 0.4))).is_equal(1)
	assert_int(bf.slot_at(slot_pos + Vector2(0, size.y / 2.0 + BarricadeField.TAP_SLOP + 4.0))) \
			.is_equal(-1)
	assert_int(bf.slot_at(slot_pos + Vector2(size.x / 2.0 + BarricadeField.TAP_SLOP + 4.0, 0))) \
			.is_equal(-1)


func test_the_build_bar_previews_the_wave_and_repairs_the_gate() -> void:
	var counts: Dictionary = WaveSchedule.enemy_counts(scene.config.waves[0])
	assert_int(scene.build_bar.previewed_count()).is_equal(counts.size())
	scene.run.gold = 100
	scene.run.wall_damage_taken = 50.0
	scene.build_bar.sync(scene.run)
	assert_bool(scene.build_bar.repair_button.disabled).is_false()
	scene.build_bar.repair_pressed.emit()
	assert_float(scene.run.wall_hp()).is_equal(scene.run.wall_max() - 50.0 + scene.config.gate_repair_hp)


func test_tips_are_off_in_a_direct_run() -> void:
	scene.pump_tips()
	assert_bool(scene.tip_layer.is_active()).is_false()


func test_the_first_run_teaches_the_enemy_then_building_then_starting() -> void:
	var seen: Dictionary = {}
	scene.enable_tips(seen)
	scene.start_run(4242)
	scene.pump_tips()
	# Wave 1's enemy comes first: its portrait card, with no spotlight.
	var first: Array[EnemyDef] = WaveSchedule.new_enemies(scene.config.waves, 0)
	assert_str(scene.tip_layer.current.key()).is_equal("new_enemy:%s" % first[0].id)
	scene.tip_layer.advance()
	assert_bool(seen.has("new_enemy:%s" % first[0].id)).is_true()
	for i: int in range(1, first.size()):
		scene.pump_tips()
		scene.tip_layer.advance()
	# Then the "do" card: a spotlight on an empty pad, and only a tap there gets through.
	scene.pump_tips()
	assert_str(String(scene.tip_layer.current.def.id)).is_equal("first_build")
	var spot: Rect2 = scene.tip_layer.focus_rect()
	assert_float(spot.size.x).is_greater(0.0)
	scene.tip_layer.complete(&"unit_built")  # not the event it waits for
	assert_bool(scene.tip_layer.is_active()).is_true()
	scene.tip_layer.focus_pressed.emit(_press(spot.get_center()))
	assert_bool(scene.build_menu.is_open()).is_true()
	assert_bool(scene.tip_layer.is_active()).is_false()
	# Build, and the start button gets its card.
	scene.run.gold = 999
	scene.build_menu.build_requested.emit(scene.build_menu.plot, scene.config.units[0].id)
	scene.pump_tips()
	assert_str(String(scene.tip_layer.current.def.id)).is_equal("start_wave")
	assert_bool(scene.tip_layer.focus_rect().intersects(
			scene.build_bar.start_button.get_global_rect())).is_true()


func test_no_tip_opens_over_a_menu_and_none_repeats() -> void:
	var seen: Dictionary = {}
	scene.enable_tips(seen)
	scene.start_run(4242)
	scene.open_plot(_first_open_empty_plot())
	scene.pump_tips()
	assert_bool(scene.tip_layer.is_active()).is_false()
	scene.build_menu.close()
	var shown: Dictionary = {}
	for i: int in 12:
		scene.pump_tips()
		if not scene.tip_layer.is_active():
			break
		var key: String = scene.tip_layer.current.key()
		assert_bool(shown.has(key)).is_false()
		shown[key] = true
		if scene.tip_layer.current.def.id == &"first_build":
			scene.open_plot(scene.run.plots[0].index if scene.run.plot_open(0) else _first_open_empty_plot())
			scene.build_menu.close()
		else:
			scene.tip_layer.advance()
	scene.start_run(99)
	scene.pump_tips()
	assert_bool(scene.tip_layer.is_active()).is_false()


func test_a_crate_tip_stops_time_mid_wave() -> void:
	var seen: Dictionary = {}
	for t: TipDef in scene.config.tips:
		if t.trigger != &"crate_spawned" and t.trigger != &"boost_crate":
			seen[String(t.id)] = true
	for w: WaveDef in scene.config.waves:
		for entry: SpawnEntry in w.spawns:
			seen["new_enemy:%s" % entry.enemy.id] = true
	scene.enable_tips(seen)
	scene.start_wave()
	var spawned: Array = [false]
	scene.run.combat.crate_spawned.connect(func(_c: CombatSim.Crate) -> void: spawned[0] = true)
	_tick_until(func() -> bool: return spawned[0])
	scene.pump_tips()
	assert_bool(scene.tip_layer.is_active()).is_true()
	assert_array([&"crate_spawned", &"boost_crate"]).contains(
			[scene.tip_layer.current.def.trigger])
	assert_float(scene.tip_layer.focus_rect().size.x).is_greater(0.0)
	scene.tip_layer.freeze = 1.0
	scene._update_tips()
	assert_float(Engine.time_scale).is_less_equal(RunController.TIP_TIME_FLOOR)
	scene.tip_layer.advance()
	scene.tip_layer.freeze = 0.0
	scene._update_tips()
	assert_float(Engine.time_scale).is_equal(1.0)


func _first_open_empty_plot() -> int:
	for p: CombatSim.Plot in scene.run.plots:
		if p.is_empty() and scene.run.plot_open(p.index):
			return p.index
	return -1


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


func test_a_loss_offers_a_retry_and_a_win_the_next_sector() -> void:
	scene.start_wave()
	scene.run.wall_damage_taken = scene.run.wall_max() - 0.5
	_tick_until(func() -> bool: return scene.run.phase == Run.Phase.LOST, 60 * 60)
	assert_bool(scene.overlay.map_button.visible).is_false()
	assert_int(scene.overlay.stars.earned).is_equal(0)
	scene.overlay.restart_pressed.emit()
	assert_str(String(scene.config.map.id)).is_equal("outpost")
	assert_int(scene.run.phase).is_equal(Run.Phase.BUILD)
	# A win (forced here) offers sector 2, with stars by the gate left.
	scene.run.wall_damage_taken = scene.run.wall_max() * 0.3
	scene.run.phase = Run.Phase.WON
	scene._on_phase_changed(Run.Phase.WON)
	assert_bool(scene.overlay.map_button.visible).is_true()
	assert_int(scene.overlay.stars.earned).is_equal(2)
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
	# Shadows, mounds and bubbles (3) + a batch per type + the HP bar layer: never a node per
	# enemy.
	assert_int(scene.enemy_field.get_child_count()).is_less_equal(types.size() + 4)


## Stage 2 enemies in the real scene (the --showcase wave, behind an unbreakable gate): the
## view shows burrowers as mounds, shields as bubbles and Bombardiers' globs, in batches.
func test_the_stage2_enemies_render_mounds_bubbles_and_globs() -> void:
	var cfg: RunConfig = RunController.showcase_config(scene.config,
			PackedStringArray(["wasp", "warden", "burrower", "bombardier"]))
	cfg.wall_hp = 1e6
	scene.config = cfg
	scene.start_run(7)
	scene.start_wave()
	var seen := {"mound": false, "bubble": false, "lob": false, "flyer": false}
	for i: int in 60 * 70:
		scene.tick(1)
		if i % 10 != 0:
			continue
		scene.sync_views(1.0 / 6.0)
		seen["mound"] = seen["mound"] or scene.enemy_field.mound_count() > 0
		seen["bubble"] = seen["bubble"] or scene.enemy_field.bubble_count() > 0
		seen["lob"] = seen["lob"] or not scene.run.combat.lobs.is_empty()
		for e: CombatSim.Enemy in scene.run.combat.path_enemies[0] + scene.run.combat.path_enemies[1]:
			seen["flyer"] = seen["flyer"] or e.def.flying
	for k: String in seen:
		assert_bool(seen[k]).override_failure_message("never saw a %s" % k).is_true()


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
	scene.fx.popup("+100 VERY WIDE TEXT", Vector2(-50, 300), Color.WHITE, &"heading")
	scene.fx.popup("+100 VERY WIDE TEXT", Vector2(scene.config.playfield_width() + 50, 300),
			Color.WHITE, &"heading")
	for child: Node in scene.fx.get_children():
		if child is Label and (child as Label).visible:
			var l: Label = child
			assert_float(l.position.x).is_greater_equal(0.0)
			assert_float(l.position.x + l.size.x).is_less_equal(scene.config.playfield_width())


func test_the_ability_button_arms_and_the_next_tap_calls_it() -> void:
	assert_str(String(scene.run.ability.id)).is_equal("strike")  # a direct run's default
	scene.start_wave()
	scene.tick(1)
	scene.sync_views()
	assert_bool(scene.ability_button.visible).is_true()
	scene.toggle_ability()
	assert_bool(scene.aiming).is_true()
	assert_float(Engine.time_scale).is_equal(scene.config.build_menu_time_scale)
	var at := Vector2(270, 300)
	scene.handle_pointer(_press(_screen(at)))
	assert_bool(scene.aiming).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_int(scene.run.combat.casts.size()).is_equal(1)
	assert_bool(scene.run.ability_ready()).is_false()
	# Cooling down: the button does nothing.
	scene.toggle_ability()
	assert_bool(scene.aiming).is_false()


func test_the_ability_button_hides_between_waves() -> void:
	scene.sync_views()
	assert_bool(scene.ability_button.visible).is_false()


func test_every_ability_is_cast_and_lands_in_the_scene() -> void:
	for a: AbilityDef in scene.base_config.abilities:
		scene.start_run(4242)
		assert_bool(scene.run.choose_ability(a)).is_true()
		scene.start_wave()
		_tick_until(func() -> bool: return scene.run.combat.enemy_count() >= 3)
		var target: Vector2 = scene.run.combat.path_enemies.filter(
				func(g: Array) -> bool: return not g.is_empty())[0][0].pos()
		scene.toggle_ability()
		if a.targeted():
			assert_bool(scene.aiming).override_failure_message(String(a.id)).is_true()
			scene.handle_pointer(_press(_screen(target)))
		assert_bool(scene.aiming).is_false()
		assert_bool(scene.run.ability_ready()).override_failure_message(String(a.id)).is_false()
		var landed: Array = [false]
		scene.run.combat.ability_landed.connect(func(_c: CombatSim.Cast) -> void: landed[0] = true)
		scene.tick(roundi((a.delay + 0.1) * scene.config.tick_rate))
		scene.sync_views(0.1)
		assert_bool(landed[0]).override_failure_message("%s never landed" % a.id).is_true()


func test_a_hand_played_run_opens_with_the_pick_and_teaches_the_pick_once() -> void:
	var seen: Dictionary = {}
	scene.enable_tips(seen)
	scene.offer_pick = true
	scene.start_run(4242)
	assert_bool(scene.ability_picker.visible).is_true()
	assert_bool(scene.build_bar.visible).is_false()
	assert_object(scene.ability_picker.selected).is_same(scene.run.ability)
	scene.pump_tips()
	assert_bool(scene.tip_layer.is_active()).is_false()  # the pick comes first
	assert_bool(scene.ability_picker.pick(&"cryo_bomb")).is_true()
	assert_str(String(scene.run.ability.id)).is_equal("cryo_bomb")
	assert_bool(scene.ability_picker.visible).is_false()
	assert_bool(scene.build_bar.visible).is_true()
	scene.pump_tips()
	assert_str(scene.tip_layer.current.key()).is_equal("ability_intro:cryo_bomb")
	assert_int(scene.tip_layer.pages.size()).is_equal(2)
	assert_str(scene.tip_layer.pages[0].clip).is_equal(scene.run.ability.clip)
	scene.tip_layer.advance()
	scene.tip_layer.advance()
	assert_bool(seen.has("ability_intro:cryo_bomb")).is_true()
	# The next run offers it again, but it isn't taught twice.
	scene.start_run(4243)
	scene.ability_picker.pick(&"cryo_bomb")
	scene.pump_tips()
	var current: String = scene.tip_layer.current.key() if scene.tip_layer.is_active() else ""
	assert_str(current).is_not_equal("ability_intro:cryo_bomb")


## Regression (2026-09-29): the "How to use it" card's wrapping line had no width, so the card
## grew taller than the screen and looked like a black screen needing an extra tap.
func test_every_special_attack_tutorial_card_fits_on_screen() -> void:
	var view: float = scene.get_viewport_rect().size.y
	for a: AbilityDef in scene.base_config.abilities:
		var pages: Array[TipLayer.Page] = RunController.ability_pages(a)
		scene.tip_layer.show_tip(TipDirector.Pending.new(TipDef.new(), a.id), pages)
		for i: int in pages.size():
			assert_float(scene.tip_layer.card_height()).override_failure_message(
					"%s card %d is %d tall" % [a.id, i, scene.tip_layer.card_height()]) \
					.is_less(view * 0.6)
			if i + 1 < pages.size():
				scene.tip_layer.advance()
		scene.tip_layer.current = null


func test_two_units_in_range_link_and_the_card_lists_it() -> void:
	scene.run.gold = 999
	var a: int = -1
	var b: int = -1
	for p: CombatSim.Plot in scene.run.plots:
		for q: CombatSim.Plot in scene.run.plots:
			if a < 0 and p.index < q.index and scene.run.plot_open(p.index) \
					and scene.run.plot_open(q.index) \
					and p.position.distance_to(q.position) <= scene.config.synergy_range:
				a = p.index
				b = q.index
	assert_int(a).is_greater_equal(0)
	scene.enable_tips({})
	for key: String in ["new_enemy:grunt", "new_enemy:runner", "first_build", "start_wave"]:
		scene.tips.seen[key] = true
	scene.tips.clear_queue()
	assert_bool(scene.run.build(a, &"mortar")).is_true()
	assert_bool(scene.run.build(b, &"rail")).is_true()
	assert_bool(scene.run.plots[a].links.is_empty()).is_false()
	scene.open_plot(a)
	scene.build_menu.sync(scene.run)
	assert_bool(scene.build_menu._links.visible).is_true()
	assert_str(scene.build_menu._links.text).contains("Siege Battery")
	scene.build_menu.close()
	# The first link teaches itself.
	var found: bool = false
	for i: int in 6:
		scene.pump_tips()
		if not scene.tip_layer.is_active():
			break
		if scene.tip_layer.current.def.id == &"synergy":
			found = true
			break
		scene.tip_layer.advance()
	assert_bool(found).is_true()
