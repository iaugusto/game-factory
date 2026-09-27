class_name ZoneDef
extends Resource
## A patch of terrain on a map (a circle): mud slows enemies walking through it; high ground
## gives pads on it extra reach. Visible on the field, so its effect is readable.

enum Kind { MUD, HIGH_GROUND }

@export var kind: Kind = Kind.MUD
@export var center: Vector2 = Vector2.ZERO
@export var radius: float = 60.0
## MUD: enemy speed multiplier inside (0.6 = 40% slower). HIGH_GROUND: reach bonus (0.25).
@export var value: float = 0.6


func contains(p: Vector2) -> bool:
	return center.distance_squared_to(p) <= radius * radius
