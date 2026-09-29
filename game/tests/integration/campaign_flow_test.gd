extends GdUnitTestSuite
## The campaign loop (B3's "run → meta → better run"): the campaign screen reads the save,
## the skill tree spends its stars, and a run launched from the campaign plays with the tree
## and records its stars back into the save file. Session is pointed at a temporary save, so
## the player's real save is never touched.

const CONFIG_PATH: String = "res://data/run_config.tres"
const RUN_SCENE: String = "res://scenes/run.tscn"

var path: String
var cfg: RunConfig


func before_test() -> void:
	path = create_temp_dir("campaign") + "/save.json"
	Session.use_save(SaveData.new(), path)
	cfg = load(CONFIG_PATH)


func after_test() -> void:
	Session.active = false
	Session.map_id = &""
	Session.use_save(null, SaveData.DEFAULT_PATH)
	Engine.time_scale = 1.0
	clean_temp_dir()


func _screen() -> CampaignScreen:
	var screen := CampaignScreen.new()
	screen.build(cfg)
	add_child(screen)
	return auto_free(screen)


func _win(map_id: StringName, gate: float) -> void:
	Session.profile().record_result(map_id, true, 10, gate, cfg)


func test_a_fresh_campaign_opens_sector_one_only() -> void:
	var screen := _screen()
	assert_int(screen.play_buttons.size()).is_equal(cfg.maps.size())
	assert_int(cfg.maps.size()).is_equal(3)
	assert_bool(screen.play_buttons[0].disabled).is_false()
	assert_bool(screen.play_buttons[1].disabled).is_true()
	assert_bool(screen.play_buttons[2].disabled).is_true()
	assert_str(screen.stars_label.text).is_equal("0 / 9")


func test_winning_a_sector_unlocks_the_next_and_its_stars_show() -> void:
	_win(cfg.maps[0].id, 0.6)
	var screen := _screen()
	assert_bool(screen.play_buttons[1].disabled).is_false()
	assert_bool(screen.play_buttons[2].disabled).is_true()
	assert_str(screen.stars_label.text).is_equal("2 / 9")
	assert_str(screen.tree_button.text).contains("2 stars to spend")


func test_the_tree_spends_stars_saves_and_resets() -> void:
	_win(cfg.maps[0].id, 0.6)  # 2 stars
	var screen := _screen()
	screen.open_tree()
	var panel: SkillTreePanel = screen.tree_panel
	assert_bool(panel.visible).is_true()
	assert_bool(panel.buy(&"sharpshooters")).is_false()  # needs Drill first
	assert_bool(panel.buy(&"drill")).is_true()
	assert_bool(panel.buy(&"sharpshooters")).is_true()
	assert_bool(panel.buy(&"thick_walls")).is_false()  # no stars left
	# Saved to disk as it happened.
	var on_disk := SaveData.load_from(path)
	assert_bool(on_disk.tree.has(&"drill")).is_true()
	assert_bool(on_disk.tree.has(&"sharpshooters")).is_true()
	panel.reset()
	assert_int(SaveData.load_from(path).tree.spent(cfg.skill_tree)).is_equal(0)
	assert_str(screen.tree_button.text).contains("2 stars to spend")


func test_a_campaign_run_plays_with_the_tree_and_records_its_stars() -> void:
	_win(cfg.maps[0].id, 0.2)  # 1 star, sector 2 open
	Session.profile().tree.buy(cfg.skill_tree, cfg.skill_tree.skill_by_id(&"thick_walls"), 1)
	Session.active = true
	Session.map_id = cfg.maps[1].id
	var scene: RunController = auto_free(load(RUN_SCENE).instantiate())
	add_child(scene)
	scene.set_physics_process(false)
	scene.set_process(false)
	assert_str(String(scene.config.map.id)).is_equal(String(cfg.maps[1].id))
	assert_bool(scene.records).is_true()
	assert_float(scene.run.wall_max()).is_equal(cfg.wall_hp + 40.0)
	# The pick offers what the campaign unlocked (sector 1 won: its attack too), starting on the
	# last pick; a pick is saved as the next default.
	assert_bool(scene.ability_picker.visible).is_true()
	var pool: Array[AbilityDef] = scene.ability_pool()
	assert_array(pool).is_equal(Session.profile().campaign.abilities_unlocked(cfg))
	assert_bool(pool.size() > 2).is_true()
	assert_str(String(scene.run.ability.id)).is_equal(String(Session.profile().last_ability))
	assert_bool(scene.ability_picker.pick(pool[2].id)).is_true()
	assert_str(String(SaveData.load_from(path).last_ability)).is_equal(String(pool[2].id))
	# Win it with the gate at 95% (forced): 3 stars recorded and saved.
	scene.run.wall_damage_taken = scene.run.wall_max() * 0.05
	scene.run.waves_cleared = scene.run.wave_count()
	scene.run.phase = Run.Phase.WON
	scene._on_phase_changed(Run.Phase.WON)
	var on_disk := SaveData.load_from(path)
	assert_int(on_disk.campaign.stars_at(cfg.maps[1].id)).is_equal(3)
	assert_bool(on_disk.campaign.cleared.has(cfg.maps[1].id)).is_true()
	assert_int(on_disk.runs).is_equal(2)
	assert_str(scene.overlay.note.text).contains("NEW BEST  +3 stars")
	# The overlay offers sector 3 next; going there keeps the run recorded on it.
	assert_bool(scene.overlay.map_button.visible).is_true()
	scene.overlay.next_map_pressed.emit()
	assert_str(String(Session.map_id)).is_equal(String(cfg.maps[2].id))


func test_a_direct_run_records_nothing() -> void:
	var scene: RunController = auto_free(load(RUN_SCENE).instantiate())
	add_child(scene)
	scene.set_physics_process(false)
	scene.set_process(false)
	assert_bool(scene.records).is_false()
	scene.run.phase = Run.Phase.WON
	scene._on_phase_changed(Run.Phase.WON)
	assert_bool(FileAccess.file_exists(path)).is_false()


func test_the_first_visit_shows_a_tip_once_and_tips_can_be_turned_off() -> void:
	var screen := _screen()
	screen.pump_tips()
	assert_bool(screen.tip_layer.is_active()).is_true()
	assert_str(String(screen.tip_layer.current.def.id)).is_equal("campaign")
	screen.tip_layer.advance()
	assert_bool(Session.profile().tips_seen.has("campaign")).is_true()
	# Saved: a fresh screen on the same save shows nothing.
	var again := _screen()
	again.pump_tips()
	assert_bool(again.tip_layer.is_active()).is_false()
	# Replay brings it back; off keeps everything quiet, and is saved too.
	again.replay_tips()
	again.pump_tips()
	assert_bool(again.tip_layer.is_active()).is_true()
	again.tip_layer.advance()
	again.set_tips_on(false)
	assert_bool(SaveData.load_from(path).tips_off).is_true()
	again.replay_tips()
	assert_bool(Session.profile().tips_off).is_false()
