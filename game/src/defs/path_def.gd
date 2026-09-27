class_name PathDef
extends Resource
## One way from a spawn portal to the gate (docs/2026-09-26-maps-from-paths/). A polyline whose
## y strictly increases: it may bend sideways but never turns back up the field, so order along
## a path is order in y (targeting stays a binary search). It ends on the gate line
## (RunConfig.wall_y). Two paths that share a stretch of centre line are a merge or a fork.

@export var points: PackedVector2Array = PackedVector2Array()
## How far enemies stray either side of the centre line (big ones less; RunConfig.jitter_for).
@export var spread: float = 30.0
## The wave (1-based) whose build phase opens this path's portal; before it, nothing spawns
## on it.
@export var opens_at_wave: int = 1
