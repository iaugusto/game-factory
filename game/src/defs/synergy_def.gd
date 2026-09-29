class_name SynergyDef
extends Resource
## What two unit types do for each other when their pads stand within RunConfig.synergy_range
## (docs/2026-09-27-artillery-and-synergies/). Every unordered pair of unit types has exactly
## one (content_test). For a same-type pair, both units get `bonus_a`.

@export var id: StringName
@export var title: String = ""
@export var description: String = ""
@export var unit_a: StringName
@export var unit_b: StringName
@export var bonus_a: StatBonus
@export var bonus_b: StatBonus


func involves(a: StringName, b: StringName) -> bool:
	return (unit_a == a and unit_b == b) or (unit_a == b and unit_b == a)


## The bonus the unit of type `unit_id` gets from this synergy.
func bonus_for(unit_id: StringName) -> StatBonus:
	if unit_a == unit_b or unit_id == unit_a:
		return bonus_a
	return bonus_b
