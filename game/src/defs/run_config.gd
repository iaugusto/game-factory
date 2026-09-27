class_name RunConfig
extends Resource
## Everything a run is made of: base numbers plus the content sets. One instance lives in
## res://data/run_config.tres; tests may build smaller ones in code.

@export_group("Playfield")
## The field is this wide (portrait); maps lay their paths out inside it.
@export var field_width: float = 540.0
@export var wall_y: float = 860.0
@export var tick_rate: int = 60

@export_group("Units")
@export var crit_multiplier: float = 2.0
## The counter chart: a weak hit deals ×weak, a resisted one ×resist; armour never takes a hit
## below armor_floor of its damage.
@export var weak_multiplier: float = 2.0
@export var resist_multiplier: float = 0.5
@export var armor_floor: float = 0.15
## Selling refunds this fraction of everything spent on the plot (a costly decision).
@export var sell_refund: float = 0.5
## A unit built mid-wave waits this long before its first shot (swaps are never instant).
@export var build_setup_time: float = 1.0
## Coins per HP to repair a damaged unit (rounded up).
@export var unit_repair_cost_per_hp: float = 0.3

@export_group("Crates")
## Damage one tap deals to a crate (crate HP is effectively "taps to break").
@export var tap_damage: float = 1.0
## A tap this far outside a crate's radius still counts (fat fingers).
@export var tap_slop: float = 16.0

@export_group("Base")
@export var wall_hp: float = 100.0
## Between waves the gate can be patched: this much HP for this many coins, per purchase.
@export var gate_repair_hp: float = 25.0
@export var gate_repair_cost: int = 20
@export var barricade: BarricadeDef
@export var start_gold: int = 45
@export var win_brick_bonus: int = 10
@export var cards_per_offer: int = 3

@export_group("Presentation")
## Game speed while the build menu is open mid-wave: slowed, not paused, so the pressure stays.
@export var build_menu_time_scale: float = 0.35

@export_group("Content")
## The map a run is on, and its waves (for_map sets both from a MapDef).
@export var map: MapDef
@export var waves: Array[WaveDef] = []
## Every map, in campaign order.
@export var maps: Array[MapDef] = []
@export var units: Array[UnitDef] = []
@export var cards: Array[CardDef] = []
@export var meta_upgrades: Array[MetaUpgradeDef] = []


func unit_by_id(unit_id: StringName) -> UnitDef:
	for u: UnitDef in units:
		if u.id == unit_id:
			return u
	return null


func plot_count() -> int:
	return map.plots.size() if map != null else 0


func playfield_width() -> float:
	return field_width


## How far an enemy of `radius` may stray from its path's centre line (a path's `spread`):
## big ones stay centred, so they never overlap the build plots beside the path.
static func jitter_for(spread: float, radius: float) -> float:
	return clampf(spread + 12.0 - radius, 0.0, spread)


## The config for a run on `m`: a shallow copy with the map and its waves (the map's own
## waves if it has any).
func for_map(m: MapDef) -> RunConfig:
	var c: RunConfig = duplicate(false)
	c.map = m
	if not m.waves.is_empty():
		c.waves = m.waves.duplicate()
	return c


func map_by_id(map_id: StringName) -> MapDef:
	for m: MapDef in maps:
		if m.id == map_id:
			return m
	return null
