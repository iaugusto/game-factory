class_name PhaseOverlay
extends Control
## The end-of-run screen: victory or "the gate fell", the stars the run earned, waves cleared,
## the gate left, and what next: the next sector (after a win), retry, or the campaign.
## After a loss it fades in once the breach moment has played (show_result's `delay`).
## (Between-wave screens are CardPicker and BuildBar.)

const FADE_TIME: float = 0.35

## Play the same sector again.
signal restart_pressed
## Play the next sector (shown after a win when there is one).
signal next_map_pressed
## Back to the campaign screen.
signal campaign_pressed

var title: Label
var stars: StarRow
var body: Label
var note: Label
var button: Button
var map_button: Button
var campaign_button: Button
## Real seconds before the fade-in starts, then the fade's progress.
var _delay: float = 0.0
var _fade: float = 1.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := UiTheme.dim(0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(Color(0, 0, 0, 0), -1,
			Color(UiTheme.look.title, 0.35), 2))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	title = UiTheme.label("", &"display", UiTheme.look.title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	stars = StarRow.make(0, 64.0)
	box.add_child(stars)
	body = UiTheme.label("", &"body", UiTheme.look.text)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	note = UiTheme.label("", &"body", UiTheme.look.good)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	map_button = Button.new()
	map_button.custom_minimum_size = Vector2(0, 58)
	UiTheme.style_button(map_button, true, &"label")
	map_button.pressed.connect(func() -> void:
		visible = false
		next_map_pressed.emit())
	box.add_child(map_button)
	button = Button.new()
	button.custom_minimum_size = Vector2(0, 52)
	button.pressed.connect(func() -> void:
		visible = false
		restart_pressed.emit())
	box.add_child(button)
	campaign_button = Button.new()
	campaign_button.custom_minimum_size = Vector2(0, 46)
	UiTheme.style_button(campaign_button, false, &"body")
	campaign_button.text = "CAMPAIGN"
	campaign_button.pressed.connect(func() -> void:
		visible = false
		campaign_pressed.emit())
	box.add_child(campaign_button)
	visible = false


## Show the result; with `delay` > 0 (real seconds) it stays transparent and unclickable until
## then, and fades in.
## `result`: Campaign.record's dictionary (stars, gained, new_best, consolation), or just
## {stars} for a run that isn't recorded.
## `next_map`: the name of the sector "NEXT SECTOR" goes to ("" hides the button).
func show_result(won: bool, cleared: int, total: int, gate_fraction: float, result: Dictionary,
		delay: float = 0.0, next_map: String = "") -> void:
	map_button.visible = next_map != ""
	map_button.text = "NEXT: %s  ▶" % next_map.to_upper()
	button.text = "RETRY" if won else "TRY AGAIN"
	UiTheme.style_button(button, next_map == "", &"label" if next_map == "" else &"body")
	title.text = "VICTORY" if won else "THE GATE FELL"
	title.add_theme_color_override("font_color", UiTheme.look.good if won else UiTheme.look.threat)
	var earned: int = int(result.get("stars", 0))
	stars.set_stars(earned)
	stars.pop_in(delay + FADE_TIME)
	_body_for(cleared, total, 0.0)
	if is_inside_tree():
		# The gate held counts up as the stars land.
		var t: Tween = create_tween().set_ignore_time_scale(true)
		t.tween_interval(delay + FADE_TIME)
		t.tween_method(func(g: float) -> void: _body_for(cleared, total, g), 0.0,
				gate_fraction, 0.6).set_ease(Tween.EASE_OUT)
	else:
		_body_for(cleared, total, gate_fraction)
	var lines: PackedStringArray = []
	if bool(result.get("consolation", false)):
		lines.append("A hard-fought stand: +1 star")
	elif int(result.get("gained", 0)) > 0:
		var n: int = int(result["gained"])
		lines.append("NEW BEST  +%d %s" % [n, "star" if n == 1 else "stars"])
	if won and earned < 3:
		lines.append("Keep the gate above 50% / 90% for more stars" if earned == 1
				else "Keep the gate above 90% for the third star")
	note.text = "\n".join(lines)
	note.visible = not lines.is_empty()
	visible = true
	_delay = delay
	_fade = 1.0 if delay <= 0.0 else 0.0
	_apply_fade()


func _body_for(cleared: int, total: int, gate: float) -> void:
	body.text = "Waves cleared: %d/%d\nGate held: %d%%" % [cleared, total, roundi(gate * 100.0)]


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
	campaign_button.disabled = _fade < 1.0


func is_result() -> bool:
	return visible
