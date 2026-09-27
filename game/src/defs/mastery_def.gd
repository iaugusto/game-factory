class_name MasteryDef
extends Resource
## A specialisation bought once for a unit at max level (docs/2026-09-26-counters-and-coin-sinks):
## either the shared "Overcharge" (+25% damage) or the unit's own trait. Every field defaults
## to "no effect", so a trait is just the few fields it changes.

@export var id: StringName
@export var title: String = ""
@export var description: String = ""
## Fractions: 0.25 = +25% damage; reload_bonus 0.25 = reloads 25% faster (reload / 1.25).
@export var damage_bonus: float = 0.0
@export var reach_bonus: float = 0.0
@export var reload_bonus: float = 0.0
@export var splash_bonus: float = 0.0
## Slow factor lowered by this (0.25: half speed becomes a quarter), and seconds added to it.
@export var slow_bonus: float = 0.0
@export var slow_time_bonus: float = 0.0
## Fraction of the target's armour ignored (1.0 = all of it).
@export var armor_pierce: float = 0.0
