class_name CrateDef
extends Resource
## A loot crate that drifts down a path. Only the player's taps break it (units never shoot
## crates); breaking it pays `reward` coins, and a boost crate also speeds up every unit's fire
## for a while. A crate that reaches the wall is lost. Crates are the main source of coins
## (kills pay a trickle).

@export var id: StringName
@export var display_name: String = ""
## In taps at the base RunConfig.tap_damage of 1.
@export var hp: float = 15.0
@export var reward: int = 10
## Units per second along its path.
@export var speed: float = 35.0
## Visual half-size; taps within radius + RunConfig.tap_slop hit it.
@export var radius: float = 18.0
## Boost crates: every unit fires this many times as fast for `boost_duration` seconds
## (1.0 = no boost).
@export var boost_rate_mult: float = 1.0
@export var boost_duration: float = 0.0
@export var color: Color = Color.WHITE


func is_boost() -> bool:
	return boost_rate_mult != 1.0 and boost_duration > 0.0
