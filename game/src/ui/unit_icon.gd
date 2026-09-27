class_name UnitIcon
extends Control
## A unit as it looks on the field (base + head, head pointing up), scaled into a UI box.

var unit: UnitDef:
	set(v):
		unit = v
		queue_redraw()
var dimmed: bool = false:
	set(v):
		dimmed = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if unit == null:
		return
	var c: Vector2 = size / 2.0
	var s: float = minf(size.x, size.y) / 60.0
	var tint := Color(0.45, 0.45, 0.45) if dimmed else Color.WHITE
	var base: String = "units/base_troop" if unit.role == UnitDef.Role.TROOP \
			else "units/base_emplacement"
	Art.draw(self, base, c, 0.0, s, tint)
	Art.draw(self, "units/%s" % unit.id, c, 0.0, s, tint)
