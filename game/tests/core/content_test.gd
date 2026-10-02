extends GdUnitTestSuite
## Integrity of the real content in res://data: references resolve, ids are unique, every
## modifier key exists, every piece of content is used, and the design rules hold
## (stronger shot = longer reload; plots off the enemy paths; crates breakable in time by
## tapping; the wall carries build spots). Map and wave rules run for every map in
## RunConfig.maps (each a level with its own paths and waves).

const CONFIG_PATH: String = "res://data/run_config.tres"
## Half the on-screen size of a plot; plots must keep this clear of enemy paths.
const PLOT_RADIUS: float = 22.0
## The tap rate a player is assumed to manage while also building (the bot's default).
const TAP_RATE: float = 3.0

## The whole content set (units, cards, meta, every map).
var base: RunConfig
## The config for the first map (unit-, card- and chart-level rules).
var cfg: RunConfig


func before() -> void:
	base = load(CONFIG_PATH)
	cfg = base.for_map(base.map)


## One run config per map.
func _configs() -> Array[RunConfig]:
	var out: Array[RunConfig] = []
	for m: MapDef in base.maps:
		out.append(base.for_map(m))
	return out


## Every enemy type in any map's waves, and every one in data/enemies/ (content not placed in
## a wave yet is still checked).
func _enemies() -> Array[EnemyDef]:
	var seen: Dictionary = {}
	var out: Array[EnemyDef] = []
	for c: RunConfig in _configs():
		for w: WaveDef in c.waves:
			for s: SpawnEntry in w.spawns:
				if not seen.has(s.enemy.id):
					seen[s.enemy.id] = true
					out.append(s.enemy)
	for file: String in ResourceLoader.list_directory("res://data/enemies"):
		if file.ends_with(".tres"):
			var e: EnemyDef = load("res://data/enemies/" + file)
			if not seen.has(e.id):
				seen[e.id] = true
				out.append(e)
	return out


func test_every_enemy_file_is_loaded_and_has_art() -> void:
	var ids: Array[StringName] = []
	for e: EnemyDef in _enemies():
		ids.append(e.id)
		assert_bool(ResourceLoader.exists("res://art/enemies/%s.svg" % e.id)) \
				.override_failure_message("%s has no art" % e.id).is_true()
	for id: StringName in [&"wasp", &"warden", &"burrower", &"bombardier"]:
		assert_bool(ids.has(id)).override_failure_message("%s missing" % id).is_true()


func test_each_stage2_enemy_carries_its_one_rule() -> void:
	var by_id: Dictionary = {}
	for e: EnemyDef in _enemies():
		by_id[e.id] = e
	assert_bool((by_id[&"wasp"] as EnemyDef).flying).is_true()
	var w: EnemyDef = by_id[&"warden"]
	assert_float(w.shield_radius * w.shield_amount * w.shield_regen).is_greater(0.0)
	var b: EnemyDef = by_id[&"burrower"]
	assert_float(b.burrow_every * b.burrow_length).is_greater(0.0)
	var bomb: EnemyDef = by_id[&"bombardier"]
	var best: float = 0.0
	for u: UnitDef in cfg.units:
		best = maxf(best, u.reach)
	assert_float(bomb.siege_range).is_between(100.0, 400.0)
	assert_float(best).override_failure_message("no unit can reach a Bombardier at its post") \
			.is_greater(bomb.siege_range * 0.5)


