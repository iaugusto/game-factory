class_name CampaignScreen
extends Control
## Root of scenes/campaign.tscn, the main scene: the campaign of sectors (RunConfig.maps, in
## order) with the stars earned on each, a lock on those not yet reached, and the skill tree.
## Holds no rules: unlocks and stars come from Campaign, the tree from SkillTree, both in the
## save that Session owns (docs/2026-09-27-sectors-and-skill-tree/).
##
## With run arguments on the command line (--map, --seed, --autoplay, …) it goes straight to
## the run scene, so captures, perf runs and the documented commands still start a run.
## `--open-tree` (DEV ONLY) opens the skill tree at start, for screenshots.

const CONFIG_PATH: String = "res://data/run_config.tres"

var config: RunConfig
var stars_label: Label
var tree_button: Button
var tree_panel: SkillTreePanel
## One entry per sector: its PLAY button (disabled while locked).
var play_buttons: Array[Button] = []
## Tips for the campaign (the first visit, stars to spend) and the layer that shows them.
var tips := TipDirector.new()
var tip_layer: TipLayer
## The settings card (tips on/off, replay tips) and its toggle.
var settings: PanelContainer
var tips_button: Button
var _list: VBoxContainer
## Frames to wait before showing a tip, so the layout (and every spotlight) has settled.
var _tip_wait: int = 2


func _ready() -> void:
	if config != null:
		return  # built already (tests build before adding)
	var args: Dictionary = RunController.parse_args(OS.get_cmdline_user_args())
	if Session.wants_direct_run(args):
		get_tree().change_scene_to_file.call_deferred(Session.RUN_SCENE)
		return
	build(load(CONFIG_PATH))
	if args.has("open-tree"):
		open_tree()


## Build the screen for `cfg` from Session's save (public so tests can build it directly).
func build(cfg: RunConfig) -> void:
	config = cfg
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiTheme.look.backdrop
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 26)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := UiTheme.label("HOLD THE GATE", &"display", UiTheme.look.title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiTheme.label("CAMPAIGN", &"body", UiTheme.look.text_dim)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var total_row := HBoxContainer.new()
	total_row.alignment = BoxContainer.ALIGNMENT_CENTER
	total_row.add_theme_constant_override("separation", 8)
	total_row.add_child(UiTheme.icon("ui/star", 30))
	stars_label = UiTheme.label("", &"label", UiTheme.look.coin)
	total_row.add_child(stars_label)
	box.add_child(total_row)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_list)
	tree_button = Button.new()
	tree_button.custom_minimum_size = Vector2(0, 62)
	UiTheme.style_button(tree_button, false, &"label")
	tree_button.pressed.connect(open_tree)
	box.add_child(tree_button)
	tree_panel = SkillTreePanel.new()
	tree_panel.changed.connect(refresh)
	add_child(tree_panel)
	_build_settings()
	tips.tips = cfg.tips
	tips.seen = Session.profile().tips_seen
	tips.enabled = not Session.profile().tips_off
	tip_layer = TipLayer.new()
	tip_layer.finished.connect(func(p: TipDirector.Pending) -> void:
		tips.done(p)
		Session.persist())
	add_child(tip_layer)
	refresh()
	tips.notify(&"campaign_open")


## Rebuild the sector cards and the star counts from the save.
func refresh() -> void:
	var save: SaveData = Session.profile()
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.free()
	play_buttons.clear()
	for i: int in config.maps.size():
		_list.add_child(_sector_card(i, save.campaign))
	var total: int = save.campaign.stars_total()
	stars_label.text = "%d / %d" % [total, config.maps.size() * 3]
	var free: int = save.stars_free(config.skill_tree)
	tree_button.text = "SKILL TREE  ·  %d %s to spend" % [free, "star" if free == 1 else "stars"] \
			if free > 0 else "SKILL TREE"
	UiTheme.style_button(tree_button, free > 0, &"label")
	if free > 0:
		tips.notify(&"stars_to_spend")


func _process(_delta: float) -> void:
	if _tip_wait > 0:
		_tip_wait -= 1
		return
	pump_tips()


## Show the next waiting tip unless the tree or settings are open. Public for tests.
func pump_tips() -> void:
	if tip_layer == null or tip_layer.is_active() or tree_panel.visible or settings.visible:
		return
	var p: TipDirector.Pending = tips.pending()
	if p == null:
		return
	var pages: Array[TipLayer.Page] = []
	for c: TipCard in p.def.cards:
		var pg := TipLayer.Page.new()
		pg.title = c.title
		pg.body = c.body
		if c.icon != "":
			pg.picture = UiTheme.icon(c.icon, 64)
		match c.focus:
			&"sector_play":
				for b: Button in play_buttons:
					if not b.disabled:
						pg.focus = b.get_global_rect().grow(6)
						break
			&"skill_tree":
				pg.focus = tree_button.get_global_rect().grow(6)
		pages.append(pg)
	tip_layer.show_tip(p, pages)


