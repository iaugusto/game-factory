class_name CrateSpawn
extends Resource
## One crate within a wave, appearing at `time` seconds on `path` (-1 = a random open path).

@export var crate: CrateDef
@export var time: float = 0.0
@export var path: int = -1
