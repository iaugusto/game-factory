class_name PlotView
extends Node2D
## One build plot. Empty: a concrete pad with a teal "+" ring that breathes. Built: the unit's
## base, its head turning smoothly toward its target, recoil and a muzzle flash on each shot, a
## charging ring for slow reloads (the "stronger means slower" rule made visible), and level
## chevrons. Selected: the unit's reach as a ring. Jammed by a spitter: greyed, gooed in lime,
## with a ring counting down the seconds left.

## Head sprite length to the muzzle, per unit id (field units), for the flash position.
const MUZZLE: Dictionary[StringName, float] = {&"rifleman": 18.0, &"sniper": 30.0, &"mg": 24.0,
		&"frost": 18.0, &"mortar": 16.0, &"rail": 27.0}
## Reloads shorter than this don't get a charge ring (it would only flicker).
const RING_MIN_RELOAD: float = 0.8
const TURN_SPEED: float = 10.0

var plot: CombatSim.Plot
var _built_id: StringName = &""
var _built_level: int = 0
var _angle: float = 0.0
var _recoil: float = 0.0
var _flash: float = 0.0
var _pop: float = 0.0
var _t: float = 0.0
var _selected: bool = false
var _charge: float = 1.0
var _reload: float = 1.0
var _reach: float = 0.0
var _disabled: float = 0.0
## The longest disable seen since it started (for the countdown ring).
var _disabled_full: float = 1.0
var _add: Node2D


func _init() -> void:
	_add = Node2D.new()
	_add.material = Art.additive()
	_add.draw.connect(_draw_add)
	add_child(_add)


## Draw order: wall spots sit on the wall sprite (FieldView.wall, z 5), so they draw above it.
const WALL_Z: int = 6

## True for a spot on the wall (behind RunConfig.wall_y); set by PlotField.
var on_wall: bool = false
## The wave at hand (1-based), to show a locked plot's unlock wave; set by PlotField.
var wave_number: int = 1
## True if it stands on high ground (drawn with a gold rim).
var high_ground: bool = false


func set_selected(on: bool) -> void:
	_selected = on
	# The reach ring draws over neighbouring plots.
	z_index = (WALL_Z if on_wall else 0) + (3 if on else 0)
	queue_redraw()


func sync(sim: CombatSim, delta: float) -> void:
	_t += delta
	if plot.is_empty():
		_built_id = &""
		_built_level = 0
	elif plot.def.id != _built_id:
		_built_id = plot.def.id
		_built_level = plot.level
		_pop = 1.0
		_angle = 0.0
	elif plot.level > _built_level:
		_built_level = plot.level
		_pop = 1.0  # an upgrade pops like a build
	if not plot.is_empty():
		if plot.target != null or plot.aim != Vector2.ZERO:
			var want: float = (plot.aim - plot.position).angle() + PI / 2.0
			_angle = lerp_angle(_angle, want, minf(1.0, TURN_SPEED * delta))
		_reload = sim.plot_reload(plot)
		_reach = sim.plot_reach(plot)
		_charge = 1.0 - clampf(plot.cooldown / _reload, 0.0, 1.0)
	if plot.disabled > _disabled:
		_disabled_full = plot.disabled
	_disabled = plot.disabled
	_recoil = maxf(0.0, _recoil - delta * 30.0)
	_flash = maxf(0.0, _flash - delta)
	_pop = maxf(0.0, _pop - delta * 4.0)
	queue_redraw()
	_add.queue_redraw()


func on_fired(target: Vector2) -> void:
	_angle = (target - plot.position).angle() + PI / 2.0
	_recoil = 5.0 if plot.def.reload >= 1.0 else 2.0
	_flash = 0.07


