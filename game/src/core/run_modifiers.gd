class_name RunModifiers
extends RefCounted
## Additive bonuses that cards (during a run) and meta upgrades (at run start) feed into.
##
## Every field defaults to "no effect", and content refers to fields by name (CardDef.key,
## MetaUpgradeDef.key), so adding a new kind of bonus is one field here
## plus whatever reads it.

var start_gold_bonus: float = 0.0
var wall_hp_bonus: float = 0.0
## Wall HP restored per second during waves.
var wall_regen: float = 0.0
## Fractions: 0.25 = +25%.
var gold_bonus: float = 0.0
var runner_gold_bonus: float = 0.0
var crate_reward_bonus: float = 0.0
## Taps deal this much more damage to crates.
var crate_damage_bonus: float = 0.0
var unit_cost_discount: float = 0.0
## Units reload this much faster: reload / (1 + bonus).
var unit_rate_bonus: float = 0.0
var unit_damage_bonus: float = 0.0
var unit_reach_bonus: float = 0.0
## Chance for a unit's shot to deal config.crit_multiplier (+ crit_mult_bonus) × damage.
var crit_chance: float = 0.0
var crit_mult_bonus: float = 0.0
var frost_slow_bonus: float = 0.0


## True if `key` names a modifier field (used to validate content).
static func has_key(key: StringName) -> bool:
	for prop: Dictionary in RunModifiers.new().get_property_list():
		if prop["name"] == String(key) and prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			return true
	return false


## Add `value` to the field `key`. Returns false (and changes nothing) for an unknown key.
func add(key: StringName, value: float) -> bool:
	if not has_key(key):
		push_error("RunModifiers: unknown key '%s'" % key)
		return false
	set(key, float(get(key)) + value)
	return true


func duplicate_mods() -> RunModifiers:
	var copy := RunModifiers.new()
	for prop: Dictionary in get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			copy.set(prop["name"], get(prop["name"]))
	return copy