## Stage 3: every boss has phases listed from the highest threshold down, each of which does
## something; spawns are real, non-boss enemies; only a phase with spawns can guard.
func test_every_boss_is_well_formed() -> void:
	var bosses: Dictionary = {}
	for e: EnemyDef in _enemies():
		if not e.is_boss:
			assert_array(e.phases).override_failure_message("%s: phases but no boss" % e.id) \
					.is_empty()
			continue
		bosses[e.id] = e
		assert_array(e.phases).override_failure_message("%s has no phases" % e.id).is_not_empty()
		var last: float = INF
		for ph: BossPhase in e.phases:
			var tag: String = "%s @%.2f" % [e.id, ph.at_hp_fraction]
			assert_float(ph.at_hp_fraction).override_failure_message(tag).is_between(0.05, 1.0)
			assert_bool(ph.at_hp_fraction < last).override_failure_message(tag + ": order") \
					.is_true()
			last = ph.at_hp_fraction
			var spawns: bool = ph.spawn != null and ph.spawn_count > 0
			assert_bool(spawns or ph.armor_delta != 0.0 or ph.speed_mult != 1.0) \
					.override_failure_message(tag + ": does nothing").is_true()
			if spawns:
				assert_bool(ph.spawn.is_boss).override_failure_message(tag).is_false()
				assert_int(ph.spawn_count).override_failure_message(tag).is_less_equal(16)
			assert_bool(spawns or not (ph.guard or ph.keep_pace)) \
					.override_failure_message(tag + ": guards without spawns").is_true()
			assert_int(ph.callout.length()).override_failure_message(tag).is_less_equal(32)
	for id: StringName in [&"boss", &"broodmother", &"titan", &"overmind"]:
		assert_bool(bosses.has(id)).override_failure_message("%s missing" % id).is_true()
	# The user's call: the Queen breaks a base gate in two strikes, three with any upgrade.
	var queen: EnemyDef = bosses[&"boss"]
	assert_float(queen.wall_damage).is_equal(base.wall_hp / 2.0)


func test_every_map_loads_with_ten_waves() -> void:
	assert_int(base.maps.size()).is_greater_equal(2)
	assert_object(base.map).is_same(base.maps[0])
	for c: RunConfig in _configs():
		assert_int(c.waves.size()).override_failure_message("%s waves" % c.map.id).is_equal(10)
		assert_str(c.map.display_name).is_not_empty()


func test_every_wave_is_complete() -> void:
	for c: RunConfig in _configs():
		_check_waves_complete(c)


func _check_waves_complete(c: RunConfig) -> void:
	for i: int in c.waves.size():
		var w: WaveDef = c.waves[i]
		assert_object(w).override_failure_message("wave %d missing" % (i + 1)).is_not_null()
		assert_bool(w.spawns.is_empty()).override_failure_message("wave %d has no enemies" % (i + 1)).is_false()
		assert_bool(w.crates.is_empty()).override_failure_message("wave %d has no crates" % (i + 1)).is_false()
		for s: SpawnEntry in w.spawns:
			assert_object(s.enemy).is_not_null()
			assert_int(s.count).is_greater(0)
		for cs: CrateSpawn in w.crates:
			assert_object(cs.crate).is_not_null()


func test_boss_only_in_final_wave() -> void:
	for c: RunConfig in _configs():
		for i: int in c.waves.size():
			var has_boss: bool = false
			for s: SpawnEntry in c.waves[i].spawns:
				has_boss = has_boss or s.enemy.is_boss
			assert_bool(has_boss).override_failure_message("%s wave %d" % [c.map.id, i + 1]) \
					.is_equal(i == c.waves.size() - 1)


func test_every_modifier_key_exists() -> void:
	for c: CardDef in cfg.cards:
		assert_bool(RunModifiers.has_key(c.key)) \
				.override_failure_message("card %s: unknown key %s" % [c.id, c.key]).is_true()
	for k: SkillDef in cfg.skill_tree.skills:
		assert_bool(RunModifiers.has_key(k.key)) \
				.override_failure_message("skill %s: unknown key %s" % [k.id, k.key]).is_true()
		assert_float(k.value).override_failure_message("skill %s: no effect" % k.id) \
				.is_not_equal(0.0)


