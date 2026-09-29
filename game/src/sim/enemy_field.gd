class_name EnemyField
extends Node2D
## Every enemy, batched: one textured MultiMesh per enemy type plus one shared shadow batch, fed
## from CombatSim's paths.
##
## Batching is the performance rule (B2 finding: one node per enemy cost ~600 draw calls at the
## budget load; batched, the whole field is a handful). Everything per-enemy that moves is
## instance data:
## - the transform carries the walk waddle and the spawn "emerge" scale;
## - custom data carries the hit flash and the walk frame (shaders/enemy.gdshader);
## - custom data also carries the frost overlay while slowed, and the ice while frozen solid
##   (a Cryo Bomb: CombatSim.Enemy.stun).
## HP bars are drawn in one pass by this node, only for damaged or tough enemies.
##
## At the gate (CombatSim.Enemy.sieging) an enemy stops walking, is drawn pressed against the
## wall's top edge rather than half under it, and lunges at the gate on every strike.
##
## Stage 2 enemies (docs/2026-09-27-content-expansion/): a flyer is drawn lifted and bobbing
## over a small, faint shadow left on the ground; a burrowed enemy is only a dirt mound (its own
## batch, under the sprites, with no HP bar); a shielded enemy wears a bubble that fades as the
## shield drains; Bombardiers' globs arc to the gate. The last two are drawn on the bar layer.

const CAPACITY: int = 512
const FLASH_TIME: float = 0.06
## Peak flash, and the gap before an enemy under sustained fire can flash again: a flicker,
## never a solid white blob.
const FLASH_PEAK: float = 0.55
const FLASH_GAP: float = 0.14
## Enemies at least this tough always show their bar; others only once damaged.
const HP_BAR_ALWAYS: float = 20.0
const ENEMY_SHADER := preload("res://shaders/enemy.gdshader")
## How far a strike's lunge reaches, and how long it takes to recoil (seconds).
const LUNGE: float = 7.0
const LUNGE_TIME: float = 0.22
## How high a flyer is drawn above its path, how much it bobs, and how high a glob arcs.
const FLY_HEIGHT: float = 12.0
const FLY_BOB: float = 2.5
const LOB_ARC: float = 90.0
const SHIELD_COLOR := Color("#7fe0ff")

var config: RunConfig
## enemy type id -> its MultiMeshInstance2D
var _batches: Dictionary[StringName, MultiMeshInstance2D] = {}
var _box: Dictionary[StringName, float] = {}
var _shadows: MultiMeshInstance2D
var _mounds: MultiMeshInstance2D
## Shield bubbles: one batch over the sprites (a bubble per shielded enemy was one draw call
## each: ~1800 at the mixed stress load).
var _bubbles: MultiMeshInstance2D
var _sim: CombatSim
var _shielded: Array[CombatSim.Enemy] = []
var _t: float = 0.0
## enemy id -> [last seen hp, time since the last flash started]
var _hits: Dictionary[int, Vector2] = {}
var _bars: Array[CombatSim.Enemy] = []
var _drawn: int = 0
var _material: ShaderMaterial
## HP bars go on their own layer above the batches (a node's own _draw renders beneath its
## children).
var _bar_layer: Node2D


func setup(run_config: RunConfig) -> void:
	config = run_config
	if _shadows == null:
		_material = ShaderMaterial.new()
		_material.shader = ENEMY_SHADER
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = Art.quad(Vector2(64, 32))
		mm.instance_count = CAPACITY
		mm.visible_instance_count = 0
		_shadows = MultiMeshInstance2D.new()
		_shadows.multimesh = mm
		_shadows.texture = Art.tex("fx/shadow")
		add_child(_shadows)
		var mounds := MultiMesh.new()
		mounds.transform_format = MultiMesh.TRANSFORM_2D
		mounds.mesh = Art.quad(Vector2(48, 36))
		mounds.instance_count = CAPACITY
		mounds.visible_instance_count = 0
		_mounds = MultiMeshInstance2D.new()
		_mounds.multimesh = mounds
		_mounds.texture = Art.tex("fx/mound")
		add_child(_mounds)
		var bubbles := MultiMesh.new()
		bubbles.transform_format = MultiMesh.TRANSFORM_2D
		bubbles.use_colors = true
		bubbles.mesh = Art.quad(Vector2(64, 64))
		bubbles.instance_count = CAPACITY
		bubbles.visible_instance_count = 0
		_bubbles = MultiMeshInstance2D.new()
		_bubbles.multimesh = bubbles
		_bubbles.texture = Art.tex("fx/bubble")
		_bubbles.z_index = 1  # over every enemy batch, under the HP bars' layer order
		add_child(_bubbles)
		_bar_layer = Node2D.new()
		_bar_layer.z_index = 1
		_bar_layer.draw.connect(_draw_bars)
		add_child(_bar_layer)


