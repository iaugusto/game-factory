class_name IntelCard
extends Control
## "New threat": shown in the build phase before the wave in which an enemy type first appears
## (WaveSchedule.new_enemies). Its picture, name, what it does, and the counter chart as unit
## icons: which units it is weak to and which it shrugs off. The Doom-style "know your weapon"
## lesson, taught before the fight. A tap anywhere closes it.

signal dismissed

var title: Label
var _list: VBoxContainer
## Enemy ids on the card now (for tests).
var shown: Array[StringName] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PANEL, 16,
			Color(UiTheme.BAD, 0.55), 2))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	title = UiTheme.label("NEW THREAT", 26, UiTheme.BAD, 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_list)
	var hint := UiTheme.label("Tap to continue", 13, UiTheme.TEXT_DIM, 3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	visible = false


func show_enemies(cfg: RunConfig, enemies: Array[EnemyDef]) -> void:
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.free()  # at once: a queued free would linger as an orphan
	shown.clear()
	for e: EnemyDef in enemies:
		shown.append(e.id)
		_list.add_child(_entry(cfg, e))
	title.text = "NEW THREAT" if enemies.size() == 1 else "NEW THREATS"
	visible = not enemies.is_empty()


func close() -> void:
	if visible:
		visible = false
		dismissed.emit()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		accept_event()
		close()


func _entry(cfg: RunConfig, e: EnemyDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(EnemyIcon.make(e, 72))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var name_label := UiTheme.label(e.display_name.to_upper(), 20, UiTheme.TEXT, 4)
	col.add_child(name_label)
	var desc := UiTheme.label(e.description, 14, UiTheme.TEXT_DIM, 3)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	col.add_child(desc)
	col.add_child(_unit_row("WEAK TO", Counters.units_strong_vs(cfg, e), UiTheme.GOOD))
	var bad: Array[UnitDef] = Counters.units_weak_vs(cfg, e)
	if not bad.is_empty():
		col.add_child(_unit_row("SHRUGS OFF", bad, UiTheme.BAD))
	return row


static func _unit_row(caption: String, units: Array[UnitDef], color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.label(caption, 12, color, 3)
	l.custom_minimum_size = Vector2(82, 0)
	row.add_child(l)
	for u: UnitDef in units:
		var icon := UnitIcon.new()
		icon.unit = u
		icon.custom_minimum_size = Vector2(30, 30)
		icon.tooltip_text = u.display_name
		row.add_child(icon)
	return row
