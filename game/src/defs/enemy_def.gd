class_name EnemyDef
extends Resource
## One enemy type. Enemies walk along their path toward the gate; one that reaches it
## stops and strikes it every `attack_interval` until killed (the gate siege). Spitters
## (spit_interval > 0) also disable units from range.


@export var id: StringName
@export var display_name: String = ""
## One line for the intel card shown the first time it appears.
@export var description: String = ""
@export var hp: float = 1.0
## Units per second along its path (the gate sits at RunConfig.wall_y).
@export var speed: float = 40.0
## Gate HP removed per strike while at the gate (the first strike lands on arrival).
@export var wall_damage: float = 1.0
## Seconds between strikes at the gate.
@export var attack_interval: float = 1.0
## Coins for the kill: a small trickle; crates are the main income.
@export var gold: int = 1
## Body radius: bullets connect at its edge; escorts and the barricade use it.
@export var radius: float = 12.0
## Enemies that count as runners for the "runner bounty" modifier.
@export var is_runner: bool = false

@export_group("Counters")
## Damage types (UnitDef.DamageType, as bit flags) that hit it for RunConfig.weak_multiplier
## and that it shrugs off (RunConfig.resist_multiplier).
@export_flags("Kinetic", "Explosive", "Piercing", "Cryo") var weak_to: int = 0
@export_flags("Kinetic", "Explosive", "Piercing", "Cryo") var resists: int = 0
## Flat damage removed from every hit (never below RunConfig.armor_floor of the hit): punishes
## many light hits, rewards heavy ones.
@export var armor: float = 0.0
## How much pressure one of these puts on a wave (content tests check waves' threat grows).
@export var threat: float = 1.0
@export_group("")

@export_group("Unit attack")
## While walking, it stops at the nearest built plot within `unit_reach` and strikes it for
## `unit_damage` every attack_interval until the unit is destroyed (0 = never attacks units).
@export var unit_reach: float = 0.0
@export var unit_damage: float = 0.0

@export_group("Split")
## On death it bursts into `split_count` of `split_into`, where it fell.
@export var split_into: EnemyDef
@export var split_count: int = 0

@export_group("Heal")
## Heals other enemies within `heal_radius` by `heal_per_second` of their max HP per second.
@export var heal_radius: float = 0.0
@export var heal_per_second: float = 0.0

@export_group("Spit")
## Every `spit_interval` seconds, spit at the nearest working unit within `spit_range`; the
## glob flies at `spit_speed` and disables the unit for `disable_duration` seconds.
## spit_interval 0 = never spits.
@export var spit_interval: float = 0.0
@export var spit_range: float = 0.0
@export var spit_speed: float = 260.0
@export var disable_duration: float = 0.0
@export_group("")
@export var color: Color = Color.WHITE
