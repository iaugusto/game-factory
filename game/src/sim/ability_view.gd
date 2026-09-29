class_name AbilityView
extends Node2D
## Draws, on the field: the aim preview while an attack is armed (its blast circle, fire strip
## or row of mines), a telegraph on each attack on its way (its area and a ring closing in as it
## lands), the burning strips and waiting mines, and the links between units (thin animated
## dashes between linked pads). A handful of lines, arcs and sprites in one _draw; no nodes per
## object.

const FREEZE_COLOR := Color("#8fe8ff")
const BURN_COLOR := Color("#ff8a2e")
const MINE_COLOR := Color("#e8b030")

var run: Run
## One instance draws the links (under the plots), another the attacks and aim (over enemies).
var links_only: bool = false
var armed: bool = false
var aim: Vector2 = Vector2(270, 400)
## Whether a mouse has moved (desktop): only then does a preview follow it. On touch there is
## no hover, so armed shows a pulsing frame around the field instead.
var aim_seen: bool = false
var _t: float = 0.0


func sync(r: Run, is_armed: bool, aim_at: Vector2, delta: float) -> void:
	run = r
	armed = is_armed
	aim = aim_at
	_t += delta
	queue_redraw()


## The colour an ability's telegraph and preview are drawn in.
static func color_of(a: AbilityDef) -> Color:
	match a.kind:
		AbilityDef.Kind.FREEZE:
			return FREEZE_COLOR
		AbilityDef.Kind.BURN:
			return BURN_COLOR
		AbilityDef.Kind.MINES:
			return MINE_COLOR
	return UiTheme.look.threat


func _draw() -> void:
	if run == null:
		return
	if links_only:
		_draw_links()
		return
	for h: CombatSim.Hazard in run.combat.hazards:
		_draw_fire(h)
	for m: CombatSim.Mine in run.combat.mines:
		Art.draw(self, "fx/mine", m.pos, 0.0, 1.0)
		var blink: float = 0.5 + 0.5 * sin(_t * 9.0 + m.id)
		draw_circle(m.pos, 2.6, Color(1.0, 0.25, 0.2, 0.4 + 0.6 * blink))
	for c: CombatSim.Cast in run.combat.casts:
		_draw_cast(c)
	if armed and run.ability != null:
		var a: float = 0.6 + 0.3 * sin(_t * 8.0)
		var col: Color = color_of(run.ability)
		var field := Rect2(Vector2.ZERO, Vector2(run.config.playfield_width(), run.config.wall_y))
		draw_rect(field.grow(-3.0), Color(col, a * 0.8), false, 6.0)
		if aim_seen:
			_draw_preview(run.ability, aim, Color(col, a))


## What an armed attack would cover if tapped at `at`.
func _draw_preview(ab: AbilityDef, at: Vector2, col: Color) -> void:
	match ab.kind:
		AbilityDef.Kind.BURN:
			var road: Array[CombatSim.Stretch] = run.combat.burn_layout(ab, at)
			var bands: Array[PackedVector2Array] = _bands(road, run.combat.burn_half_width(road))
			_fill(bands, Color(col, 0.15))
			_outline(bands, col, 2.5)
		AbilityDef.Kind.MINES:
			for p: Vector2 in mine_spots(run, ab, at):
				draw_arc(p, 7.0, 0, TAU, 16, col, 2.0)
		_:
			draw_arc(at, ab.radius, 0, TAU, 48, col, 2.5)
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(at + dir * 10.0, at + dir * 26.0, col, 3.0)


## An attack on its way: its area, and a ring closing in as it lands.
func _draw_cast(c: CombatSim.Cast) -> void:
	var ab: AbilityDef = c.ability
	var k: float = clampf(c.t / maxf(0.001, ab.delay), 0.0, 1.0)
	var col: Color = color_of(ab)
	match ab.kind:
		AbilityDef.Kind.STRIKE, AbilityDef.Kind.FREEZE:
			draw_circle(c.pos, ab.radius, Color(col, 0.12))
			draw_arc(c.pos, ab.radius, 0, TAU, 48, Color(col, 0.8), 2.0)
			draw_arc(c.pos, ab.radius * k, 0, TAU, 48, Color(col, 0.9), 3.0)
			# The shell on its way down: it falls into the blast as the ring closes.
			var fall := Vector2(-60.0, 420.0)
			var shell: Vector2 = c.pos - fall * k * k
			draw_line(shell, shell - fall.normalized() * 70.0, Color(col.lightened(0.5), 0.35), 3.0)
			Art.draw(self, "fx/shell", shell, fall.angle() - PI / 2.0, 1.4,
					Color.WHITE if ab.kind == AbilityDef.Kind.STRIKE else FREEZE_COLOR.lightened(0.3))
		AbilityDef.Kind.BURN:
			var road: Array[CombatSim.Stretch] = run.combat.burn_layout(ab, c.pos)
			var hw: float = run.combat.burn_half_width(road)
			var bands: Array[PackedVector2Array] = _bands(road, hw)
			_fill(bands, Color(col, 0.12))
			_outline(bands, Color(col, 0.8), 2.0)
			# The fuse: fills along the road from the middle out as it lands.
			for st: CombatSim.Stretch in road:
				var geo: PathGeo = run.combat.geos[st.path]
				var mid: float = (st.d_lo + st.d_hi) / 2.0
				var half: float = (st.d_hi - st.d_lo) / 2.0 * (1.0 - k)
				for poly: PackedVector2Array in _band(geo.stretch(mid - half, mid + half), hw):
					draw_colored_polygon(poly, Color(col, 0.25))
		AbilityDef.Kind.MINES:
			for p: Vector2 in mine_spots(run, ab, c.pos):
				draw_arc(p, 6.0 + 10.0 * k, 0, TAU, 16, Color(col, 0.9), 2.0)