## Where an enemy is drawn: the sim's position, held back at the wall's top edge (the sim's
## gate line is wall_y; the drawn wall starts above it), plus the strike lunge at the gate.
func position_of(e: CombatSim.Enemy) -> Vector2:
	var edge: float = config.wall_y - FieldView.WALL_TOP_OFFSET - e.def.radius * 0.45
	var p := Vector2(e.x, minf(e.y, edge))
	if e.sieging:
		var since: float = maxf(0.05, e.def.attack_interval) - e.strike_timer
		p.y += LUNGE * maxf(0.0, 1.0 - since / LUNGE_TIME) * (-0.6 if e.lobbing else 1.0)
	if e.def.flying:
		p.y -= FLY_HEIGHT + FLY_BOB * sin(_t * 9.0 + e.id)
	return p


## Enemies drawn in the last sync (for tests and diagnostics).
func drawn_count() -> int:
	return _drawn


## Burrowers drawn as mounds, and shield bubbles, in the last sync (for tests).
func mound_count() -> int:
	return _mounds.multimesh.visible_instance_count if _mounds != null else 0


func bubble_count() -> int:
	return _bubbles.multimesh.visible_instance_count if _bubbles != null else 0


## Batches that exist (one per enemy type seen), for tests.
func batch_count() -> int:
	return _batches.size()


func forget(enemy_id: int) -> void:
	_hits.erase(enemy_id)


func clear() -> void:
	_hits.clear()
	for batch: MultiMeshInstance2D in _batches.values():
		batch.multimesh.visible_instance_count = 0
	if _shadows != null:
		_shadows.multimesh.visible_instance_count = 0
		_mounds.multimesh.visible_instance_count = 0
		_bubbles.multimesh.visible_instance_count = 0
	_shielded.clear()
	_bars.clear()
	_drawn = 0
	if _bar_layer != null:
		_bar_layer.queue_redraw()


func sync(sim: CombatSim, delta: float) -> void:
	var counts: Dictionary[StringName, int] = {}
	_sim = sim
	_t += delta
	_bars.clear()
	_shielded.clear()
	_drawn = 0
	var mounds: int = 0
	var shadow_mm: MultiMesh = _shadows.multimesh
	var mound_mm: MultiMesh = _mounds.multimesh
	for group: Array in sim.path_enemies:
		for e: CombatSim.Enemy in group:
			if e.burrowed():
				if mounds < CAPACITY:
					var k: float = e.def.radius / 14.0 * (1.0 + 0.06 * sin(_t * 14.0 + e.id))
					mound_mm.set_instance_transform_2d(mounds, Transform2D(0.0, Vector2(k, k), 0.0,
							Vector2(e.x, e.y)))
					mounds += 1
				continue
			if e.shield > 0.05:
				_shielded.append(e)
			var batch: MultiMeshInstance2D = _batch_for(e.def)
			var i: int = counts.get(e.def.id, 0)
			if i >= CAPACITY or _drawn >= CAPACITY:
				continue
			counts[e.def.id] = i + 1
			var box: float = _box[e.def.id]
			var stride: float = maxf(6.0, box * 0.2)
			var phase: float = e.y / stride
			var emerge: float = clampf(0.55 + e.y / 60.0, 0.55, 1.0)
			var rot: float = sin(phase * PI) * 0.06
			var p: Vector2 = position_of(e)
			var mm: MultiMesh = batch.multimesh
			mm.set_instance_transform_2d(i, Transform2D(rot, Vector2.ONE * emerge, 0.0, p))
			mm.set_instance_color(i, e.elite.tint if e.elite != null else Color.WHITE)
			mm.set_instance_custom_data(i, Color(_flash(e, delta), float(int(phase) % 2),
					_frost(e), 0))
			var sw: float = e.def.radius * 2.6 / 64.0 * emerge
			var ground: Vector2 = Vector2(p.x, e.y) if e.def.flying else p
			if e.def.flying:
				sw *= 0.7  # a small shadow, left on the ground below it
			shadow_mm.set_instance_transform_2d(_drawn, Transform2D(0.0, Vector2(sw, sw),
					0.0, ground + Vector2(e.def.radius * 0.25, e.def.radius * 0.55)))
			shadow_mm.set_instance_color(_drawn, Color(1, 1, 1, 0.45 if e.def.flying else 0.8))
			if e.hp < e.max_hp or e.def.hp >= HP_BAR_ALWAYS or e.elite != null:
				_bars.append(e)
			_drawn += 1
	for id: StringName in _batches:
		_batches[id].multimesh.visible_instance_count = counts.get(id, 0)
	shadow_mm.visible_instance_count = _drawn
	mound_mm.visible_instance_count = mounds
	var bubble_mm: MultiMesh = _bubbles.multimesh
	var n: int = mini(_shielded.size(), CAPACITY)
	for i: int in n:
		var e: CombatSim.Enemy = _shielded[i]
		var k: float = clampf(e.shield / maxf(0.001, maxf(e.shield_max, e.shield)), 0.0, 1.0)
		var r: float = (e.def.radius * 1.35 + 3.0) / 30.0
		bubble_mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(r, r), 0.0, position_of(e)))
		bubble_mm.set_instance_color(i, Color(SHIELD_COLOR, 0.35 + 0.6 * k))
	bubble_mm.visible_instance_count = n
	_bar_layer.queue_redraw()


