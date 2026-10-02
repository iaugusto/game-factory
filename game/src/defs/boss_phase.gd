class_name BossPhase
extends Resource
## One phase of a boss (EnemyDef.phases): when the boss's HP falls to `at_hp_fraction` of its
## max, this fires once, in order (docs/2026-09-27-content-expansion/, Stage 3). A phase may
## spawn a brood or an escort, change the boss's armour and speed, and stop it for a moment.
## Bosses are content: a new boss is a new .tres, not new code.


## Fires when hp <= at_hp_fraction × max_hp. 1.0 fires as the boss arrives (an opening escort).
## A boss's phases are listed from the highest fraction down; one hit can fire several.
@export_range(0.0, 1.0) var at_hp_fraction: float = 0.5
## A line the view pops over the boss when the phase fires ("" = none).
@export var callout: String = ""

@export_group("Spawn")
## `spawn_count` of `spawn` appear just ahead of the boss on its path, spread sideways, scaled
## by the wave like any spawn.
@export var spawn: EnemyDef
@export var spawn_count: int = 0
## The spawns walk at the boss's speed (never faster than their own), so they stay beside it.
@export var keep_pace: bool = false
## The spawns guard the boss: it takes no damage while any of them lives.
@export var guard: bool = false

@export_group("Boss")
## Added to the boss's armour (negative sheds it).
@export var armor_delta: float = 0.0
## Multiplies the boss's speed from now on.
@export var speed_mult: float = 1.0
## The boss stops (no walking, no striking) for this long while the phase plays out.
@export var pause_seconds: float = 0.0
