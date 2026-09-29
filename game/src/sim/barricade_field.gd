class_name BarricadeField
extends Node2D
## The barricade slots and the one barricade (Run.barricade()). Empty slots show as a pulsing
## amber ghost of the barricade itself (props/barricade_slot) between waves (and always, until a
## barricade is built), so the player sees where it can go and what it will look like; the
## barricade shows its level's sprite, or rubble once broken, with an HP bar, a shake when
## struck and a teal ghost over it when selected. Answers "which slot is here?": a tap inside
## the barricade's footprint (its art's size, plus TAP_SLOP), the same shape the player sees.

## Extra reach around the footprint for a fingertip (field units).
const TAP_SLOP: float = 6.0
const SLOT_KEY: String = "props/barricade_slot"
const SHAKE_TIME: float = 0.15
const OPEN_TINT := Color(1.0, 0.75, 0.2)
const SELECTED_TINT := Color(0.25, 0.9, 0.8)

var selected: int = -1
var _run: Run
var _slots: PackedVector2Array = PackedVector2Array()
var _last_hp: float = 0.0
var _shake: float = 0.0
var _t: float = 0.0
## The barricade's footprint in field units, from its art.
var _size: Vector2 = Vector2.ZERO


func setup(run: Run) -> void:
	_run = run
	_size = Art.size(SLOT_KEY)
	_slots = run.config.map.barricade_slots
	selected = -1
	_last_hp = 0.0
	queue_redraw()


## The slot whose footprint (grown by TAP_SLOP) holds `field_pos`, nearest first; or -1.
func slot_at(field_pos: Vector2) -> int:
	var best: int = -1
	var best_d: float = INF
	var half: Vector2 = _size / 2.0 + Vector2.ONE * TAP_SLOP
	for i: int in _slots.size():
		var off: Vector2 = (field_pos - _slots[i]).abs()
		if off.x > half.x or off.y > half.y:
			continue
		var d: float = _slots[i].distance_squared_to(field_pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func select(slot: int) -> void:
	selected = slot
	queue_redraw()


func sync(delta: float) -> void:
	if _run == null:
		return
	_t += delta
	var b: CombatSim.Barricade = _run.barricade()
	if b.hp < _last_hp:
		_shake = SHAKE_TIME
	_last_hp = b.hp
	_shake = maxf(0.0, _shake - delta)
	queue_redraw()


func _draw() -> void:
	if _run == null:
		return
	var b: CombatSim.Barricade = _run.barricade()
	var show_slots: bool = _run.phase == Run.Phase.BUILD or not b.is_built()
	for i: int in _slots.size():
		var p: Vector2 = _slots[i]
		if b.is_built() and b.slot == i:
			_draw_barricade(b, p)
		elif show_slots or selected == i:
			var a: float = 0.55 + 0.2 * sin(_t * 3.0 + i)
			Art.draw(self, SLOT_KEY, p, 0.0, 1.0, Color(OPEN_TINT, a))
		if selected == i:
			Art.draw(self, SLOT_KEY, p, 0.0, 1.06, Color(SELECTED_TINT, 0.85))


func _draw_barricade(b: CombatSim.Barricade, p: Vector2) -> void:
	var jolt: Vector2 = Vector2(sin(_t * 80.0), 0.0) * 3.0 * (_shake / SHAKE_TIME)
	var key: String = "props/barricade_%d" % b.level if b.is_standing() else "props/barricade_rubble"
	Art.draw(self, key, p + jolt)
	if b.is_standing() and b.hp < b.max_hp:
		var w: float = 90.0
		var ratio: float = clampf(b.hp / b.max_hp, 0.0, 1.0)
		var top: float = p.y + _size.y / 2.0 + 2.0
		draw_rect(Rect2(p.x - w / 2.0 - 1, top - 1, w + 2, 6), Color(0.05, 0.04, 0.03, 0.85))
		draw_rect(Rect2(p.x - w / 2.0, top, w * ratio, 4), EnemyField._bar_color(ratio))
