class_name PhaseOverlay
extends Control
## The end-of-run screen: victory, or the gate fell; waves cleared, bricks earned, play again.
## After a loss it fades in once the breach moment has played (show_result's `delay`).
## (Between-wave screens are CardPicker and BuildBar.)

const FADE_TIME: float = 0.35

signal restart_pressed
## Play the other map (shown when RunConfig.maps has more than one).
signal next_map_pressed

var title: Label
var body: Label
var button: Button
var map_button: Button
## Real seconds before the fade-in starts, then the fade's progress.
var _delay: float = 0.0
var _fade: float = 1.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PANEL, 18,
			Color(UiTheme.ACCENT, 0.45), 2))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	title = UiTheme.label("", 40, UiTheme.ACCENT, 7)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	body = UiTheme.label("", 19, UiTheme.TEXT, 4)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	button = Button.new()
	button.custom_minimum_size = Vector2(0, 58)
	UiTheme.style_button(button, true, 24)
	button.text = "PLAY AGAIN"
	button.pressed.connect(func() -> void:
		visible = false
		restart_pressed.emit())
	box.add_child(button)
	map_button = Button.new()
	map_button.custom_minimum_size = Vector2(0, 48)
	UiTheme.style_button(map_button, false, 18)
	map_button.pressed.connect(func() -> void:
		visible = false
		next_map_pressed.emit())
	box.add_child(map_button)
	visible = false


## Show the result; with `delay` > 0 (real seconds) it stays transparent and unclickable until
## then, and fades in.
## `other_map`: the name of the map "PLAY <map>" switches to ("" hides the button).
func show_result(won: bool, cleared: int, total: int, bricks: int, delay: float = 0.0,
		other_map: String = "") -> void:
	map_button.visible = other_map != ""
	map_button.text = "PLAY %s  ▶" % other_map.to_upper()
	title.text = "VICTORY" if won else "THE GATE FELL"
	title.add_theme_color_override("font_color", UiTheme.GOOD if won else UiTheme.BAD)
	body.text = "Waves cleared: %d/%d\nBricks earned: %d" % [cleared, total, bricks]
	visible = true
	_delay = delay
	_fade = 1.0 if delay <= 0.0 else 0.0
	_apply_fade()


func _process(delta: float) -> void:
	if not visible or _fade >= 1.0:
		return
	var real: float = delta / maxf(Engine.time_scale, 0.001)
	if _delay > 0.0:
		_delay -= real
		return
	_fade = minf(1.0, _fade + real / FADE_TIME)
	_apply_fade()


func _apply_fade() -> void:
	modulate.a = _fade
	button.disabled = _fade < 1.0
	map_button.disabled = _fade < 1.0


func is_result() -> bool:
	return visible
