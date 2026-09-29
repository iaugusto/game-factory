class_name Fixtures
extends RefCounted
## Small, explicit content for tests, so rules are tested against numbers written in the test
## rather than against res://data (which keeps being retuned). content_test.gd covers the
## real data separately.

## The fixture map: three straight paths down x = 90, 270, 450 (from y = 0 to the gate at 860,
## no spread). Its plots: rear pair near the wall, forward pair up the field, both between the
## paths; then a wall spot on the middle path (WALL_SPOT).
const PATH_X: Array[float] = [90.0, 270.0, 450.0]
const PLOTS: Array[Vector2] = [Vector2(180, 700), Vector2(360, 700), Vector2(180, 300),
		Vector2(360, 300), Vector2(270, 876)]
const WALL_SPOT: int = 4
## One barricade slot per path, in front of the wall.
const BARRICADE_SLOTS: Array[Vector2] = [Vector2(90, 770), Vector2(270, 770), Vector2(450, 770)]


static func enemy(hp: float = 3.0, speed: float = 100.0, wall_damage: float = 5.0,
		gold: int = 1, runner: bool = false, id: StringName = &"e") -> EnemyDef:
	var e := EnemyDef.new()
	e.id = id
	e.hp = hp
	e.speed = speed
	e.wall_damage = wall_damage
	e.gold = gold
	e.radius = 10.0
	e.is_runner = runner
	return e


static func crate(hp: float = 5.0, reward: int = 10, speed: float = 100.0,
		boost_mult: float = 1.0, boost_duration: float = 0.0) -> CrateDef:
	var c := CrateDef.new()
	c.id = &"crate"
	c.hp = hp
	c.reward = reward
	c.speed = speed
	c.radius = 15.0
	c.boost_rate_mult = boost_mult
	c.boost_duration = boost_duration
	return c


static func spawn(e: EnemyDef, count: int = 1, start: float = 0.0, interval: float = 1.0,
		path: int = 0) -> SpawnEntry:
	var s := SpawnEntry.new()
	s.enemy = e
	s.count = count
	s.start = start
	s.interval = interval
	s.path = path
	return s


static func crate_spawn(c: CrateDef, time: float = 0.0, path: int = 0) -> CrateSpawn:
	var s := CrateSpawn.new()
	s.crate = c
	s.time = time
	s.path = path
	return s


static func wave(spawns: Array[SpawnEntry] = [], crates: Array[CrateSpawn] = []) -> WaveDef:
	var w := WaveDef.new()
	w.spawns = spawns
	w.crates = crates
	return w


static func unit(id: StringName = &"gun", attack: UnitDef.Attack = UnitDef.Attack.HITSCAN,
		cost: int = 10, upgrades: PackedInt32Array = PackedInt32Array([20, 30]),
		dmg: float = 1.0, reload: float = 1.0, reach: float = 1000.0) -> UnitDef:
	var u := UnitDef.new()
	u.id = id
	u.attack = attack
	u.cost = cost
	u.upgrade_costs = upgrades
	u.damage = dmg
	u.reload = reload
	u.reach = reach
	return u


static func card(id: StringName, key: StringName, value: float, weight: float = 1.0,
		stacks: int = 1) -> CardDef:
	var c := CardDef.new()
	c.id = id
	c.key = key
	c.value = value
	c.weight = weight
	c.max_stacks = stacks
	return c


static func skill(id: StringName, branch: int, tier: int, cost: int = 1,
		key: StringName = &"gold_bonus", value: float = 0.1) -> SkillDef:
	var k := SkillDef.new()
	k.id = id
	k.branch = branch
	k.tier = tier
	k.cost = cost
	k.key = key
	k.value = value
	return k


## A special attack of `kind` with round numbers: radius 70, delay 0.5 s, cooldown 10 s, damage
## 30; tests set the kind's other fields.
static func ability(kind: AbilityDef.Kind = AbilityDef.Kind.STRIKE, id: StringName = &"ab") \
		-> AbilityDef:
	var a := AbilityDef.new()
	a.id = id
	a.short_name = "AB"
	a.kind = kind
	a.radius = 70.0
	a.delay = 0.5
	a.cooldown = 10.0
	a.damage = 30.0
	return a


## A config with the given waves and the fixture map. Enemies walk exactly on their path's
## centre line (no spread), no coins at the start, a tap deals 1 damage with no slop, so
## geometry and economy in tests are exact.
static func config(waves: Array[WaveDef], wall_hp: float = 100.0) -> RunConfig:
	var c := RunConfig.new()
	c.waves = waves
	c.tap_damage = 1.0
	c.tap_slop = 0.0
	c.wall_hp = wall_hp
	c.start_gold = 0
	var m := MapDef.new()
	for x: float in PATH_X:
		var path := PathDef.new()
		path.points = PackedVector2Array([Vector2(x, 0), Vector2(x, 860)])
		path.spread = 0.0
		m.paths.append(path)
	m.plots = PackedVector2Array(PLOTS)
	m.barricade_slots = PackedVector2Array(BARRICADE_SLOTS)
	c.map = m
	c.barricade = BarricadeDef.new()
	return c


## Put `def` on plot `index` at `level`, bypassing coins (rules tests about firing).
static func place(run: Run, index: int, def: UnitDef, level: int = 1) -> CombatSim.Plot:
	var plot: CombatSim.Plot = run.plots[index]
	plot.def = def
	plot.level = level
	plot.cooldown = 0.0
	plot.max_hp = def.hp_at(level)
	plot.hp = plot.max_hp
	return plot


## A long-reach gun on the wall spot that kills anything weak the moment it spawns: flow tests
## need waves to end, and an enemy at the gate never leaves on its own (it sieges).
static func sentinel(run: Run) -> CombatSim.Plot:
	return place(run, WALL_SPOT, unit(&"sentinel", UnitDef.Attack.HITSCAN, 10, [], 1000.0, 0.1,
			5000.0))


## A sentinel on plot `index` of any map (see `sentinel`).
static func sentinel_on(run: Run, index: int) -> CombatSim.Plot:
	return place(run, index, unit(&"sentinel", UnitDef.Attack.HITSCAN, 10, [], 1000.0, 0.05,
			5000.0))


## Start the wave if the run is in BUILD, then step until the phase changes away from WAVE
## or `max_ticks` pass.
static func run_wave(run: Run, max_ticks: int = 60 * 120) -> void:
	if run.phase == Run.Phase.BUILD:
		run.start_wave()
	var start: int = run.ticks
	while run.phase == Run.Phase.WAVE and run.ticks - start < max_ticks:
		run.step()
