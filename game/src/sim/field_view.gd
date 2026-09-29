class_name FieldView
extends Node2D
## The battlefield: the map's painted ground (field/ground_<map id>, generated from the map's
## own paths, plots and zones), portals that haven't opened yet (sealed, with the wave they
## break open on; a newly opened one flares), a decal layer (goo splats and scorch marks that
## fade), and the wall (drawn above the field's moving objects via z_index, tinted as it takes
## damage).

const WALL_TOP_OFFSET: float = 16.0
const DECAL_CAP: int = 48
const DECAL_LIFE: float = 6.0

var config: RunConfig
## Waves (1-based) at which each path's portal opens, and the wave at hand (for sealed portals).
var wave_number: int = 1
var ground: Sprite2D
var _portal_layer: Node2D
var _t: float = 0.0
var wall: Sprite2D
var wall_ratio: float = 1.0:
	set(v):
		wall_ratio = v
		if wall != null:
			var hurt: float = 1.0 - clampf(v, 0.0, 1.0)
			wall.modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.5), hurt * 0.8)

## Fading ground decals: [texture key, position, rotation, scale, tint, age].
var _decals: Array[Array] = []
var _decal_layer: Node2D


func setup(run_config: RunConfig) -> void:
	config = run_config
	if ground == null:
		ground = Sprite2D.new()
		ground.centered = false
		ground.scale = Vector2.ONE * Art.FIELD_SCALE
		add_child(ground)
		_portal_layer = Node2D.new()
		_portal_layer.draw.connect(_draw_portals)
		add_child(_portal_layer)
		_decal_layer = Node2D.new()
		_decal_layer.draw.connect(_draw_decals)
		add_child(_decal_layer)
		wall = Sprite2D.new()
		wall.centered = false
		wall.texture = Art.tex("field/wall")
		wall.scale = Vector2.ONE * Art.FIELD_SCALE
		wall.z_index = 5
		add_child(wall)
	wall.position = Vector2(0, config.wall_y - WALL_TOP_OFFSET)
	var key: String = "field/ground_%s" % config.map.id
	ground.texture = Art.tex(key)
	ground.modulate = UiTheme.look.field_tint
	# The painted ground is authored at 540 wide; stretch it if a config's field differs.
	var gs: Vector2 = Art.size(key)
	ground.scale = Vector2(config.playfield_width() / gs.x, config.wall_y / gs.y) * Art.FIELD_SCALE \
			if gs.x > 0.0 else Vector2.ONE


func add_decal(key: String, pos: Vector2, tint: Color, scl: float, rot: float) -> void:
	if _decals.size() >= DECAL_CAP:
		_decals.pop_front()
	_decals.append([key, pos, rot, scl, tint, 0.0])


func clear_decals() -> void:
	_decals.clear()
	_decal_layer.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _portal_layer != null and config != null:
		_portal_layer.queue_redraw()
	if _decals.is_empty():
		return
	var keep: Array[Array] = []
	for d: Array in _decals:
		d[5] = float(d[5]) + delta
		if float(d[5]) < DECAL_LIFE:
			keep.append(d)
	_decals = keep
	_decal_layer.queue_redraw()


## Portals not open yet: a sealed burrow and "W4". The portal opening this very wave pulses
## (its breach was just announced).
func _draw_portals() -> void:
	for path: PathDef in config.map.paths:
		if path.points.is_empty():
			continue
		var p := Vector2(clampf(path.points[0].x, 24.0, config.playfield_width() - 24.0),
				maxf(path.points[0].y, 4.0) + 6.0)
		if path.opens_at_wave > wave_number:
			Art.draw(_portal_layer, "field/portal_sealed", p)
			var font: Font = ThemeDB.fallback_font
			var text: String = "W%d" % path.opens_at_wave
			_portal_layer.draw_string_outline(font, p + Vector2(-12, 30), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.look.caption + 1, 5, Color(0, 0, 0, 0.9))
			_portal_layer.draw_string(font, p + Vector2(-12, 30), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.look.caption + 1, Color("#ff7ab0"))
		elif path.opens_at_wave == wave_number and path.opens_at_wave > 1:
			var k: float = 0.5 + 0.5 * sin(_t * 5.0)
			Art.draw(_portal_layer, "fx/ring", p, 0.0, 1.4 + 0.6 * k, Color(1.0, 0.35, 0.6, 0.5 * k))


func _draw_decals() -> void:
	for d: Array in _decals:
		var tint: Color = d[4]
		var fade: float = 1.0 - clampf((float(d[5]) - DECAL_LIFE * 0.6) / (DECAL_LIFE * 0.4), 0.0, 1.0)
		Art.draw(_decal_layer, d[0], d[1], d[2], d[3], Color(tint, tint.a * fade))
