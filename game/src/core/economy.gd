class_name Economy
extends RefCounted
## Coin income and prices. Stateless; the run's coins live in Run.gold.
##
## Crates are the main income (crate_reward); kills pay a small trickle (kill_reward).


## Coins for killing one enemy, with the run's bonuses (rounded, never below the base).
static func kill_reward(enemy: EnemyDef, mods: RunModifiers) -> int:
	var mult: float = 1.0 + mods.gold_bonus + mods.loot_bonus
	if enemy.is_runner:
		mult += mods.runner_gold_bonus
	return maxi(enemy.gold, roundi(enemy.gold * mult))


## Coins for breaking a crate (rounded, never below the base).
static func crate_reward(crate: CrateDef, mods: RunModifiers) -> int:
	return maxi(crate.reward, roundi(crate.reward * (1.0 + mods.crate_reward_bonus
			+ mods.loot_bonus)))


## Price after the run's discount (rounded up, never below 1, discount capped at 90%).
static func discounted(price: int, mods: RunModifiers) -> int:
	var discount: float = clampf(mods.unit_cost_discount, 0.0, 0.9)
	return maxi(1, ceili(price * (1.0 - discount)))


static func unit_cost(unit: UnitDef, mods: RunModifiers) -> int:
	return discounted(unit.cost, mods)


## Price to go from `current_level` to the next, or -1 if already at max level.
static func unit_upgrade_cost(unit: UnitDef, current_level: int, mods: RunModifiers) -> int:
	var index: int = current_level - 1
	if index < 0 or index >= unit.upgrade_costs.size():
		return -1
	return discounted(unit.upgrade_costs[index], mods)