func test_the_skill_tree_is_well_formed() -> void:
	# Three branches (research §4.3), each tiers 1..6 with no gap or duplicate, costs rising
	# 1, 1, 2, 2, 3, 3 (36 stars for the whole tree, of 18 a player can earn: the tree is a
	# choice), and a title and description on every node. Tier 6 came with sectors 4-6 (E8).
	var tree: SkillTreeDef = cfg.skill_tree
	assert_int(tree.branch_titles.size()).is_equal(3)
	for b: int in tree.branch_titles.size():
		var nodes: Array[SkillDef] = tree.branch_skills(b)
		assert_int(nodes.size()).is_equal(6)
		for i: int in nodes.size():
			assert_int(nodes[i].tier).is_equal(i + 1)
			assert_int(nodes[i].cost).is_equal([1, 1, 2, 2, 3, 3][i])
			assert_str(nodes[i].title).is_not_empty()
			assert_str(nodes[i].description).is_not_empty()
	assert_int(tree.total_cost()).is_equal(36)
	assert_int(base.maps.size() * 3).is_equal(18)
	# The user's own nodes are in it.
	assert_str(String(tree.skill_by_id(&"last_stand").key)).is_equal("death_blast")
	assert_float(tree.skill_by_id(&"scavengers").value).is_equal_approx(0.1, 1e-6)


func test_counts() -> void:
	assert_int(cfg.units.size()).is_equal(6)
	assert_int(cfg.cards.size()).is_equal(12)
	assert_int(cfg.skill_tree.skills.size()).is_equal(18)
	assert_int(cfg.plot_count()).is_equal(11)
	assert_int(base.for_map(base.maps[1]).plot_count()).is_equal(15)
	assert_int(base.maps.size()).is_equal(6)


func test_ids_are_unique() -> void:
	for group: Array in [cfg.units, cfg.cards, cfg.skill_tree.skills, base.maps]:
		var seen: Dictionary = {}
		for item: Resource in group:
			var id: StringName = item.get("id")
			assert_bool(seen.has(id)).override_failure_message("duplicate id %s" % id).is_false()
			seen[id] = true


func test_all_enemies_crates_and_attacks_are_used() -> void:
	var crates: Dictionary = {}
	var in_waves: Dictionary = {}
	for w: WaveDef in _all_waves():
		for c: CrateSpawn in w.crates:
			crates[c.crate.id] = true
		for sp: SpawnEntry in w.spawns:
			in_waves[sp.enemy.id] = true
	# Every enemy is in some wave (sectors 4-6 bring the Stage 2 enemies and the bosses).
	assert_int(in_waves.size()).is_equal(15)
	assert_int(_enemies().size()).is_equal(15)
	assert_int(crates.size()).is_equal(3)
	var attacks: Dictionary = {}
	for u: UnitDef in cfg.units:
		attacks[u.attack] = true
		assert_int(u.max_level()).is_equal(3)
	assert_int(attacks.size()).is_equal(UnitDef.Attack.size())


func test_stronger_shots_reload_slower() -> void:
	var units: Array[UnitDef] = cfg.units.duplicate()
	units.sort_custom(func(a: UnitDef, b: UnitDef) -> bool: return a.damage < b.damage)
	for i: int in range(1, units.size()):
		assert_float(units[i].reload).override_failure_message(
				"%s hits harder than %s but reloads faster" % [units[i].id, units[i - 1].id]) \
				.is_greater_equal(units[i - 1].reload)


func test_unit_dps_stays_in_a_band() -> void:
	# A heavy unit buys splash, pierce or reach, not raw single-target DPS.
	var lo: float = INF
	var hi: float = 0.0
	for u: UnitDef in cfg.units:
		lo = minf(lo, u.dps_at(1))
		hi = maxf(hi, u.dps_at(1))
	assert_float(hi / lo).is_less_equal(3.0)


