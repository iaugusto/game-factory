class_name BossBar
extends Control
## The boss's HP bar, under the top bar while a boss is on the field (content expansion Stage 3,
## docs/2026-09-27-content-expansion/): its name, its HP with a tick at each phase threshold
## (ticks it has passed are dimmed), and a status line while its guards make it untouchable.
## It follows CombatSim.bosses[0] (the first boss still alive); it only reads the run.

const HEIGHT: float = 46.0
const BAR_H: float = 12.0
## Widest it gets (it sits between the screen's edge buttons on narrow screens).
const MAX_WIDTH: float = 340.0
const GUARD_COLOR := Color("#ffd86a")

var name_label: Label
var status_label: Label
## The boss shown in the last sync (null: hidden).
var boss: CombatSim.Enemy = null
var _ratio: float = 1.0
## Shown ratio, easing toward the real one so a big hit reads as a drain.
var _shown: float = 1.0
var _ticks: PackedFloat32Array = PackedFloat32Array()
var _passed: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	size = Vector2(MAX_WIDTH, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	name_label = UiTheme.label("", &"label", UiTheme.look.threat)
	name_label.position = Vector2(0, 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	status_label = UiTheme.label("", &"caption", GUARD_COLOR)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)


## Show the first boss on the field during a wave (hide otherwise).
func sync(run: Run, delta: float = 0.0) -> void:
	var sim: CombatSim = run.combat
	var b: CombatSim.Enemy = sim.bosses[0] if not sim.bosses.is_empty() else null
	visible = b != null and run.phase == Run.Phase.WAVE
	if not visible:
		boss = null
		return
	if b != boss:
		boss = b
		_shown = 1.0
		name_label.text = b.def.display_name.to_upper()
		_ticks.clear()
		for ph: BossPhase in b.def.phases:
			if ph.at_hp_fraction < 1.0:
				_ticks.append(ph.at_hp_fraction)
	_ratio = clampf(b.hp / maxf(0.001, b.max_hp), 0.0, 1.0)
	_shown = _ratio if delta <= 0.0 or _ratio > _shown \
			else maxf(_ratio, _shown - maxf(0.25, (_shown - _ratio) * 3.0) * delta)
	_passed = 0
	for t: float in _ticks:
		if _ratio <= t + 1e-4:
			_passed += 1
	if b.guarded():
		status_label.text = "GUARDED ×%d" % b.guards
	else:
		status_label.text = ""
	status_label.size = Vector2(size.x, 20)
	status_label.position = Vector2(0, 2)
	queue_redraw()


## The bar's rectangle, under the name.
func bar_rect() -> Rect2:
	return Rect2(0, HEIGHT - BAR_H - 6.0, size.x, BAR_H)


## Phase ticks passed, for tests.
func passed_ticks() -> int:
	return _passed


func _draw() -> void:
	if boss == null:
		return
	var r: Rect2 = bar_rect()
	var guarded: bool = boss.guarded()
	draw_rect(r.grow(2.0), Color(0.03, 0.02, 0.03, 0.9))
	draw_rect(r, UiTheme.look.threat.darkened(0.8))
	draw_rect(Rect2(r.position, Vector2(r.size.x * _shown, r.size.y)), Color(1, 1, 1, 0.55))
	var fill: Color = GUARD_COLOR if guarded else UiTheme.look.threat
	draw_rect(Rect2(r.position, Vector2(r.size.x * _ratio, r.size.y)), fill)
	draw_rect(Rect2(r.position, Vector2(r.size.x * _ratio, r.size.y * 0.35)), Color(1, 1, 1, 0.22))
	for i: int in _ticks.size():
		var x: float = r.position.x + r.size.x * _ticks[i]
		var c := Color(1, 1, 1, 0.3) if _ratio <= _ticks[i] + 1e-4 else Color(1, 1, 1, 0.95)
		draw_line(Vector2(x, r.position.y - 4.0), Vector2(x, r.end.y + 4.0), Color(0, 0, 0, 0.9), 4.0)
		draw_line(Vector2(x, r.position.y - 4.0), Vector2(x, r.end.y + 4.0), c, 2.0)
	draw_rect(r.grow(2.0), Color(1, 1, 1, 0.18), false, 1.0)
