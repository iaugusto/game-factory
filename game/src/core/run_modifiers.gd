class_name RunModifiers
extends RefCounted
## Additive bonuses that cards (during a run) and skill-tree nodes (at run start) feed into.
##
## Every field defaults to "no effect", and content refers to fields by name (CardDef.key,
## SkillDef.key), so adding a new kind of bonus is one field here plus whatever reads it.

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
## Coins from kills *and* crates (the tree's "+10% loot"); stacks with the two above.
var loot_bonus: float = 0.0
## Units get this much more max HP (a fraction).
var unit_hp_bonus: float = 0.0
## A destroyed unit explodes: this much EXPLOSIVE damage per unit level, within
## RunConfig.death_blast_radius of its pad (0: no blast).
var death_blast: float = 0.0
## >= 1: the run opens with the barricade standing at level 1 on the map's first slot.
var start_barricade: float = 0.0
## Units are built this many levels up (capped at max), for the price of level 1.
var veteran_level: float = 0.0
## Gate repairs heal this much more (a fraction).
var gate_repair_bonus: float = 0.0
## Free rerolls of each card offer.
var card_rerolls: float = 0.0
## Extra cards in each offer.
var extra_cards: float = 0.0
## Masteries cost this much less (a fraction; stacks with the unit discount).
var mastery_discount: float = 0.0
## Enemies striking the gate take this much damage per second of their strike interval.
var gate_thorns: float = 0.0
## The special attack reloads this much faster (a fraction off its cooldown).
var ability_cooldown_bonus: float = 0.0
## Special attacks hit this much harder (a fraction on their damage; E8 Stage 4's tier-6 node).
var ability_power_bonus: float = 0.0


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