func test_plots_are_inside_the_field_and_off_enemy_paths() -> void:
	for c: RunConfig in _configs():
		var geos: Array[PathGeo] = _geos(c)
		for p: Vector2 in c.map.plots:
			assert_float(p.x).is_between(PLOT_RADIUS, c.playfield_width() - PLOT_RADIUS)
			if _on_wall(p):
				continue  # enemies stop at wall_y: nothing ever walks over a wall spot
			assert_float(p.y).is_between(PLOT_RADIUS, c.wall_y - PLOT_RADIUS)
			for e: EnemyDef in _enemies():
				for i: int in geos.size():
					var half: float = RunConfig.jitter_for(c.map.paths[i].spread, e.radius) + e.radius
					assert_float(geos[i].nearest(p).y).override_failure_message(
							"%s: plot %s overlaps %s on path %d" % [c.map.id, p, e.id, i]) \
							.is_greater_equal(half + PLOT_RADIUS)


func _geos(c: RunConfig) -> Array[PathGeo]:
	var out: Array[PathGeo] = []
	for path: PathDef in c.map.paths:
		out.append(PathGeo.new(path.points))
	return out


func _on_wall(p: Vector2) -> bool:
	return p.y > cfg.wall_y


func test_paths_run_down_from_a_portal_to_the_gate() -> void:
	for c: RunConfig in _configs():
		assert_bool(c.map.paths.is_empty()).is_false()
		var open_at_start: bool = false
		for i: int in c.map.paths.size():
			var pts: PackedVector2Array = c.map.paths[i].points
			var tag: String = "%s path %d" % [c.map.id, i]
			assert_int(pts.size()).override_failure_message(tag).is_greater_equal(2)
			for k: int in range(1, pts.size()):
				assert_float(pts[k].y).override_failure_message("%s turns back up" % tag) \
						.is_greater(pts[k - 1].y)
			assert_float(pts[pts.size() - 1].y).override_failure_message(tag).is_equal(c.wall_y)
			# The portal: at the top of the field or on a side edge; or a burrow breaking open
			# mid-field (Ashfall), only as a later breach and well up the field from the gate.
			var start: Vector2 = pts[0]
			var edge: bool = start.y <= 0.0 or start.x <= 0.0 or start.x >= c.playfield_width()
			var breach: bool = c.map.paths[i].opens_at_wave > 1 and start.y <= c.wall_y - 300.0
			assert_bool(edge or breach) \
					.override_failure_message("%s starts inside the field" % tag).is_true()
			assert_int(c.map.paths[i].opens_at_wave).is_between(1, c.waves.size())
			open_at_start = open_at_start or c.map.paths[i].opens_at_wave == 1
		assert_bool(open_at_start).is_true()


func test_waves_only_use_paths_open_by_then() -> void:
	for c: RunConfig in _configs():
		for i: int in c.waves.size():
			for s: SpawnEntry in c.waves[i].spawns:
				if s.path >= 0:
					assert_int(s.path).is_less(c.map.paths.size())
					assert_int(c.map.paths[s.path].opens_at_wave).override_failure_message(
							"%s wave %d uses path %d before it opens" % [c.map.id, i + 1, s.path]) \
							.is_less_equal(i + 1)
			for crate: CrateSpawn in c.waves[i].crates:
				if crate.path >= 0:
					assert_int(c.map.paths[crate.path].opens_at_wave).is_less_equal(i + 1)


func test_plot_unlocks_and_zones_are_sane() -> void:
	for c: RunConfig in _configs():
		assert_bool(c.map.plot_unlock_waves.is_empty() \
				or c.map.plot_unlock_waves.size() == c.map.plots.size()).is_true()
		for i: int in c.map.plots.size():
			assert_int(c.map.plot_unlock_wave(i)).is_between(1, c.waves.size())
		for z: ZoneDef in c.map.zones:
			assert_float(z.center.x).is_between(0.0, c.playfield_width())
			assert_float(z.center.y).is_between(0.0, c.wall_y)
			assert_float(z.value).is_greater(0.0)


