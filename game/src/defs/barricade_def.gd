class_name BarricadeDef
extends Resource
## The one barricade the player may raise on a slot in front of the wall (MapDef
## .barricade_slots). Enemies on every path through it stop and attack it until it breaks, which makes a
## kill zone; its level sets its HP. Broken, it stays as rubble until repaired.

## HP at level 1, 2, 3, ... Its size is the number of levels.
@export var hp_per_level: PackedFloat32Array = PackedFloat32Array([60.0, 140.0, 260.0])
## Price of level 1 (building it), then of each upgrade.
@export var costs: PackedInt32Array = PackedInt32Array([30, 40, 60])
## Coins per HP restored (rounded up).
@export var repair_cost_per_hp: float = 0.25


func max_level() -> int:
	return hp_per_level.size()


func hp_at(level: int) -> float:
	return hp_per_level[clampi(level, 1, max_level()) - 1]
