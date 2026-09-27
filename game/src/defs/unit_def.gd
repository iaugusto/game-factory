class_name UnitDef
extends Resource
## A troop or weapon the player places on a build plot (MapDef). Placed any time, mid-wave
## included, for coins.
##
## The design rule is "the stronger the shot, the longer the reload": content_test.gd checks
## that reload never decreases as damage per shot rises, and that single-target damage per
## second stays within a band, so a heavy unit buys splash, pierce or reach, not raw DPS.

## How a shot reaches its target (rules in CombatSim._fire_plot).
enum Attack {
	## A homing projectile; fizzles if its target dies first.
	BULLET,
	## A ground-targeted arc to where the target was when fired; splash on landing. Fast
	## enemies can walk out of it.
	SHELL,
	## Instant damage to the target.
	HITSCAN,
	## Instant damage to every enemy on the target's path within reach.
	BEAM,
}
## Cosmetic and flavour only (how it's drawn); the rules don't read it.
enum Role { TROOP, EMPLACEMENT }
## What kind of damage it deals: enemies are weak to one type and may resist another
## (EnemyDef.weak_to / resists), the "right weapon for each enemy" chart.
enum DamageType { KINETIC, EXPLOSIVE, PIERCING, CRYO }

const DAMAGE_TYPE_NAMES: PackedStringArray = ["Kinetic", "Explosive", "Piercing", "Cryo"]

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
@export var role: Role = Role.EMPLACEMENT
@export var attack: Attack = Attack.BULLET
@export var damage_type: DamageType = DamageType.KINETIC
@export var cost: int = 20
## Hit points at level 1 (+30% per level): the few enemies that attack units (Ravagers) can
## destroy it.
@export var hp: float = 50.0
## Price of level 2, level 3, ... Its size is the number of upgrades available.
@export var upgrade_costs: PackedInt32Array = PackedInt32Array()
## Damage per shot at level 1.
@export var damage: float = 1.0
## Seconds between shots at level 1.
@export var reload: float = 1.0
## Targeting radius around the plot, in field units.
@export var reach: float = 180.0
## BULLET and SHELL: field units per second.
@export var projectile_speed: float = 900.0
## SHELL: radius damaged on landing.
@export var splash_radius: float = 0.0
## BEAM: at most this many enemies on the path are hit, furthest along first (0 = all).
@export var beam_max_targets: int = 0
## Speed multiplier applied to a hit enemy (0.5 = half speed), and for how long.
@export var slow_factor: float = 1.0
@export var slow_duration: float = 0.0
## Per level above 1: damage grows by this fraction; reload shrinks by this fraction.
@export var level_damage_bonus: float = 0.5
@export var level_reload_bonus: float = 0.15
@export var color: Color = Color.WHITE
## Bought once at max level: pick one (Overcharge, or this unit's trait).
@export var masteries: Array[MasteryDef] = []
@export var mastery_cost: int = 90


func hp_at(level: int) -> float:
	return hp * (1.0 + (level - 1) * 0.3)


func max_level() -> int:
	return 1 + upgrade_costs.size()


func damage_at(level: int) -> float:
	return damage * (1.0 + (level - 1) * level_damage_bonus)


func reload_at(level: int) -> float:
	return reload * pow(1.0 - level_reload_bonus, level - 1)


## Single-target damage per second at `level` (no splash, no pierce).
func dps_at(level: int = 1) -> float:
	return damage_at(level) / reload_at(level)
