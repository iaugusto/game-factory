class_name BarricadeMenu
extends Control
## The card that opens on a barricade slot: build the barricade here, move it here (between
## waves, free), upgrade it (up to level 3) or repair it. It holds no rules: it asks Run for
## prices and emits requests; RunController calls Run.
##
## It covers the screen so a tap anywhere else closes it.

signal build_requested(slot: int)
signal upgrade_requested
signal repair_requested
signal closed

var slot: int = -1
var title: Label
var info: Label
var build_button: Button
var upgrade_button: Button
var repair_button: Button
var _card: PanelContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PANEL, 12,
			Color(UiTheme.ACCENT, 0.35), 1))
	_card.custom_minimum_size = Vector2(220, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_card.add_child(box)
	title = UiTheme.label("BARRICADE", 17, UiTheme.ACCENT, 4)
	box.add_child(title)
	info = UiTheme.label("", 13, UiTheme.TEXT_DIM, 3)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(196, 0)
	box.add_child(info)
	build_button = _button(box, true, func() -> void: build_requested.emit(slot))
	upgrade_button = _button(box, true, func() -> void: upgrade_requested.emit())
	repair_button = _button(box, false, func() -> void: repair_requested.emit())
	visible = false


static func _button(box: Container, primary: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(196, 42)
	UiTheme.style_button(b, primary, 15)
	b.pressed.connect(on_press)
	box.add_child(b)
	return b


func is_open() -> bool:
	return visible


func open(index: int, screen_pos: Vector2, run: Run) -> void:
	slot = index
	visible = true
	sync(run)
	_card.reset_size()
	var view: Vector2 = get_viewport_rect().size
	# Above the slot (the slots sit low, near the wall).
	_card.position = Vector2(clampf(screen_pos.x - _card.size.x / 2.0, 8.0, view.x - _card.size.x - 8.0),
			maxf(Hud.HEIGHT + 8.0, screen_pos.y - _card.size.y - 34.0))


func close() -> void:
	if not visible:
		return
	visible = false
	slot = -1
	closed.emit()


## Refresh what can be done here and what it costs.
func sync(run: Run) -> void:
	if not visible:
		return
	var b: CombatSim.Barricade = run.barricade()
	var cost: int = run.barricade_cost()
	var here: bool = b.is_built() and b.slot == slot
	var max_level: int = run.config.barricade.max_level()
	build_button.visible = not here
	if not b.is_built():
		title.text = "BARRICADE"
		info.text = "Enemies on the paths through here stop to break it: a kill zone. Only one; move it between waves."
		build_button.text = "BUILD  ● %d" % cost
		build_button.disabled = cost < 0 or run.gold < cost or not run.can_spend()
	elif not here:
		title.text = "BARRICADE"
		info.text = "Move the barricade here (between waves, free)."
		build_button.text = "MOVE HERE"
		build_button.disabled = run.phase != Run.Phase.BUILD
	else:
		title.text = "BARRICADE  ·  Lv %d/%d" % [b.level, max_level]
		info.text = "HP %d / %d%s" % [ceili(b.hp), roundi(b.max_hp),
				"  ·  BROKEN" if not b.is_standing() else ""]
	upgrade_button.visible = here
	if here:
		upgrade_button.text = "UPGRADE  ● %d" % cost if cost >= 0 else "MAX LEVEL"
		upgrade_button.disabled = cost < 0 or run.gold < cost or not run.can_spend()
	var repair: int = run.barricade_repair_cost()
	repair_button.visible = here
	if here:
		repair_button.text = "REPAIR  ● %d" % repair if repair >= 0 else "FULL HP"
		repair_button.disabled = repair < 0 or run.gold < repair or not run.can_spend()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		accept_event()
		close()