func test_the_wall_carries_a_build_spot_at_every_path_end() -> void:
	# User, 2026-09-26: "the wall is also composed of fixed spots the player can place troops
	# or weapons on". Every path's end at the gate has one within reach of a short gun.
	for c: RunConfig in _configs():
		var spots: Array[Vector2] = []
		for p: Vector2 in c.map.plots:
			if _on_wall(p):
				spots.append(p)
				# On the drawn wall (its top edge is 16 above wall_y) and on screen.
				assert_float(p.y).is_between(c.wall_y, c.wall_y + 30.0)
		for path: PathDef in c.map.paths:
			var end: Vector2 = path.points[path.points.size() - 1]
			var near: float = INF
			for p: Vector2 in spots:
				near = minf(near, p.distance_to(end))
			assert_float(near).override_failure_message("%s: no wall spot near %s" % [c.map.id, end]) \
					.is_less(60.0)


func test_crates_are_breakable_in_time_by_tapping() -> void:
	var dps: float = TAP_RATE * cfg.tap_damage
	var shortest: float = INF
	for conf: RunConfig in _configs():
		for g: PathGeo in _geos(conf):
			shortest = minf(shortest, g.length)
	for w: WaveDef in _all_waves():
		for c: CrateSpawn in w.crates:
			var travel: float = shortest / c.crate.speed
			assert_float(c.crate.hp / dps).override_failure_message(
					"%s takes too long to break" % c.crate.id).is_less(travel * 0.5)


func _all_waves() -> Array[WaveDef]:
	var out: Array[WaveDef] = []
	for c: RunConfig in _configs():
		out.append_array(c.waves)
	return out


func test_every_crate_takes_more_than_one_tap() -> void:
	for w: WaveDef in _all_waves():
		for c: CrateSpawn in w.crates:
			assert_float(c.crate.hp).is_greater(cfg.tap_damage)


func test_every_enemy_strikes_the_gate_on_an_interval() -> void:
	for e: EnemyDef in _enemies():
		assert_float(e.attack_interval).is_greater(0.0)
		assert_float(e.wall_damage).is_greater(0.0)


func test_some_unit_outranges_every_spitter() -> void:
	# Counterplay: a spitter can always be killed from outside its spit range.
	var best: float = 0.0
	for u: UnitDef in cfg.units:
		best = maxf(best, u.reach)
	for e: EnemyDef in _enemies():
		if e.spit_interval > 0.0:
			assert_float(e.spit_range).override_failure_message(
					"%s outranges every unit" % e.id).is_less(best)
			assert_float(e.disable_duration).is_greater(0.0)
			assert_float(e.disable_duration).is_less(e.spit_interval * 2.0)


func test_spitters_are_introduced_before_they_mass() -> void:
	# Taught first: none in the first three waves, and at most two in their first wave.
	for c: RunConfig in _configs():
		var first: int = -1
		for i: int in c.waves.size():
			var n: int = 0
			for s: SpawnEntry in c.waves[i].spawns:
				if s.enemy.spit_interval > 0.0:
					n += s.count
			if n > 0 and first < 0:
				first = i
				assert_int(n).is_less_equal(2)
		assert_int(first).override_failure_message(c.map.id).is_greater_equal(3)


# --- the counter chart and coin sinks (docs/2026-09-26-counters-and-coin-sinks/) -----------

func test_every_enemy_has_one_weakness_not_also_resisted() -> void:
	for e: EnemyDef in _enemies():
		var bits: int = 0
		for t: int in UnitDef.DamageType.size():
			bits += 1 if e.weak_to & (1 << t) else 0
		assert_int(bits).override_failure_message("%s: %d weaknesses" % [e.id, bits]).is_equal(1)
		assert_int(e.weak_to & e.resists).is_equal(0)
		assert_str(e.description).is_not_empty()


