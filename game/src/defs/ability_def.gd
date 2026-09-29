class_name AbilityDef
extends Resource
## A special attack: the one the player picks when a map starts (RunController's picker) and
## calls during waves from the ability button (Run.call_ability). Abilities are content: adding
## one is a .tres in data/abilities/ plus an entry in RunConfig.abilities. What it does is one of
## a few effect kinds, resolved by CombatSim (docs/2026-09-27-content-expansion/).
##
## Every attack is ready at each wave's start, then reloads for `cooldown` s of wave time. Damage
## ignores the counter chart and armour (the answer that is never wrong, paid for by the reload),
## and scales with the wave's hp_scale like the enemies it hits.

enum Kind {
	## A shell lands after `delay`: `damage` to everything within `radius`.
	STRIKE,
	## Everything within `radius` is frozen solid for `duration` s (no walking, striking,
	## spitting or healing), then slowed to `slow` for `slow_time` s more.
	FREEZE,
	## A stretch of road `length` long on the path nearest the tap, centred on it, burns for
	## `duration` s: `damage` per second to every enemy walking on it (on any path sharing it).
	BURN,
	## `mine_count` mines along the path nearest the tap, `mine_spacing` apart. Each goes off when
	## an enemy walks onto it: `damage` to everything within `radius`. They last for the wave.
	MINES,
	## Not aimed: the gate gets `gate_heal` HP back, and every unit and the barricade
	## `unit_heal` of their max HP.
	REPAIR,
}

@export var id: StringName
@export var display_name: String = ""
## The ability button's label (a word).
@export var short_name: String = ""
## One line for the pick card and the tutorial.
@export var description: String = ""
## Art key of its icon (button, pick card, tutorial).
@export var icon: String = ""
## A looping clip of it in action for the first-time tutorial (res://clips/*.ogv), or "".
@export_file("*.ogv") var clip: String = ""
@export var kind: Kind = Kind.STRIKE
## The map whose first win unlocks it (&"": unlocked from the start).
@export var unlocked_by: StringName = &""

@export_group("Timing")
## Seconds of wave time to reload after a call.
@export var cooldown: float = 30.0
## Seconds between the call and the effect landing (the telegraph).
@export var delay: float = 0.5

@export_group("Effect")
## STRIKE/FREEZE: the blast radius. MINES: each mine's blast.
@export var radius: float = 70.0
## × the wave's hp_scale. STRIKE: once; BURN: per second; MINES: per mine.
@export var damage: float = 0.0
## FREEZE: seconds frozen. BURN: seconds burning.
@export var duration: float = 0.0
## FREEZE: the slow after the thaw (speed multiplier) and how long it lasts.
@export var slow: float = 1.0
@export var slow_time: float = 0.0
## BURN: how much of the road burns, measured along the path (its width is the road's).
@export var length: float = 0.0
## MINES: how many, and how far apart along the path.
@export var mine_count: int = 0
@export var mine_spacing: float = 30.0
## REPAIR: gate HP restored, and the fraction of max HP restored to units and the barricade.
@export var gate_heal: float = 0.0
@export var unit_heal: float = 0.0
@export_group("")


## True if a call needs a spot on the field (every kind but REPAIR).
func targeted() -> bool:
	return kind != Kind.REPAIR
