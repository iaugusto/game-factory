class_name Fx
extends Node2D
## Everything cosmetic that comes and goes: particle bursts (chitin shards, crate splinters,
## sparks, coins that fly to the coin counter), light flashes and shock rings, hitscan tracers
## and rail beams, floating text, and screen shake.
##
## It uses its own RandomNumberGenerator, never a gameplay stream, so nothing here can change
## the simulation. Particles are plain data drawn in two passes (normal and additive), so a
## burst costs no nodes; the counts are capped.

signal coin_arrived

const MAX_PARTICLES: int = 400
const MAX_FLASHES: int = 64


class Particle:
	var key: String
	var pos: Vector2
	var vel: Vector2
	var rot: float
	var spin: float
	var age: float = 0.0
	var life: float
	var scl: float
	var color: Color
	var gravity: float = 0.0
	var drag: float = 2.0
	var additive: bool = false
	## Coins: after `home_after` seconds they accelerate toward `home`.
	var homing: bool = false
	var home_after: float = 0.0


class Flash:
	var key: String
	var pos: Vector2
	var rot: float = 0.0
	var scl0: float
	var scl1: float
	var color: Color
	var age: float = 0.0
	var life: float


class Streak:
	var a: Vector2
	var b: Vector2
	var color: Color
	var width: float
	var age: float = 0.0
	var life: float


## Popups are kept inside [0, bounds_width] so edge text is never clipped (0 = no clamp).
var bounds_width: float = 0.0
## Where flying coins go (field coordinates of the HUD coin counter).
var coin_target: Vector2 = Vector2(480, -30)

var _particles: Array[Particle] = []
var _flashes: Array[Flash] = []
var _streaks: Array[Streak] = []
var _labels: Array[Label] = []
var _label_life: Dictionary[Label, Vector3] = {}  # label -> (age, life, rise)
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()
var _add: Node2D


func _init() -> void:
	z_index = 8
	_add = Node2D.new()
	_add.material = Art.additive()
	_add.draw.connect(_draw_add)
	add_child(_add)


# --- effect recipes ---------------------------------------------------------------------

## An enemy dies: chitin shards in its colour, a pop of light, a goo splat for the ground.
func death(pos: Vector2, color: Color, radius: float) -> void:
	var n: int = clampi(int(radius * 0.8), 6, 26)
	for i: int in n:
		var p := _spawn("fx/shard", pos, _rng.randf_range(80, 220) * (radius / 14.0), 0.55)
		p.color = color.lightened(_rng.randf_range(-0.2, 0.25))
		p.scl = _rng.randf_range(0.6, 1.2) * clampf(radius / 12.0, 0.8, 2.2)
	for i: int in 6:
		var s := _spawn("fx/glow", pos, _rng.randf_range(60, 160), 0.3)
		s.additive = true
		s.color = Color(color.lightened(0.5), 0.8)
		s.scl = 0.12
	flash("fx/glow", pos, radius * 0.06, radius * 0.11, Color(color.lightened(0.4), 0.9), 0.18)


## A shell lands: a hot flash, a shock ring, sparks and a thrown-up dust burst.
func explosion(pos: Vector2, radius: float) -> void:
	flash("fx/glow", pos, radius * 0.03, radius * 0.07, Color(1.0, 0.75, 0.35, 1.0), 0.28)
	flash("fx/ring", pos, radius * 0.01, radius * 0.034, Color(1.0, 0.85, 0.6, 0.8), 0.3)
	for i: int in 14:
		var s := _spawn("fx/glow", pos, _rng.randf_range(120, 320), 0.35)
		s.additive = true
		s.color = Color(1.0, _rng.randf_range(0.5, 0.9), 0.3, 0.9)
		s.scl = _rng.randf_range(0.08, 0.16)
	for i: int in 8:
		var d := _spawn("fx/shard", pos, _rng.randf_range(60, 160), 0.5)
		d.color = Color("#5a4632")
		d.scl = _rng.randf_range(0.7, 1.3)
	shake(4.0)


## A crate breaks: splinters, a flash, and `coins` coins that burst out then fly to the HUD.
func crate_break(pos: Vector2, color: Color, coins: int) -> void:
	flash("fx/glow", pos, 0.4, 1.4, Color(1.0, 0.85, 0.5, 0.9), 0.25)
	flash("fx/ring", pos, 0.2, 0.9, Color(1.0, 0.9, 0.6, 0.7), 0.3)
	for i: int in 14:
		var p := _spawn("fx/splinter", pos, _rng.randf_range(90, 240), 0.6)
		p.color = color.lightened(_rng.randf_range(-0.2, 0.2))
		p.scl = _rng.randf_range(0.7, 1.3)
	for i: int in clampi(coins / 3, 3, 14):
		var c := _spawn("fx/coin", pos, _rng.randf_range(80, 200), 1.6)
		c.homing = true
		c.home_after = _rng.randf_range(0.18, 0.35)
		c.drag = 4.0
		c.spin = 0.0
		c.rot = 0.0
		c.scl = 0.9
	shake(2.5)


