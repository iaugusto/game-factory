class_name MetaProgress
extends RefCounted
## Progress kept between runs: the brick balance and the level of each meta upgrade.

var bricks: int = 0
var levels: Dictionary[StringName, int] = {}


func level(upgrade: MetaUpgradeDef) -> int:
	return levels.get(upgrade.id, 0)


## Price of the next level, or -1 if maxed.
func next_cost(upgrade: MetaUpgradeDef) -> int:
	var lvl: int = level(upgrade)
	return upgrade.costs[lvl] if lvl < upgrade.max_level() else -1


func can_buy(upgrade: MetaUpgradeDef) -> bool:
	var cost: int = next_cost(upgrade)
	return cost >= 0 and bricks >= cost


func buy(upgrade: MetaUpgradeDef) -> bool:
	if not can_buy(upgrade):
		return false
	bricks -= next_cost(upgrade)
	levels[upgrade.id] = level(upgrade) + 1
	return true


## The starting modifiers of a new run, given the owned levels.
func to_modifiers(upgrades: Array[MetaUpgradeDef]) -> RunModifiers:
	var mods := RunModifiers.new()
	for upgrade: MetaUpgradeDef in upgrades:
		var lvl: int = level(upgrade)
		if lvl > 0:
			mods.add(upgrade.key, upgrade.value_per_level * lvl)
	return mods
