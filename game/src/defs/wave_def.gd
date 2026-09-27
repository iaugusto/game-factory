class_name WaveDef
extends Resource
## One wave: its enemy groups and its loot crates. Turned into timed events by WaveSchedule.

@export var spawns: Array[SpawnEntry] = []
## Difficulty ramp across the run (B2 feedback: enemies should get tougher and faster over
## time). Every enemy in this wave spawns with its EnemyDef hp and speed times these.
@export var hp_scale: float = 1.0
@export var speed_scale: float = 1.0
@export var crates: Array[CrateSpawn] = []