## A tap lands on a crate: a quick white-gold pop and a few splinters, so every tap reads.
func crate_tap(pos: Vector2, color: Color) -> void:
	flash("fx/ring", pos, 0.15, 0.6, Color(1.0, 0.95, 0.75, 0.8), 0.18)
	flash("fx/glow", pos, 0.2, 0.55, Color(1.0, 0.9, 0.6, 0.7), 0.12)
	for i: int in 4:
		var p := _spawn("fx/splinter", pos, _rng.randf_range(60, 150), 0.35)
		p.color = color.lightened(_rng.randf_range(-0.1, 0.25))
		p.scl = _rng.randf_range(0.5, 0.9)


## A sieging enemy strikes the gate: a spark burst and a light jolt (strikes repeat every
## second per enemy, so this stays small; wall_hit is for the big moments).
func gate_strike(pos: Vector2, damage: float) -> void:
	flash("fx/glow", pos, 0.3, 0.8, Color(1.0, 0.45, 0.3, 0.8), 0.18)
	for i: int in 5:
		var s := _spawn("fx/glow", pos, _rng.randf_range(80, 200), 0.25)
		s.additive = true
		s.vel.y = -absf(s.vel.y)
		s.color = Color(1.0, 0.7, 0.35, 0.9)
		s.scl = 0.08
	shake(minf(1.0 + damage * 0.12, 4.0))


## A hit the enemy is weak to: a hot gold spark (the right weapon).
func weak_hit(pos: Vector2) -> void:
	flash("fx/glow", pos, 0.15, 0.5, Color(1.0, 0.85, 0.3, 0.95), 0.12)
	flash("fx/ring", pos, 0.1, 0.35, Color(1.0, 0.9, 0.5, 0.8), 0.14)


## A hit the enemy resists or its armour blunts: a dull grey ping (the wrong weapon).
func resisted_hit(pos: Vector2) -> void:
	flash("fx/glow", pos + Vector2(0, -6), 0.1, 0.25, Color(0.6, 0.62, 0.66, 0.7), 0.1)


## A spitter's glob lands on a unit: a lime splash and droplets.
func acid_splash(pos: Vector2) -> void:
	flash("fx/glow", pos, 0.4, 1.1, Color(0.83, 1.0, 0.35, 0.85), 0.3)
	flash("fx/ring", pos, 0.2, 0.8, Color(0.7, 1.0, 0.4, 0.7), 0.3)
	for i: int in 10:
		var d := _spawn("fx/glow", pos, _rng.randf_range(50, 140), 0.45)
		d.additive = true
		d.color = Color(0.7, 1.0, 0.3, 0.9)
		d.scl = _rng.randf_range(0.06, 0.12)


## Earth thrown up where a Burrower dives or breaks the surface: a brown puff and clods.
func dust(pos: Vector2) -> void:
	flash("fx/glow", pos, 0.4, 1.1, Color(0.55, 0.4, 0.25, 0.6), 0.35)
	for i: int in 8:
		var d := _spawn("fx/shard", pos, _rng.randf_range(40, 110), 0.4)
		d.color = Color(0.45, 0.32, 0.18, 1.0)
		d.scl = _rng.randf_range(0.25, 0.45)


## A hitscan shot: a bright tracer line that fades fast.
func tracer(a: Vector2, b: Vector2, color: Color) -> void:
	_streak(a, b, color, 3.0, 0.12)
	flash("fx/glow", b, 0.25, 0.45, Color(color, 0.9), 0.12)


## A rail shot: a thick beam with a hot core.
func beam(a: Vector2, b: Vector2, color: Color) -> void:
	_streak(a, b, color, 14.0, 0.3)
	_streak(a, b, Color(1, 1, 1, 0.9), 4.0, 0.22)
	flash("fx/glow", a, 0.5, 0.8, Color(color, 0.9), 0.2)
	shake(3.0)


## Something hits the wall: sparks and a red flash where it struck.
func wall_hit(pos: Vector2, strength: float) -> void:
	flash("fx/glow", pos, 0.6, 1.4 + strength * 0.05, Color(1.0, 0.35, 0.25, 0.9), 0.3)
	for i: int in 10:
		var s := _spawn("fx/glow", pos, _rng.randf_range(100, 260), 0.35)
		s.additive = true
		s.vel.y = -absf(s.vel.y)
		s.color = Color(1.0, 0.6, 0.3, 0.9)
		s.scl = 0.1
	shake(minf(4.0 + strength * 0.5, 16.0))


## A crate lost at the wall: a dull puff.
func poof(pos: Vector2) -> void:
	flash("fx/glow", pos, 0.4, 1.0, Color(0.6, 0.6, 0.6, 0.5), 0.3)


func ring(pos: Vector2, color: Color, radius: float, life: float = 0.4) -> void:
	flash("fx/ring", pos, radius * 0.005, radius / 32.0, color, life)


# --- primitives -------------------------------------------------------------------------

func flash(key: String, pos: Vector2, scl0: float, scl1: float, color: Color, life: float) -> void:
	if _flashes.size() >= MAX_FLASHES:
		_flashes.pop_front()
	var f := Flash.new()
	f.key = key
	f.pos = pos
	f.scl0 = scl0
	f.scl1 = scl1
	f.color = color
	f.life = life
	_flashes.append(f)