func _draw() -> void:
	if high_ground:
		draw_arc(Vector2.ZERO, 31, 0, TAU, 40, Color(1.0, 0.8, 0.35, 0.55), 2.0)
	if plot.is_empty() and plot.unlock_wave > wave_number:
		# Locked until its wave: a dark pad, a padlock, and when it opens.
		Art.draw(self, "units/plot", Vector2.ZERO, 0.0, 1.0, Color(0.35, 0.35, 0.38, 0.8))
		draw_rect(Rect2(-7, -3, 14, 11), Color(0.75, 0.72, 0.65))
		draw_arc(Vector2(0, -3), 5, PI, TAU, 12, Color(0.75, 0.72, 0.65), 2.5)
		var font: Font = ThemeDB.fallback_font
		var text: String = "W%d" % plot.unlock_wave
		draw_string_outline(font, Vector2(-11, 28), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.look.caption, 4,
				Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(-11, 28), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.look.caption,
				Color(0.85, 0.82, 0.75))
		return
	if plot.is_empty():
		var breathe: float = 1.0 + 0.04 * sin(_t * 3.0 + plot.index)
		Art.draw(self, "units/plot", Vector2.ZERO, 0.0, breathe)
		if _selected:
			draw_arc(Vector2.ZERO, 30, 0, TAU, 40, Color(0.25, 0.9, 0.8, 0.9), 2.5)
		return
	var s: float = 1.0 + 0.35 * _pop * _pop
	if _selected:
		draw_circle(Vector2.ZERO, _reach, Color(0.25, 0.9, 0.8, 0.08))
		draw_arc(Vector2.ZERO, _reach, 0, TAU, 96, Color(0.25, 0.9, 0.8, 0.7), 2.0)
	var base: String = "units/base_%s" % plot.def.id  # painted in its damage type's colour
	var tint: Color = Color(0.55, 0.62, 0.5) if _disabled > 0.0 else Color.WHITE
	Art.draw(self, base, Vector2.ZERO, 0.0, s, tint)
	if _reload >= RING_MIN_RELOAD:
		var col: Color = plot.def.color
		draw_arc(Vector2.ZERO, 26, -PI / 2.0, -PI / 2.0 + TAU * _charge, 32,
				Color(col, 0.35 + 0.5 * _charge), 3.0)
	var back: Vector2 = Vector2(0, _recoil).rotated(_angle)
	Art.draw(self, "units/%s" % plot.def.id, back, _angle, s, tint)
	if plot.max_hp > 0.0 and plot.hp < plot.max_hp:  # damaged by a Ravager: its health
		var ratio: float = clampf(plot.hp / plot.max_hp, 0.0, 1.0)
		draw_rect(Rect2(-22, -34, 44, 6), Color(0.05, 0.04, 0.03, 0.85))
		draw_rect(Rect2(-21, -33, 42 * ratio, 4), EnemyField._bar_color(ratio))
	if _disabled > 0.0:
		# lime goo over the unit and a ring counting down the seconds left
		for k: int in 5:
			var a: float = TAU * k / 5.0 + 0.7
			draw_circle(Vector2(cos(a), sin(a)) * 11.0, 5.5 - k * 0.5, Color(0.62, 0.9, 0.2, 0.75))
		draw_circle(Vector2.ZERO, 7.0, Color(0.72, 1.0, 0.3, 0.8))
		var left: float = clampf(_disabled / maxf(_disabled_full, 0.001), 0.0, 1.0)
		draw_arc(Vector2.ZERO, 29, -PI / 2.0, -PI / 2.0 + TAU * left, 32,
				Color(0.8, 1.0, 0.35, 0.95), 3.5)
	for i: int in plot.level - 1:  # level chevrons under the base
		var x: float = (i - (plot.level - 2) / 2.0) * 9.0
		var y: float = 27.0
		draw_polyline(PackedVector2Array([Vector2(x - 4, y), Vector2(x, y + 4), Vector2(x + 4, y)]),
				Color("#ffd24a"), 2.5)


func _draw_add() -> void:
	if plot.is_empty():
		return
	if _flash > 0.0:
		var muzzle: Vector2 = Vector2(0, -MUZZLE.get(plot.def.id, 20.0)).rotated(_angle)
		var k: float = _flash / 0.07
		Art.draw(_add, "fx/glow", muzzle, 0.0, 0.5 * k, Color(plot.def.color, 0.9))
		Art.draw(_add, "fx/muzzle", muzzle + Vector2(0, -6).rotated(_angle), _angle, 0.8 * k,
				Color(1, 0.95, 0.8, k))
	if _reload >= RING_MIN_RELOAD and _charge >= 1.0 and _disabled <= 0.0:
		var glow: float = 0.25 + 0.15 * sin(_t * 6.0)
		Art.draw(_add, "fx/glow", Vector2.ZERO, 0.0, 0.9, Color(plot.def.color, glow))
