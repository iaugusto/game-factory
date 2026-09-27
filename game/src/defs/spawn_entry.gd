class_name SpawnEntry
extends Resource
## A group of one enemy type within a wave: `count` enemies, starting at `start` seconds,
## one every `interval` seconds, on `path` (MapDef.paths index; -1 = a random open path per
## enemy).

@export var enemy: EnemyDef
@export var count: int = 1
@export var start: float = 0.0
@export var interval: float = 1.0
@export var path: int = -1
## Makes the whole group elite (null = normal).
@export var elite: EliteDef