func test_every_damage_type_is_some_enemys_answer_and_has_a_unit() -> void:
	for t: int in UnitDef.DamageType.size():
		var enemy_weak: bool = false
		for e: EnemyDef in _enemies():
			enemy_weak = enemy_weak or (e.weak_to & (1 << t)) != 0
		var unit: bool = false
		for u: UnitDef in cfg.units:
			unit = unit or u.damage_type == t
		assert_bool(enemy_weak and unit).override_failure_message(
				"%s has no enemy weak to it or no unit" % UnitDef.DAMAGE_TYPE_NAMES[t]).is_true()


func test_waves_get_more_threatening() -> void:
	for c: RunConfig in _configs():
		var prev: float = 0.0
		for i: int in c.waves.size():
			var t: float = WaveSchedule.threat(c.waves[i])
			assert_float(t).override_failure_message("%s wave %d threat %.0f <= %.0f" % [
					c.map.id, i + 1, t, prev]).is_greater(prev)
			prev = t


func test_every_sector_is_harder_than_the_one_before() -> void:
	# The campaign escalates (the skill tree grows between sectors): each sector's waves carry
	# more threat in all than the sector before it's, and so does its boss wave. Not wave by
	# wave: sectors 4-6 thin the familiar enemies early to make room for their new ones (E8
	# Stage 4), and threat within a sector already rises every wave (the test above).
	for k: int in range(1, base.maps.size()):
		var a: RunConfig = base.for_map(base.maps[k - 1])
		var b: RunConfig = base.for_map(base.maps[k])
		var ta: float = 0.0
		var tb: float = 0.0
		for i: int in a.waves.size():
			ta += WaveSchedule.threat(a.waves[i])
			tb += WaveSchedule.threat(b.waves[i])
		assert_float(tb).override_failure_message("%s is not harder than %s" % [b.map.id,
				a.map.id]).is_greater(ta)
		var last: int = a.waves.size() - 1
		assert_float(WaveSchedule.threat(b.waves[last])).override_failure_message(
				"%s's boss wave is not harder than %s's" % [b.map.id, a.map.id]) \
				.is_greater(WaveSchedule.threat(a.waves[last]))


func test_every_unit_offers_overcharge_and_its_own_trait() -> void:
	for u: UnitDef in cfg.units:
		assert_int(u.masteries.size()).is_equal(2)
		assert_str(String(u.masteries[0].id)).is_equal("overcharge")
		assert_float(u.masteries[0].damage_bonus).is_equal_approx(0.25, 0.0001)
		assert_str(String(u.masteries[1].id)).is_not_equal("overcharge")
		assert_int(u.mastery_cost).is_greater(0)


func test_barricade_slots_sit_on_paths_in_front_of_the_wall() -> void:
	assert_object(cfg.barricade).is_not_null()
	assert_int(cfg.barricade.costs.size()).is_equal(cfg.barricade.max_level())
	for c: RunConfig in _configs():
		assert_bool(c.map.barricade_slots.is_empty()).is_false()
		var geos: Array[PathGeo] = _geos(c)
		for p: Vector2 in c.map.barricade_slots:
			assert_float(p.y).is_between(c.wall_y - 150.0, c.wall_y - 40.0)
			var on_path: bool = false
			for g: PathGeo in geos:
				on_path = on_path or g.nearest(p).y <= CombatSim.BARRICADE_REACH
			assert_bool(on_path).override_failure_message("%s: slot %s blocks no path" % [
					c.map.id, p]).is_true()


# --- new enemies, destroyable units, elites (docs/2026-09-26-new-enemies-and-destroyable-units/)

func test_every_unit_can_be_destroyed_and_repaired() -> void:
	assert_float(cfg.unit_repair_cost_per_hp).is_greater(0.0)
	for u: UnitDef in cfg.units:
		assert_float(u.hp).override_failure_message("%s has no HP" % u.id).is_greater(0.0)