## Floating text at `pos` in text role `role` (UiTheme), rising `rise` px over `life` s.
func popup(text: String, pos: Vector2, color: Color = Color.WHITE, role: StringName = &"label",
		life: float = 0.8, rise: float = 50.0) -> void:
	var label: Label = _free_label()
	label.text = text
	UiTheme.restyle(label, role, color)
	label.reset_size()
	label.position = pos - label.size / 2.0
	if bounds_width > 0.0:
		label.position.x = clampf(label.position.x, 4.0, maxf(4.0, bounds_width - label.size.x - 4.0))
	label.modulate.a = 1.0
	label.visible = true
	_label_life[label] = Vector3(0.0, life, rise)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Current shake offset for the field; decays over time.
func shake_offset() -> Vector2:
	if _shake <= 0.1:
		return Vector2.ZERO
	return Vector2(_rng.randf_range(-_shake, _shake), _rng.randf_range(-_shake, _shake))


func particle_count() -> int:
	return _particles.size()


func clear() -> void:
	_particles.clear()
	_flashes.clear()
	_streaks.clear()
	for label: Label in _labels:
		label.visible = false
	_label_life.clear()
	_shake = 0.0
	queue_redraw()
	_add.queue_redraw()


func _spawn(key: String, pos: Vector2, speed: float, life: float) -> Particle:
	if _particles.size() >= MAX_PARTICLES:
		_particles.pop_front()
	var p := Particle.new()
	p.key = key
	p.pos = pos
	p.vel = Vector2.from_angle(_rng.randf() * TAU) * speed
	p.rot = _rng.randf() * TAU
	p.spin = _rng.randf_range(-12.0, 12.0)
	p.life = life * _rng.randf_range(0.75, 1.25)
	p.scl = 1.0
	p.color = Color.WHITE
	_particles.append(p)
	return p


func _streak(a: Vector2, b: Vector2, color: Color, width: float, life: float) -> void:
	var s := Streak.new()
	s.a = a
	s.b = b
	s.color = color
	s.width = width
	s.life = life
	_streaks.append(s)


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 40.0)
	var alive: Array[Particle] = []
	for p: Particle in _particles:
		p.age += delta
		if p.homing and p.age > p.home_after:
			var to: Vector2 = coin_target - p.pos
			if to.length() < 18.0:
				coin_arrived.emit()
				continue
			p.vel = p.vel.lerp(to.normalized() * 900.0, minf(1.0, delta * 6.0))
			p.life = p.age + 1.0  # coins live until they arrive
		else:
			p.vel *= maxf(0.0, 1.0 - p.drag * delta)
			p.vel.y += p.gravity * delta
		p.pos += p.vel * delta
		p.rot += p.spin * delta
		if p.age < p.life:
			alive.append(p)
	_particles = alive
	var flashes: Array[Flash] = []
	for f: Flash in _flashes:
		f.age += delta
		if f.age < f.life:
			flashes.append(f)
	_flashes = flashes
	var streaks: Array[Streak] = []
	for s: Streak in _streaks:
		s.age += delta
		if s.age < s.life:
			streaks.append(s)
	_streaks = streaks
	for label: Label in _label_life.keys():
		var st: Vector3 = _label_life[label]
		st.x += delta
		if st.x >= st.y:
			label.visible = false
			_label_life.erase(label)
			continue
		label.position.y -= st.z * delta / st.y
		label.modulate.a = 1.0 - maxf(0.0, (st.x / st.y - 0.6) / 0.4)
		_label_life[label] = st
	queue_redraw()
	_add.queue_redraw()


func _draw() -> void:
	for p: Particle in _particles:
		if p.additive:
			continue
		var fade: float = 1.0 if p.homing else clampf(1.0 - (p.age / p.life - 0.6) / 0.4, 0.0, 1.0)
		Art.draw(self, p.key, p.pos, p.rot, p.scl, Color(p.color, p.color.a * fade))


func _draw_add() -> void:
	for s: Streak in _streaks:
		var k: float = 1.0 - s.age / s.life
		_add.draw_line(s.a, s.b, Color(s.color, s.color.a * k), s.width * (0.4 + 0.6 * k))
	for f: Flash in _flashes:
		var k: float = f.age / f.life
		var ease_k: float = 1.0 - (1.0 - k) * (1.0 - k)
		Art.draw(_add, f.key, f.pos, f.rot, lerpf(f.scl0, f.scl1, ease_k),
				Color(f.color, f.color.a * (1.0 - k)))
	for p: Particle in _particles:
		if not p.additive:
			continue
		var fade: float = clampf(1.0 - p.age / p.life, 0.0, 1.0)
		Art.draw(_add, p.key, p.pos, 0.0, p.scl, Color(p.color, p.color.a * fade))


func _free_label() -> Label:
	for label: Label in _labels:
		if not _label_life.has(label):
			return label
	var label := Label.new()
	label.z_index = 10
	add_child(label)
	_labels.append(label)
	return label