## The ⚙ corner button and its card: tips on or off, and replaying every tip.
func _build_settings() -> void:
	var gear := Button.new()
	gear.text = "⚙"
	gear.custom_minimum_size = Vector2(48, 48)
	UiTheme.style_button(gear, false, &"label")
	gear.anchor_left = 1.0
	gear.anchor_right = 1.0
	gear.offset_left = -48 - 14
	gear.offset_right = -14
	gear.offset_top = 14
	gear.offset_bottom = 14 + 48
	gear.pressed.connect(func() -> void: settings.visible = not settings.visible)
	add_child(gear)
	settings = PanelContainer.new()
	settings.add_theme_stylebox_override("panel", UiTheme.panel(Color(0, 0, 0, 0), -1,
			Color(UiTheme.look.title, 0.3), 2))
	settings.anchor_left = 1.0
	settings.anchor_right = 1.0
	settings.offset_left = -14 - 260
	settings.offset_right = -14
	settings.offset_top = 14 + 48 + 8
	add_child(settings)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	settings.add_child(box)
	box.add_child(UiTheme.label("SETTINGS", &"label", UiTheme.look.title))
	tips_button = Button.new()
	tips_button.custom_minimum_size = Vector2(236, 46)
	tips_button.pressed.connect(func() -> void: set_tips_on(Session.profile().tips_off))
	box.add_child(tips_button)
	var replay := Button.new()
	replay.text = "REPLAY ALL TIPS"
	replay.custom_minimum_size = Vector2(236, 46)
	UiTheme.style_button(replay, false, &"body")
	replay.pressed.connect(replay_tips)
	box.add_child(replay)
	settings.visible = false
	_sync_tips_button()


## Tips on or off for every run from now on (saved).
func set_tips_on(on: bool) -> void:
	Session.profile().tips_off = not on
	tips.enabled = on
	if not on:
		tips.clear_queue()
	Session.persist()
	_sync_tips_button()


## Forget every tip read, so each shows again when it next applies (saved).
func replay_tips() -> void:
	Session.profile().tips_seen.clear()
	Session.persist()
	set_tips_on(true)
	tips.notify(&"campaign_open")


func _sync_tips_button() -> void:
	var on: bool = not Session.profile().tips_off
	tips_button.text = "TIPS: ON" if on else "TIPS: OFF"
	UiTheme.style_button(tips_button, on, &"body")


func open_tree() -> void:
	tree_panel.open(config.skill_tree)


## Start sector `index` (a campaign run: its result is recorded).
func play(index: int) -> void:
	if Session.profile().campaign.is_unlocked(config.maps, index):
		Session.goto_run(config.maps[index].id)


func _sector_card(index: int, campaign: Campaign) -> Control:
	var m: MapDef = config.maps[index]
	var open: bool = campaign.is_unlocked(config.maps, index)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(Color(0, 0, 0, 0), -1,
			Color(UiTheme.look.action, 0.45) if open else Color(0, 0, 0, 0), 2 if open else -1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var thumb := TextureRect.new()
	thumb.texture = Art.tex("field/ground_%s" % m.id)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.custom_minimum_size = Vector2(96, 150)
	thumb.modulate = Color.WHITE if open else Color(0.35, 0.35, 0.38)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(thumb)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	col.add_child(UiTheme.label("SECTOR %d" % (index + 1), &"caption", UiTheme.look.text_dim))
	col.add_child(UiTheme.label(m.display_name, &"label",
			UiTheme.look.text if open else UiTheme.look.text_dim))
	var stars: int = campaign.stars_at(m.id)
	var star_row := StarRow.make(stars, 30.0)
	star_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_child(star_row)
	var play_button := Button.new()
	play_button.custom_minimum_size = Vector2(0, 48)
	if open:
		play_button.text = "REPLAY" if campaign.cleared.has(m.id) else "PLAY  ▶"
		UiTheme.style_button(play_button, not campaign.cleared.has(m.id), &"body")
	else:
		play_button.text = "LOCKED: win sector %d" % index
		UiTheme.style_button(play_button, false, &"caption")
		play_button.disabled = true
	play_button.pressed.connect(func() -> void: play(index))
	col.add_child(play_button)
	play_buttons.append(play_button)
	return panel
