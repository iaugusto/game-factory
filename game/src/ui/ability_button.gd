class_name AbilityButton
extends Control
## The special attack's button (top right, under the HUD, during waves): a round button with
## the picked attack's icon, its name, and a cooldown sweep. Ready: the action colour and a slow
## pulse. Armed (an aimed attack waiting for its target tap): a bright ring. Holds no rules; the
## owner reads Run and calls sync().

signal pressed

const SIZE: float = 76.0

var charged: bool = false
var armed: bool = false
## 0..1 of the cooldown left (1 = just fired).
var cooldown: float = 0.0
var icon: String = ""
var _t: float = 0.0
var _label: Label


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = UiTheme.label("", &"caption")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(SIZE, 20)
	_label.position = Vector2(0, SIZE - 20)
	add_child(_label)
	visible = false


func sync(run: Run, is_armed: bool, delta: float) -> void:
	var a: AbilityDef = run.ability
	charged = run.ability_ready()
	armed = is_armed
	icon = a.icon if a != null else ""
	cooldown = clampf(run.ability_cooldown_left / maxf(0.001, run.ability_cooldown()), 0.0, 1.0)
	var word: String = a.short_name if a != null else ""
	_label.text = "TAP FIELD" if armed else (word if charged
			else "%ds" % ceili(run.ability_cooldown_left))
	_t += delta
	queue_redraw()


## The button's rectangle on screen (tips spotlight it).
func area() -> Rect2:
	return get_global_rect()


func _draw() -> void:
	var c := Vector2(SIZE, SIZE) / 2.0
	var r: float = SIZE / 2.0 - 4.0
	var bg: Color = UiTheme.look.action if charged else UiTheme.look.panel_raised
	draw_circle(c, r, UiTheme.look.text_outline)
	draw_circle(c, r - 3.0, bg)
	Art.draw(self, icon, c - Vector2(0, 6), 0.0, 1.05,
			Color.WHITE if charged else Color(1, 1, 1, 0.45))
	if cooldown > 0.0:
		# The part still charging, as a dark pie from 12 o'clock.
		var pts := PackedVector2Array([c])
		var steps: int = 32
		for i: int in steps + 1:
			var a: float = -PI / 2.0 + TAU * cooldown * i / steps
			pts.append(c + Vector2.from_angle(a) * (r - 3.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.45))
	if armed:
		draw_arc(c, r + 1.0 + 3.0 * sin(_t * 10.0), 0, TAU, 40, UiTheme.look.threat, 3.0)
	elif charged:
		draw_arc(c, r + 2.0, 0, TAU, 40, Color(UiTheme.look.action, 0.5 + 0.4 * sin(_t * 4.0)), 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		accept_event()
		pressed.emit()
