class_name SkillTreePanel
extends Control
## The skill tree, over the campaign screen: one column per branch, its nodes top tier first.
## A tap selects a node and shows what it does; BUY spends its stars (the tier above must be
## owned); RESET gives every star back, free (research §3: a free respec invites trying builds).
## Holds no rules: SkillTree decides, Session's save holds the result and is written on change.

signal changed
signal closed

const NODE_SIZE := Vector2(156, 84)

var tree: SkillTreeDef
var stars_label: Label
var info_title: Label
var info_body: Label
var buy_button: Button
var reset_button: Button
## Node id -> its button.
var node_buttons: Dictionary[StringName, Button] = {}
var selected: SkillDef = null
var _columns: HBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := UiTheme.dim(1.0)
	dim.color = UiTheme.look.backdrop
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.label("SKILL TREE", &"heading", UiTheme.look.title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(52, 52)
	UiTheme.style_button(close_button, false, &"label")
	close_button.pressed.connect(close)
	head.add_child(close_button)
	var stars_row := HBoxContainer.new()
	stars_row.add_theme_constant_override("separation", 8)
	stars_row.add_child(UiTheme.icon("ui/star", 26))
	stars_label = UiTheme.label("", &"label", UiTheme.look.text)
	stars_row.add_child(stars_label)
	box.add_child(stars_row)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 8)
	_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_columns)
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.look.panel_raised, 12))
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(info)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	info.add_child(info_box)
	info_title = UiTheme.label("", &"label", UiTheme.look.title)
	info_box.add_child(info_title)
	info_body = UiTheme.label("", &"body", UiTheme.look.text)
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_box.add_child(info_body)
	buy_button = Button.new()
	buy_button.custom_minimum_size = Vector2(0, 54)
	buy_button.pressed.connect(func() -> void:
		if selected != null:
			buy(selected.id))
	info_box.add_child(buy_button)
	reset_button = Button.new()
	reset_button.text = "RESET  (free: every star comes back)"
	reset_button.custom_minimum_size = Vector2(0, 46)
	UiTheme.style_button(reset_button, false, &"body")
	reset_button.pressed.connect(reset)
	box.add_child(reset_button)
	visible = false


func open(skill_tree: SkillTreeDef) -> void:
	tree = skill_tree
	for child: Node in _columns.get_children():
		_columns.remove_child(child)
		child.free()
	node_buttons.clear()
	for b: int in tree.branch_titles.size():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		_columns.add_child(col)
		var head := UiTheme.label(tree.branch_titles[b], &"caption", UiTheme.look.text_dim)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(head)
		for s: SkillDef in tree.branch_skills(b):
			var button := Button.new()
			button.custom_minimum_size = NODE_SIZE
			button.clip_text = true
			var inner := VBoxContainer.new()
			inner.set_anchors_preset(Control.PRESET_FULL_RECT)
			inner.alignment = BoxContainer.ALIGNMENT_CENTER
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var name_label := UiTheme.label(s.title, &"body", UiTheme.look.text)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			inner.add_child(name_label)
			var cost_row := StarRow.make(s.cost, 16.0, s.cost)
			inner.add_child(cost_row)
			button.add_child(inner)
			var id: StringName = s.id
			button.pressed.connect(func() -> void: select(id))
			col.add_child(button)
			node_buttons[s.id] = button
	selected = null
	visible = true
	refresh()


func close() -> void:
	visible = false
	closed.emit()


func select(skill_id: StringName) -> void:
	selected = tree.skill_by_id(skill_id)
	refresh()


## Buy `skill_id` with the save's stars; saves on success.
func buy(skill_id: StringName) -> bool:
	var save: SaveData = Session.profile()
	var s: SkillDef = tree.skill_by_id(skill_id)
	if s == null or not save.tree.buy(tree, s, save.campaign.stars_total()):
		return false
	Session.persist()
	refresh()
	changed.emit()
	return true


func reset() -> void:
	Session.profile().tree.reset()
	Session.persist()
	refresh()
	changed.emit()


## Restyle every node from the save: owned (teal), buyable (amber), reachable but too dear
## (steel), locked behind the tier above (dark).
func refresh() -> void:
	var save: SaveData = Session.profile()
	var stars: int = save.campaign.stars_total()
	var free: int = stars - save.tree.spent(tree)
	stars_label.text = "%d to spend   (%d earned)" % [free, stars]
	for s: SkillDef in tree.skills:
		var button: Button = node_buttons[s.id]
		var owned: bool = save.tree.has(s.id)
		var reachable: bool = save.tree.is_reachable(tree, s)
		var bg: Color = UiTheme.look.panel_raised
		var border := UiTheme.look.line
		if owned:
			bg = Color(UiTheme.look.owned, 0.28)
			border = UiTheme.look.owned
		elif reachable and free >= s.cost:
			border = UiTheme.look.action
		elif not reachable:
			bg = UiTheme.look.panel.darkened(0.3)
		var style := UiTheme.panel(bg, -1, border, 3 if s == selected else 2)
		if s == selected:
			style.border_color = Color.WHITE
		for state: String in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)
		button.focus_mode = Control.FOCUS_NONE
		button.modulate = Color(1, 1, 1, 1.0 if reachable or owned else 0.55)
	_refresh_info(save, free)


func _refresh_info(save: SaveData, free: int) -> void:
	if selected == null:
		info_title.text = "Earn stars in sectors"
		info_body.text = "Each sector gives up to 3 stars: win it, and keep the gate above 50% " \
				+ "and 90%. Tap a skill to see it. Each branch opens from the top."
		buy_button.visible = false
		return
	info_title.text = selected.title
	info_body.text = selected.description
	buy_button.visible = true
	if save.tree.has(selected.id):
		buy_button.text = "OWNED"
		buy_button.disabled = true
		UiTheme.style_button(buy_button, false, &"label")
	elif not save.tree.is_reachable(tree, selected):
		buy_button.text = "Needs %s first" % tree.at(selected.branch, selected.tier - 1).title
		buy_button.disabled = true
		UiTheme.style_button(buy_button, false, &"body")
	else:
		buy_button.text = "BUY  (%d %s)" % [selected.cost, "star" if selected.cost == 1 else "stars"]
		buy_button.disabled = free < selected.cost
		UiTheme.style_button(buy_button, true, &"label")