## Tracks hp per enemy; returns the flash amount: FLASH_PEAK fading over FLASH_TIME after a
## hit, retriggered at most every FLASH_GAP.
func _flash(e: CombatSim.Enemy, delta: float) -> float:
	var st: Vector2 = _hits.get(e.id, Vector2(e.hp, INF))
	st.y += delta
	if e.hp < st.x:
		st.x = e.hp
		if st.y >= FLASH_GAP:
			st.y = 0.0
	_hits[e.id] = st
	return FLASH_PEAK * maxf(0.0, 1.0 - st.y / FLASH_TIME)


func _draw_bars() -> void:
	var ci: Node2D = _bar_layer
	if _sim != null:
		for lob: CombatSim.Lob in _sim.lobs:
			var t: float = clampf(lob.t / lob.duration, 0.0, 1.0)
			var dest := Vector2(lob.dest.x, lob.dest.y - FieldView.WALL_TOP_OFFSET)
			var at: Vector2 = lob.start.lerp(dest, t) - Vector2(0.0, LOB_ARC * 4.0 * t * (1.0 - t))
			Art.draw(ci, "fx/glob", at, 0.0, 1.0)
	for e: CombatSim.Enemy in _bars:
		var p: Vector2 = position_of(e)
		var w: float = clampf(e.def.radius * 2.0, 18.0, 70.0)
		var h: float = 4.0 if e.def.radius < 30.0 else 6.0
		var top: float = p.y - _box[e.def.id] * 0.42 - h - 2.0
		var ratio: float = clampf(e.hp / e.max_hp, 0.0, 1.0)
		var rect := Rect2(p.x - w / 2.0, top, w, h)
		ci.draw_rect(rect.grow(1.0), Color(0.05, 0.03, 0.04, 0.85))
		ci.draw_rect(Rect2(rect.position, Vector2(w * ratio, h)), _bar_color(ratio))
		ci.draw_rect(Rect2(rect.position, Vector2(w * ratio, h * 0.4)), Color(1, 1, 1, 0.25))
		if e.elite != null:  # a star over elites, in their tint
			var c := Vector2(p.x - w / 2.0 - 7.0, top + h / 2.0)
			var pts := PackedVector2Array()
			for k: int in 10:
				var r: float = 6.0 if k % 2 == 0 else 2.6
				pts.append(c + Vector2.from_angle(-PI / 2.0 + k * PI / 5.0) * r)
			ci.draw_colored_polygon(pts, e.elite.tint)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.8), 1.0)


## The frost channel of an enemy's custom data: 0 none, 0.5 slowed (icy overlay), 1 frozen
## solid. One channel for both: the alpha channel of custom data doesn't reach the shader on the
## compatibility renderer.
static func _frost(e: CombatSim.Enemy) -> float:
	if e.stun > 0.0:
		return 1.0
	return 0.5 if e.slow_factor < 1.0 else 0.0


static func _bar_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color("#ffd24a").lerp(Color("#7de07d"), (ratio - 0.5) * 2.0)
	return Color("#ff5a4a").lerp(Color("#ffd24a"), ratio * 2.0)


func _batch_for(def: EnemyDef) -> MultiMeshInstance2D:
	if _batches.has(def.id):
		return _batches[def.id]
	var key: String = "enemies/%s" % def.id
	var tex: Texture2D = Art.tex(key)
	if tex == null:
		tex = Art.tex("enemies/grunt")
	var box: float = tex.get_size().y * Art.SPRITE_SCALE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = Art.quad(Vector2(box, box))
	mm.instance_count = CAPACITY
	mm.visible_instance_count = 0
	var batch := MultiMeshInstance2D.new()
	batch.multimesh = mm
	batch.texture = tex
	batch.material = _material
	add_child(batch)
	_batches[def.id] = batch
	_box[def.id] = box
	return batch