func test_new_enemy_types_arrive_in_small_numbers() -> void:
	# Every type after the first wave is introduced with at most two of it; the unit-hunter and
	# its kin not before wave 4.
	for c: RunConfig in _configs():
		var seen: Dictionary = {}
		for i: int in c.waves.size():
			var counts: Dictionary = WaveSchedule.enemy_counts(c.waves[i])
			for e: EnemyDef in counts:
				if seen.has(e.id):
					continue
				seen[e.id] = true
				if i > 0 and e.id != &"runner":
					assert_int(counts[e]).override_failure_message("%s wave %d: %d %s at once" % [
							c.map.id, i + 1, counts[e], e.id]).is_less_equal(2)
				if e.unit_reach > 0.0 or e.split_count > 0 or e.heal_radius > 0.0:
					assert_int(i).override_failure_message("%s: %s too early" % [c.map.id, e.id]) \
							.is_greater_equal(3)


func test_splitters_split_into_a_real_enemy_and_elites_come_late() -> void:
	for e: EnemyDef in _enemies():
		if e.split_count > 0:
			assert_object(e.split_into).is_not_null()
	for c: RunConfig in _configs():
		for i: int in c.waves.size():
			for s: SpawnEntry in c.waves[i].spawns:
				if s.elite != null:
					assert_int(i).override_failure_message("%s: elite in wave %d" % [c.map.id, i + 1]) \
							.is_greater_equal(4)
					assert_str(s.elite.title).is_not_empty()


func test_tips_are_short_and_well_formed() -> void:
	var ids: Dictionary = {}
	assert_bool(base.tips.is_empty()).is_false()
	for t: TipDef in base.tips:
		assert_bool(ids.has(t.id)).override_failure_message("duplicate tip %s" % t.id).is_false()
		ids[t.id] = true
		assert_bool(TipDirector.EVENTS.has(t.trigger)) \
				.override_failure_message("%s: unknown trigger %s" % [t.id, t.trigger]).is_true()
		assert_int(t.cards.size()).is_between(1, 3)
		for c: TipCard in t.cards:
			assert_int(c.title.length()).override_failure_message("%s: title too long" % t.id) \
					.is_less_equal(TipCard.TITLE_MAX)
			assert_int(c.body.length()).override_failure_message("%s: body too long" % t.id) \
					.is_less_equal(TipCard.BODY_MAX)
			assert_bool(TipDirector.FOCUSES.has(c.focus)) \
					.override_failure_message("%s: unknown focus %s" % [t.id, c.focus]).is_true()
			assert_bool(c.wait_for == &"" or TipDirector.WAIT_EVENTS.has(c.wait_for)).is_true()
			if c.wait_for != &"":
				assert_str(String(c.focus)).override_failure_message(
						"%s: a do card needs a spotlight" % t.id).is_not_empty()
			if c.icon != "":
				assert_bool(ResourceLoader.exists("res://art/%s.svg" % c.icon)) \
						.override_failure_message("%s: missing icon %s" % [t.id, c.icon]).is_true()


func test_no_description_is_a_wall_of_text() -> void:
	var texts: Array[Array] = []
	for e: EnemyDef in _enemies():
		texts.append([e.id, e.description])
	for u: UnitDef in base.units:
		texts.append([u.id, u.description])
		for m: MasteryDef in u.masteries:
			texts.append([m.id, m.description])
	for c: CardDef in base.cards:
		texts.append([c.id, c.description])
	for s: SkillDef in base.skill_tree.skills:
		texts.append([s.id, s.description])
	for pair: Array in texts:
		assert_int(String(pair[1]).length()) \
				.override_failure_message("%s: description over %d characters" % [pair[0],
				TipCard.BODY_MAX]).is_less_equal(TipCard.BODY_MAX)


