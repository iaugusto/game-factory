class_name CardPicker
extends Control
## Between waves: "Wave N cleared" and three cards to pick one from. Holds no rules; emits
## the chosen index for Run.pick_card.

signal picked(index: int)

var title: Label
var _cards: VBoxContainer
var _buttons: Array[Button] = []
var _t: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	title = UiTheme.label("", 34, UiTheme.ACCENT, 7)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiTheme.label("Choose a reinforcement", 17, UiTheme.TEXT_DIM, 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 12)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_cards)
	visible = false


func show_offer(cleared: int, total: int, offer: Array[CardDef]) -> void:
	title.text = "WAVE %d/%d CLEARED" % [cleared, total]
	for b: Button in _buttons:
		b.queue_free()
	_buttons.clear()
	for i: int in offer.size():
		var card: CardDef = offer[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(440, 86)
		UiTheme.style_button(b, false, 16, 14)
		var normal: StyleBoxFlat = b.get_theme_stylebox("normal")
		normal.border_color = Color(UiTheme.ACCENT, 0.5)
		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 18
		col.offset_right = -18
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(UiTheme.label(card.title, 22, UiTheme.ACCENT, 4))
		var d := UiTheme.label(card.description, 15, UiTheme.TEXT, 3)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(d)
		b.add_child(col)
		b.pressed.connect(func() -> void: _pick(i))
		_cards.add_child(b)
		_buttons.append(b)
	_t = 0.0
	visible = true


func _pick(index: int) -> void:
	visible = false
	picked.emit(index)


## Tests and autoplay pick without a pointer.
func pick(index: int) -> void:
	if visible and index >= 0 and index < _buttons.size():
		_pick(index)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for i: int in _buttons.size():
		var k: float = clampf((_t - i * 0.08) / 0.22, 0.0, 1.0)
		_buttons[i].modulate.a = k
		_buttons[i].position.x = (1.0 - k) * 40.0
