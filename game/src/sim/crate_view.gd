class_name CrateView
extends Node2D
## One loot crate: the crate sprite with a soft shadow, a wobble as it drifts, a shake and
## flash when hit, its HP bar, and a coin tag showing what breaking it pays. Boost crates
## pulse with light.

const SHAKE_TIME: float = 0.12

var crate: CombatSim.Crate
var _last_hp: float = 0.0
var _shake: float = 0.0
var _t: float = 0.0
var _add: Node2D
var _tag: Label


func _init() -> void:
	_add = Node2D.new()
	_add.material = Art.additive()
	_add.show_behind_parent = true
	_add.draw.connect(_draw_glow)
	add_child(_add)
	_tag = Label.new()
	_tag.add_theme_font_size_override("font_size", 13)
	_tag.add_theme_color_override("font_color", Color("#ffe8a0"))
	_tag.add_theme_constant_override("outline_size", 4)
	_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_tag)


func bind(c: CombatSim.Crate) -> void:
	crate = c
	_last_hp = c.hp
	_shake = 0.0
	visible = true
	_tag.text = "%d" % c.def.reward
	_tag.reset_size()
	sync(0.0)


func unbind() -> void:
	crate = null
	visible = false


func sync(delta: float) -> void:
	if crate == null:
		return
	_t += delta
	if crate.hp < _last_hp:
		_shake = SHAKE_TIME
		_last_hp = crate.hp
	_shake = maxf(0.0, _shake - delta)
	var jolt: Vector2 = Vector2(sin(_t * 90.0), cos(_t * 77.0)) * 3.0 * (_shake / SHAKE_TIME)
	position = crate.pos() + jolt
	rotation = sin(_t * 1.6 + crate.id) * 0.06
	var box: float = Art.size("crates/%s" % crate.def.id).y
	_tag.position = Vector2(-_tag.size.x / 2.0 + 7.0, box * 0.5 + 2.0)
	_tag.rotation = -rotation
	queue_redraw()
	_add.queue_redraw()


func _draw() -> void:
	if crate == null:
		return
	var key: String = "crates/%s" % crate.def.id
	var flash: float = _shake / SHAKE_TIME
	Art.draw(self, key, Vector2.ZERO, 0.0, 1.0 + 0.08 * flash, Color(1 + flash, 1 + flash, 1 + flash))
	var box: float = Art.size(key).y
	var w: float = box * 0.8
	var ratio: float = clampf(crate.hp / crate.def.hp, 0.0, 1.0)
	var top: float = -box * 0.5 - 7.0
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	draw_rect(Rect2(-w / 2.0 - 1, top - 1, w + 2, 6), Color(0.05, 0.04, 0.03, 0.85))
	draw_rect(Rect2(-w / 2.0, top, w * ratio, 4), Color("#ffc24a"))
	draw_rect(Rect2(-w / 2.0, top, w * ratio, 1.5), Color(1, 1, 1, 0.35))
	Art.draw(self, "fx/coin", Vector2(-_tag.size.x / 2.0 - 1.0, box * 0.5 + 10.0), -rotation, 0.6)


func _draw_glow() -> void:
	if crate == null:
		return
	if crate.def.is_boost():
		var pulse: float = 0.55 + 0.3 * sin(_t * 7.0)
		Art.draw(_add, "fx/glow", Vector2.ZERO, 0.0, 1.5, Color(crate.def.color, pulse))
	else:
		Art.draw(_add, "fx/glow", Vector2.ZERO, 0.0, 1.0, Color(1.0, 0.8, 0.4, 0.12))
