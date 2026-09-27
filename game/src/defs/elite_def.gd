class_name EliteDef
extends Resource
## An elite variant of any enemy (docs/2026-09-26-new-enemies-and-destroyable-units/): the same
## shape with one property changed, so it asks for a different weapon rather than a new lesson.
## A SpawnEntry marks its whole group elite; the view tints them and puts a star over them.

@export var id: StringName
@export var title: String = ""
@export var description: String = ""
@export var hp_mult: float = 1.0
@export var speed_mult: float = 1.0
## Added to the enemy's armour (flat damage off every hit).
@export var armor_bonus: float = 0.0
## Fraction of max HP healed per second.
@export var regen: float = 0.0
@export var tint: Color = Color.WHITE