func test_every_pair_of_units_has_exactly_one_synergy() -> void:
	var ids: Array[StringName] = []
	for u: UnitDef in base.units:
		ids.append(u.id)
	var n: int = ids.size()
	assert_int(base.synergies.size()).is_equal(n * (n + 1) / 2)
	for i: int in n:
		for j: int in range(i, n):
			var found: int = 0
			for s: SynergyDef in base.synergies:
				if s.involves(ids[i], ids[j]):
					found += 1
			assert_int(found).override_failure_message("%s+%s: %d synergies" % [ids[i], ids[j],
					found]).is_equal(1)
	var seen: Dictionary = {}
	for s: SynergyDef in base.synergies:
		assert_bool(seen.has(s.id)).is_false()
		seen[s.id] = true
		assert_bool(ids.has(s.unit_a) and ids.has(s.unit_b)).is_true()
		assert_bool(s.bonus_a.is_empty() and s.bonus_b.is_empty()) \
				.override_failure_message("%s does nothing" % s.id).is_false()
		assert_int(s.description.length()).is_less_equal(TipCard.BODY_MAX)
		assert_int(s.title.length()).is_less_equal(TipCard.TITLE_MAX)


func test_every_map_has_pads_close_enough_to_link() -> void:
	for c: RunConfig in _configs():
		var pairs: int = 0
		var pts: PackedVector2Array = c.map.plots
		for i: int in pts.size():
			for j: int in range(i + 1, pts.size()):
				if pts[i].distance_to(pts[j]) <= c.synergy_range:
					pairs += 1
		assert_int(pairs).override_failure_message("%s has no linkable pads" % c.map.id) \
				.is_greater(2)


func test_special_attacks_are_sane() -> void:
	assert_int(base.abilities.size()).is_greater_equal(2)
	var ids: Dictionary = {}
	var free: int = 0
	var map_ids: Array[StringName] = []
	for m: MapDef in base.maps:
		map_ids.append(m.id)
	for a: AbilityDef in base.abilities:
		assert_bool(ids.has(a.id)).override_failure_message("duplicate %s" % a.id).is_false()
		ids[a.id] = true
		assert_int(a.display_name.length()).is_between(1, TipCard.TITLE_MAX)
		assert_int(a.short_name.length()).override_failure_message(String(a.id)).is_between(1, 7)
		assert_int(a.description.length()).is_between(1, TipCard.BODY_MAX)
		assert_bool(ResourceLoader.exists("res://art/%s.svg" % a.icon)) \
				.override_failure_message("%s: missing icon %s" % [a.id, a.icon]).is_true()
		assert_bool(a.clip == "" or ResourceLoader.exists(a.clip)) \
				.override_failure_message("%s: missing clip %s" % [a.id, a.clip]).is_true()
		assert_float(a.delay).is_between(0.0, 2.0)
		assert_float(a.cooldown).override_failure_message(String(a.id)) \
				.is_greater(maxf(a.delay, a.duration) * 3.0)
		if a.unlocked_by == &"":
			free += 1
		else:
			assert_bool(map_ids.has(a.unlocked_by)) \
					.override_failure_message("%s: unlocked by unknown map" % a.id).is_true()
		match a.kind:
			AbilityDef.Kind.STRIKE:
				assert_float(a.damage).is_greater(0.0)
				assert_float(a.radius).is_between(30.0, 150.0)
			AbilityDef.Kind.FREEZE:
				assert_float(a.duration).is_greater(0.0)
				assert_float(a.slow).is_between(0.1, 1.0)
			AbilityDef.Kind.BURN:
				assert_float(a.damage * a.duration * a.length).is_greater(0.0)
			AbilityDef.Kind.MINES:
				assert_int(a.mine_count).is_greater(0)
				assert_float(a.damage).is_greater(0.0)
			AbilityDef.Kind.REPAIR:
				assert_float(a.gate_heal + a.unit_heal).is_greater(0.0)
	assert_int(free).override_failure_message("two attacks are free from the start").is_equal(2)
	assert_str(String(base.abilities[0].unlocked_by)).is_empty()
