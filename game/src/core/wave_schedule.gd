class_name WaveSchedule
extends RefCounted
## Turns a WaveDef into a time-ordered list of spawn events. Random paths (among the open ones)
## are resolved here, from the "spawn" stream, so the whole wave is fixed the moment it starts.

enum EventType { ENEMY, CRATE }


class Event:
	var time: float
	var type: EventType
	var enemy: EnemyDef
	var crate: CrateDef
	var path: int
	var elite: EliteDef
	## Tie-break so events at the same time keep their authored order.
	var order: int


static func build(wave: WaveDef, open_paths: PackedInt32Array,
		rng: RandomNumberGenerator) -> Array[Event]:
	var events: Array[Event] = []
	var order: int = 0
	for entry: SpawnEntry in wave.spawns:
		for i: int in entry.count:
			var e := Event.new()
			e.time = entry.start + i * entry.interval
			e.type = EventType.ENEMY
			e.enemy = entry.enemy
			e.path = _resolve_path(entry.path, open_paths, rng)
			e.elite = entry.elite
			e.order = order
			order += 1
			events.append(e)
	for spawn: CrateSpawn in wave.crates:
		var c := Event.new()
		c.time = spawn.time
		c.type = EventType.CRATE
		c.crate = spawn.crate
		c.path = _resolve_path(spawn.path, open_paths, rng)
		c.order = order
		order += 1
		events.append(c)
	events.sort_custom(func(a: Event, b: Event) -> bool:
		return a.time < b.time or (a.time == b.time and a.order < b.order))
	return events


## Enemies per type in `wave`, in first-appearance order: EnemyDef -> count.
static func enemy_counts(wave: WaveDef) -> Dictionary:
	var out: Dictionary = {}
	for entry: SpawnEntry in wave.spawns:
		out[entry.enemy] = int(out.get(entry.enemy, 0)) + entry.count
	return out


## Enemy types that appear in `waves[index]` for the first time in the run (for intel cards).
static func new_enemies(waves: Array[WaveDef], index: int) -> Array[EnemyDef]:
	var seen: Dictionary = {}
	for i: int in mini(index, waves.size()):
		for entry: SpawnEntry in waves[i].spawns:
			seen[entry.enemy.id] = true
	var out: Array[EnemyDef] = []
	if index < 0 or index >= waves.size():
		return out
	for entry: SpawnEntry in waves[index].spawns:
		if not seen.has(entry.enemy.id):
			seen[entry.enemy.id] = true
			out.append(entry.enemy)
	return out


## The wave's total threat: count × EnemyDef.threat × its hp_scale (content tests check it
## rises through the run).
static func threat(wave: WaveDef) -> float:
	var total: float = 0.0
	for entry: SpawnEntry in wave.spawns:
		total += entry.count * entry.enemy.threat
	return total * wave.hp_scale


static func enemy_count(wave: WaveDef) -> int:
	var total: int = 0
	for entry: SpawnEntry in wave.spawns:
		total += entry.count
	return total


## A fixed path as authored (content tests check it is open by then), or a random open one.
static func _resolve_path(path: int, open_paths: PackedInt32Array,
		rng: RandomNumberGenerator) -> int:
	if path >= 0:
		return path
	return open_paths[rng.randi_range(0, open_paths.size() - 1)]
