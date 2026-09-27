class_name MetaUpgradeDef
extends Resource
## A permanent upgrade bought with bricks between runs. Each level adds `value_per_level` to the
## RunModifiers field `key` at the start of every run. `costs[i]` is the price of level i + 1.

@export var id: StringName
@export var title: String = ""
@export var description: String = ""
@export var key: StringName
@export var value_per_level: float = 0.0
@export var costs: PackedInt32Array = PackedInt32Array()


func max_level() -> int:
	return costs.size()
