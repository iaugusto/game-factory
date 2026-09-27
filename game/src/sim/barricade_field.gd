class_name BarricadeField
extends Node2D
## The barricade slots and the one barricade (Run.barricade()). Empty slots show as faint
## hazard outlines between waves (and always, until a barricade is built), so the player sees
## where it can go; the barricade shows its level's sprite, or rubble once broken, with an HP
## bar, a shake when struck and a highlight when selected. Answers "which slot is here?".

## Taps within this distance of a slot centre select it.
const HIT_RADIUS: float = 40.0
const SIZE := Vector2(120, 40)
const SHAKE_TIME: float = 0.15

var selected: int = -1
var _run: Run
var _slots: PackedVector2Array = PackedVector2Array()
var _last_hp: float = 0.0
var _shake: float = 0.0
var _t: float = 0.0


func setup(run: Run) -> void:
	_run = run
	_slots = run.config.map.barricade_slots
	selected = -1
	_last_hp = 0.0
	queue_redraw()


## The slot under `field_pos`, or -1.
func slot_at(field_pos: Vector2) -> int:
	var best: int = -1
	var best_d: float = HIT_RADIUS * HIT_RADIUS
	for i: int in _slots.size():
		var d: float = _slots[i].distance_squared_to(field_pos)
		if d <= best_d:
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
			var a: float = 0.28 + 0.1 * sin(_t * 3.0 + i)
			var r := Rect2(p - SIZE / 2.0, SIZE)
			draw_rect(r, Color(1.0, 0.75, 0.2, a * 0.35))
			draw_rect(r, Color(1.0, 0.75, 0.2, a + 0.25), false, 2.0)
		if selected == i:
			draw_rect(Rect2(p - SIZE / 2.0, SIZE).grow(4.0), Color(0.25, 0.9, 0.8, 0.9), false, 2.5)


func _draw_barricade(b: CombatSim.Barricade, p: Vector2) -> void:
	var jolt: Vector2 = Vector2(sin(_t * 80.0), 0.0) * 3.0 * (_shake / SHAKE_TIME)
	var key: String = "props/barricade_%d" % b.level if b.is_standing() else "props/barricade_rubble"
	Art.draw(self, key, p + jolt)
	if b.is_standing() and b.hp < b.max_hp:
		var w: float = 90.0
		var ratio: float = clampf(b.hp / b.max_hp, 0.0, 1.0)
		var top: float = p.y + SIZE.y / 2.0 + 2.0
		draw_rect(Rect2(p.x - w / 2.0 - 1, top - 1, w + 2, 6), Color(0.05, 0.04, 0.03, 0.85))
		draw_rect(Rect2(p.x - w / 2.0, top, w * ratio, 4), EnemyField._bar_color(ratio))
