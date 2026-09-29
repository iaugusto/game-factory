class_name StatBonus
extends Resource
## Bonuses to one unit's stats, from a synergy (docs/2026-09-27-artillery-and-synergies/).
## Every field defaults to "no effect". Synergies.compute sums the bonuses of a plot's links
## into one StatBonus per plot, which CombatSim folds into that plot's stats.

## Fractions: 0.15 = +15% damage; reload 0.15 = reloads 15% faster (reload / 1.15).
@export var damage: float = 0.0
@export var reload: float = 0.0
@export var reach: float = 0.0
@export var splash: float = 0.0
## Slow factor lowered by this, and seconds added to it (slowing units only).
@export var slow: float = 0.0
@export var slow_time: float = 0.0
## Fraction of the target's armour ignored.
@export var pierce: float = 0.0
## Added crit chance.
@export var crit: float = 0.0
## Extra targets for a beam.
@export var beam_targets: int = 0
## A unit that doesn't slow makes its hits slow: speed × chill for chill_time seconds.
@export var chill: float = 1.0
@export var chill_time: float = 0.0


## Add `o` into this one. Chill keeps the strongest (lowest factor, longest time).
func accumulate(o: StatBonus) -> void:
	damage += o.damage
	reload += o.reload
	reach += o.reach
	splash += o.splash
	slow += o.slow
	slow_time += o.slow_time
	pierce += o.pierce
	crit += o.crit
	beam_targets += o.beam_targets
	chill = minf(chill, o.chill)
	chill_time = maxf(chill_time, o.chill_time)


## A one-line summary for the UI ("+15% dmg, +20% reach").
func summary() -> String:
	var parts: PackedStringArray = []
	if damage != 0.0:
		parts.append("%+d%% dmg" % roundi(damage * 100))
	if reload != 0.0:
		parts.append("%+d%% fire rate" % roundi(reload * 100))
	if reach != 0.0:
		parts.append("%+d%% reach" % roundi(reach * 100))
	if splash != 0.0:
		parts.append("%+d%% splash" % roundi(splash * 100))
	if slow != 0.0 or slow_time != 0.0:
		parts.append("stronger slow")
	if pierce != 0.0:
		parts.append("%d%% armour pierce" % roundi(pierce * 100))
	if crit != 0.0:
		parts.append("%+d%% crit" % roundi(crit * 100))
	if beam_targets != 0:
		parts.append("%+d beam targets" % beam_targets)
	if chill < 1.0 and chill_time > 0.0:
		parts.append("hits chill")
	return ", ".join(parts)


func is_empty() -> bool:
	return summary() == ""
