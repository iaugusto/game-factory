class_name AbilityPicker
extends Control
## When a map starts: pick the special attack to take into it. One card per attack in the
## config (icon, name, one line, and its numbers); the unlocked ones can be chosen, the locked
## ones say which sector unlocks them. The last pick is preselected, so a returning player
## just confirms. Holds no rules: emits the chosen AbilityDef for Run.choose_ability.

signal chosen(ability: AbilityDef)

const CARD_WIDTH: float = 460.0
const CARD_HEIGHT: float = 100.0

var confirm_button: Button
## The attack selected now (the one DEPLOY confirms).
var selected: AbilityDef = null
var _cards: VBoxContainer
var _buttons: Array[Button] = []
var _defs: Array[AbilityDef] = []
var _t: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiTheme.dim())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	var title := UiTheme.label("Special attack", &"heading", UiTheme.look.title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiTheme.label("Take one into this sector", &"body", UiTheme.look.text_dim)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_cards)
	confirm_button = Button.new()
	confirm_button.custom_minimum_size = Vector2(0, 56)
	confirm_button.text = "DEPLOY"
	UiTheme.style_button(confirm_button, true, &"label")
	confirm_button.pressed.connect(confirm)
	box.add_child(confirm_button)
	visible = false


## Show `all` attacks; those in `unlocked` can be picked. `preselect` is the default pick (the
## first unlocked if it isn't one). `fresh`: ids to badge NEW. `unlock_names`: map id -> the
## sector's name, for the locked cards.
func open(all: Array[AbilityDef], unlocked: Array[AbilityDef], preselect: StringName,
		fresh: Dictionary = {}, unlock_names: Dictionary = {}) -> void:
	for b: Button in _buttons:
		_cards.remove_child(b)
		b.free()
	_buttons.clear()
	_defs.clear()
	selected = null
	for a: AbilityDef in all:
		var open_: bool = unlocked.has(a)
		var b := _card(a, open_, fresh.has(a.id),
				String(unlock_names.get(a.unlocked_by, String(a.unlocked_by).capitalize())))
		b.disabled = not open_
		b.pressed.connect(func() -> void: select(a))
		_cards.add_child(b)
		_buttons.append(b)
		_defs.append(a)
		if open_ and (selected == null or a.id == preselect):
			selected = a
	_restyle()
	_t = 0.0
	visible = true


## Select `a` (a tap on its card).
func select(a: AbilityDef) -> void:
	var i: int = _defs.find(a)
	if i < 0 or _buttons[i].disabled:
		return
	selected = a
	_restyle()


## Take the selected attack (the DEPLOY button).
func confirm() -> void:
	if not visible or selected == null:
		return
	visible = false
	chosen.emit(selected)


## Tests and dev runs pick without a pointer: select `id` and confirm. False if it can't be.
func pick(id: StringName) -> bool:
	for a: AbilityDef in _defs:
		if a.id == id:
			select(a)
			if selected == a:
				confirm()
				return true
	return false


func close() -> void:
	visible = false


## The cards' area on screen (a tip could spotlight it).
func cards_rect() -> Rect2:
	return _cards.get_global_rect()


## An attack's numbers in one line, for its card and its tutorial.
static func summary(a: AbilityDef) -> String:
	var reload: String = "reload %ds" % roundi(a.cooldown)
	match a.kind:
		AbilityDef.Kind.STRIKE:
			return "%d damage in the blast · %s" % [roundi(a.damage), reload]
		AbilityDef.Kind.FREEZE:
			return "Frozen %ss, then slowed %ss · %s" % [_num(a.duration), _num(a.slow_time),
					reload]
		AbilityDef.Kind.BURN:
			return "%d damage a second along the road for %ss · %s" % [roundi(a.damage),
					_num(a.duration), reload]
		AbilityDef.Kind.MINES:
			return "%d mines, %d damage each · %s" % [a.mine_count, roundi(a.damage), reload]
		AbilityDef.Kind.REPAIR:
			return "+%d gate, +%d%s units · %s" % [roundi(a.gate_heal), roundi(a.unit_heal * 100.0),
					"%", reload]
	return reload


## "3" for 3.0, "2.5" for 2.5.
static func _num(x: float) -> String:
	return str(snappedf(x, 0.1)).trim_suffix(".0")


func _card(a: AbilityDef, open_: bool, fresh: bool, unlock_name: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	UiTheme.style_button(b, false, &"body", 14)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -14
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := UiTheme.icon(a.icon, 60)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = Color.WHITE if open_ else Color(1, 1, 1, 0.3)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(UiTheme.label(a.display_name, &"label",
			UiTheme.look.title if open_ else UiTheme.look.text_dim))
	if fresh and open_:
		head.add_child(UiTheme.label("  NEW", &"caption", UiTheme.look.action))
	var line: String = a.description if open_ else "Win %s to unlock" % unlock_name
	var d := UiTheme.label(line, &"caption", UiTheme.look.text if open_ else UiTheme.look.text_dim)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(d)
	if open_:
		col.add_child(UiTheme.label(summary(a), &"caption", UiTheme.look.coin))
	return b


## The selected card gets the action border; the rest a hairline.
func _restyle() -> void:
	for i: int in _buttons.size():
		var on: bool = _defs[i] == selected
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var box: StyleBoxFlat = _buttons[i].get_theme_stylebox(state)
			if box == null:
				continue
			box = box.duplicate()
			box.border_color = UiTheme.look.action if on else Color(UiTheme.look.action, 0.15)
			box.set_border_width_all(4 if on else 1)
			_buttons[i].add_theme_stylebox_override(state, box)
	confirm_button.disabled = selected == null
	confirm_button.text = "DEPLOY %s" % selected.short_name if selected != null else "DEPLOY"


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for i: int in _buttons.size():
		var k: float = clampf((_t - i * 0.06) / 0.22, 0.0, 1.0)
		_buttons[i].modulate.a = k
		_buttons[i].position.x = (1.0 - k) * 40.0