## A burning stretch of road: an ember glow along it under two staggered rows of flickering
## flames that follow its bends (and every branch it takes), dying down at the end.
func _draw_fire(h: CombatSim.Hazard) -> void:
	var life: float = clampf(h.t / maxf(0.001, h.duration), 0.0, 1.0)
	var fade: float = clampf(life * 4.0, 0.0, 1.0)
	_fill(_bands(h.stretches, h.half_width), Color(BURN_COLOR.darkened(0.3), 0.28 * fade))
	for s_i: int in h.stretches.size():
		var st: CombatSim.Stretch = h.stretches[s_i]
		var geo: PathGeo = run.combat.geos[st.path]
		var n: int = maxi(3, int((st.d_hi - st.d_lo) / 22.0))
		for row: int in 2:
			for i: int in n:
				var d: float = lerpf(st.d_lo, st.d_hi, (i + 0.5 + row * 0.5) / (n + 0.5))
				var side: float = h.half_width * (0.45 if row == 0 else -0.45)
				var p: Vector2 = geo.point_at(d) + geo.normal_at(d) * side
				if _drawn_before(h, s_i, geo.point_at(d)):
					continue  # a shared stretch of road already has its flames
				var flick: float = 0.8 + 0.25 * sin(_t * 13.0 + i * 1.7 + row * 2.3 + h.id)
				Art.draw(self, "fx/flame", p, 0.0, flick * (0.7 + 0.3 * fade), Color(1, 1, 1, fade))


## Whether centre-line point `p` of stretch `s_i` lies on an earlier stretch of `h`.
static func _drawn_before(h: CombatSim.Hazard, s_i: int, p: Vector2) -> bool:
	for j: int in s_i:
		if PathGeo.distance_to_polyline(h.stretches[j].points, p) < 4.0:
			return true
	return false


## The road `stretches` cover, `half_width` to each side, as polygons merged where they overlap
## (a fork's shared stem is drawn once, so translucent fills don't darken there).
static func _bands(stretches: Array[CombatSim.Stretch], half_width: float) \
		-> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for st: CombatSim.Stretch in stretches:
		for poly: PackedVector2Array in _band(st.points, half_width):
			var merged: bool = false
			for i: int in out.size():
				var union: Array[PackedVector2Array] = Geometry2D.merge_polygons(out[i], poly)
				if union.size() == 1:
					out[i] = union[0]
					merged = true
					break
			if not merged:
				out.append(poly)
	return out


static func _band(pts: PackedVector2Array, half_width: float) -> Array[PackedVector2Array]:
	if pts.size() < 2 or half_width <= 0.0:
		return []
	return Geometry2D.offset_polyline(pts, half_width, Geometry2D.JOIN_ROUND,
			Geometry2D.END_BUTT)


func _fill(bands: Array[PackedVector2Array], col: Color) -> void:
	for poly: PackedVector2Array in bands:
		draw_colored_polygon(poly, col)


func _outline(bands: Array[PackedVector2Array], col: Color, width: float) -> void:
	for poly: PackedVector2Array in bands:
		var ring: PackedVector2Array = poly.duplicate()
		ring.append(poly[0])
		draw_polyline(ring, col, width, true)


## Where a MINES attack at `at` would lay its mines (CombatSim.mine_layout), on the field.
static func mine_spots(r: Run, ab: AbilityDef, at: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var layout: Array = r.combat.mine_layout(ab, at)
	if not layout.is_empty():
		for d: float in layout[1]:
			out.append(r.combat.geos[layout[0]].point_at(d))
	return out


func _draw_links() -> void:
	var pulse: float = 0.35 + 0.15 * sin(_t * 2.5)
	for p: CombatSim.Plot in run.plots:
		for link: Array in p.links:
			var j: int = link[0]
			if j <= p.index:
				continue
			var q: CombatSim.Plot = run.plots[j]
			var dir: Vector2 = (q.position - p.position).normalized()
			draw_dashed_line(p.position + dir * 26.0, q.position - dir * 26.0,
					Color(UiTheme.look.owned, pulse), 2.0, 8.0)
