class_name ShotField
extends Node2D
## Unit projectiles in flight, read from CombatSim.shots (only a few exist at once).
## Bullets: a glowing bolt in the unit's colour with a short streak, drawn additively.
## Shells: a mortar round on a ballistic arc (height is cosmetic; the rules only use the
## ground point) with its shadow sliding along the ground beneath it.
## Spits (CombatSim.spits): a spitter's lime acid glob with a dripping trail.

const ARC_MAX: float = 110.0

var _run: Run
var _add: Node2D


func _init() -> void:
	z_index = 4
	_add = Node2D.new()
	_add.material = Art.additive()
	_add.draw.connect(_draw_add)
	add_child(_add)


func sync(run: Run) -> void:
	_run = run
	queue_redraw()
	_add.queue_redraw()


static func arc_height(s: CombatSim.Shot) -> float:
	var k: float = clampf(s.t / s.duration, 0.0, 1.0)
	return sin(PI * k) * minf(ARC_MAX, s.start.distance_to(s.dest) * 0.4)


func _draw() -> void:
	if _run == null:
		return
	for s: CombatSim.Shot in _run.combat.shots:
		if s.attack != UnitDef.Attack.SHELL:
			continue
		var h: float = arc_height(s)
		var k: float = clampf(s.t / s.duration, 0.0, 1.0)
		Art.draw(self, "fx/shadow", s.pos + Vector2(4, 4), 0.0, 0.25 + 0.1 * (1.0 - h / ARC_MAX),
				Color(1, 1, 1, 0.7))
		var dir: Vector2 = (s.dest - s.start).normalized()
		var slope: float = cos(PI * k)  # climbing at the start, diving at the end
		var vel: Vector2 = dir + Vector2(0, -slope * 0.9)
		Art.draw(self, "fx/shell", s.pos - Vector2(0, h), vel.angle() + PI / 2.0, 1.0 + h / ARC_MAX * 0.4)


func _draw_add() -> void:
	if _run == null:
		return
	for sp: CombatSim.Spit in _run.combat.spits:
		var dir: Vector2 = (sp.plot.position - sp.pos).normalized()
		_add.draw_line(sp.pos - dir * 16.0, sp.pos, Color(0.6, 1.0, 0.3, 0.45), 4.0)
		Art.draw(_add, "fx/glow", sp.pos, 0.0, 0.45, Color(0.75, 1.0, 0.3, 0.9))
		Art.draw(_add, "fx/glow", sp.pos, 0.0, 0.18, Color(1.0, 1.0, 0.8, 1.0))
	for s: CombatSim.Shot in _run.combat.shots:
		var col: Color = _color_of(s)
		if s.attack == UnitDef.Attack.SHELL:
			Art.draw(_add, "fx/glow", s.pos - Vector2(0, arc_height(s)), 0.0, 0.25, Color(1, 0.6, 0.2, 0.6))
			continue
		var dir: Vector2 = (s.dest - s.pos).normalized()
		_add.draw_line(s.pos - dir * 14.0, s.pos, Color(col, 0.5), 3.0)
		Art.draw(_add, "fx/glow", s.pos, 0.0, 0.35, Color(col, 0.8))
		Art.draw(_add, "fx/bolt", s.pos, 0.0, 0.6, Color.WHITE)


func _color_of(s: CombatSim.Shot) -> Color:
	var plot: CombatSim.Plot = _run.plots[s.plot] if s.plot < _run.plots.size() else null
	return plot.def.color if plot != null and plot.def != null else Color.WHITE
