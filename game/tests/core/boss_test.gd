extends GdUnitTestSuite
## Content expansion Stage 3 (docs/2026-09-27-content-expansion/): bosses as data. A BossPhase
## fires once, in order, as the boss's HP falls past its threshold; it may spawn a brood or an
## escort, change armour and speed, stop the boss, and guard it. Fixture map: straight paths down
## x = 90, 270, 450 to the gate at y = 860; plots 0 = (180, 700), 1 = (360, 700).


func _phase(at: float, spawn: EnemyDef = null, count: int = 0) -> BossPhase:
	var ph := BossPhase.new()
	ph.at_hp_fraction = at
	ph.spawn = spawn
	ph.spawn_count = count
	return ph


func _boss(phases: Array[BossPhase], hp: float = 100.0, speed: float = 20.0) -> EnemyDef:
	var e := Fixtures.enemy(hp, speed, 50, 40, false, &"bossy")
	e.radius = 36.0
	e.is_boss = true
	e.phases = phases
	return e


func _run(spawns: Array[SpawnEntry]) -> Run:
	var run := Run.new(Fixtures.config([Fixtures.wave(spawns)]), 1)
	run.gold = 1000
	return run


func _steps(run: Run, n: int) -> void:
	for i: int in n:
		run.step()


func _find(run: Run, id: StringName) -> Array[CombatSim.Enemy]:
	var out: Array[CombatSim.Enemy] = []
	for group: Array in run.combat.path_enemies:
		for e: CombatSim.Enemy in group:
			if e.def.id == id:
				out.append(e)
	return out


## A run with `def` on the field (path 1), stepped until it has walked a bit.
func _with_boss(def: EnemyDef) -> Run:
	var run := _run([Fixtures.spawn(def, 1, 0, 1, 1)])
	run.start_wave()
	_steps(run, 60)
	return run


func test_phases_fire_once_each_in_order_at_their_thresholds() -> void:
	var fired: Array[int] = []
	var brood := Fixtures.enemy(5, 10, 1, 1, false, &"brood")
	var run := _with_boss(_boss([_phase(0.66, brood, 2), _phase(0.33, brood, 3)]))
	run.combat.boss_phase.connect(func(_b: CombatSim.Enemy, i: int) -> void: fired.append(i))
	var boss: CombatSim.Enemy = run.combat.bosses[0]
	run.combat._apply_damage(boss, 30.0)  # 70%: nothing yet
	assert_array(fired).is_empty()
	run.combat._apply_damage(boss, 5.0)  # 65%: the first
	assert_array(fired).contains_exactly([0])
	assert_int(_find(run, &"brood").size()).is_equal(2)
	run.combat._apply_damage(boss, 10.0)  # 55%: still one
	assert_array(fired).contains_exactly([0])
	run.combat._apply_damage(boss, 30.0)  # 25%: the second
	assert_array(fired).contains_exactly([0, 1])
	assert_int(_find(run, &"brood").size()).is_equal(5)
	run.combat._apply_damage(boss, 5.0)
	assert_array(fired).contains_exactly([0, 1])


func test_one_big_hit_fires_every_phase_it_crosses_in_order() -> void:
	var fired: Array[int] = []
	var run := _with_boss(_boss([_phase(0.66), _phase(0.33)]))
	run.combat.boss_phase.connect(func(_b: CombatSim.Enemy, i: int) -> void: fired.append(i))
	run.combat._apply_damage(run.combat.bosses[0], 80.0)
	assert_array(fired).contains_exactly([0, 1])


func test_a_killing_blow_fires_no_phase() -> void:
	var fired: Array[int] = []
	var brood := Fixtures.enemy(5, 10, 1, 1, false, &"brood")
	var run := _with_boss(_boss([_phase(0.5, brood, 4)]))
	run.combat.boss_phase.connect(func(_b: CombatSim.Enemy, i: int) -> void: fired.append(i))
	run.combat._apply_damage(run.combat.bosses[0], 500.0)
	assert_array(fired).is_empty()
	assert_array(_find(run, &"brood")).is_empty()
	assert_array(run.combat.bosses).is_empty()


func test_healing_back_above_a_threshold_never_refires_it() -> void:
	var fired: Array[int] = []
	var run := _with_boss(_boss([_phase(0.5)]))
	run.combat.boss_phase.connect(func(_b: CombatSim.Enemy, i: int) -> void: fired.append(i))
	var boss: CombatSim.Enemy = run.combat.bosses[0]
	run.combat._apply_damage(boss, 60.0)
	boss.hp = boss.max_hp
	run.combat._apply_damage(boss, 60.0)
	assert_array(fired).contains_exactly([0])


func test_the_brood_appears_just_ahead_of_the_boss_on_its_path_and_the_path_stays_sorted() -> void:
	var brood := Fixtures.enemy(5, 10, 1, 1, false, &"brood")
	var run := _with_boss(_boss([_phase(0.5, brood, 6)]))
	var boss: CombatSim.Enemy = run.combat.bosses[0]
	run.combat._apply_damage(boss, 60.0)
	for b: CombatSim.Enemy in _find(run, &"brood"):
		assert_int(b.path).is_equal(boss.path)
		assert_float(b.d).is_greater(boss.d)
		assert_float(b.d - boss.d).is_less(boss.def.radius * 2.0 + 30.0)
	var list: Array = run.combat.path_enemies[boss.path]
	for i: int in range(1, list.size()):
		assert_bool((list[i - 1] as CombatSim.Enemy).d >= (list[i] as CombatSim.Enemy).d).is_true()


func test_a_phase_at_full_hp_fires_as_the_boss_arrives() -> void:
	var escort := Fixtures.enemy(5, 60, 1, 1, false, &"escort")
	var run := _run([Fixtures.spawn(_boss([_phase(1.0, escort, 3)]), 1, 0, 1, 1)])
	run.start_wave()
	_steps(run, 2)
	assert_int(_find(run, &"escort").size()).is_equal(3)
	assert_int(run.combat.bosses[0].next_phase).is_equal(1)


func test_a_phase_sheds_armour_and_speeds_the_boss_up() -> void:
	var ph := _phase(0.5)
	ph.armor_delta = -4.0
	ph.speed_mult = 2.0
	var def := _boss([ph])
	def.armor = 5.0
	var run := _with_boss(def)
	var boss: CombatSim.Enemy = run.combat.bosses[0]
	var speed: float = boss.speed
	assert_float(CombatSim.effective_damage(run.config, def, 10.0, UnitDef.DamageType.KINETIC,
			0.0, boss.extra_armor())).is_equal_approx(5.0, 1e-4)
	run.combat._apply_damage(boss, 60.0)
	assert_float(boss.speed).is_equal_approx(speed * 2.0, 1e-4)
	assert_float(CombatSim.effective_damage(run.config, def, 10.0, UnitDef.DamageType.KINETIC,
			0.0, boss.extra_armor())).is_equal_approx(9.0, 1e-4)


func test_a_pause_stops_the_boss_then_it_walks_on() -> void:
	var ph := _phase(0.5)
	ph.pause_seconds = 1.0
	var run := _with_boss(_boss([ph]))
	var boss: CombatSim.Enemy = run.combat.bosses[0]
	run.combat._apply_damage(boss, 60.0)
	var d: float = boss.d
	_steps(run, 50)
	assert_float(boss.d).is_equal(d)
	_steps(run, 30)
	assert_float(boss.d).is_greater(d)


func test_guards_void_every_hit_until_the_last_one_dies() -> void:
	var warden := Fixtures.enemy(10, 60, 1, 1, false, &"guard")
	var ph := _phase(1.0, warden, 2)
	ph.guard = true
	var run := _run([Fixtures.spawn(_boss([ph], 100.0), 1, 0, 1, 1)])
	run.start_wave()
	_steps(run, 2)
	var boss: CombatSim.Enemy = run.combat.bosses[0]
	var guards: Array[CombatSim.Enemy] = _find(run, &"guard")
	assert_bool(boss.guarded()).is_true()
	run.combat._damage_enemy(boss, 50.0, UnitDef.DamageType.KINETIC)
	assert_float(boss.hp).is_equal(100.0)
	run.combat._apply_damage(guards[0], 100.0)
	run.combat._apply_damage(boss, 50.0)
	assert_float(boss.hp).is_equal(100.0)  # one guard still stands
	run.combat._apply_damage(guards[1], 100.0)
	assert_bool(boss.guarded()).is_false()
	run.combat._apply_damage(boss, 50.0)
	assert_float(boss.hp).is_equal(50.0)


func test_units_cannot_hurt_a_guarded_boss_but_kill_its_guards_first() -> void:
	var escort := Fixtures.enemy(3, 20, 1, 1, false, &"guard")
	var ph := _phase(1.0, escort, 2)
	ph.guard = true
	ph.keep_pace = true
	var run := _run([Fixtures.spawn(_boss([ph], 50.0, 20.0), 1, 0, 1, 1)])
	Fixtures.place(run, 1, Fixtures.unit(&"gun", UnitDef.Attack.HITSCAN, 10, [], 1.0, 0.25,
			2000.0))
	run.start_wave()
	_steps(run, 60 * 3)
	var boss: CombatSim.Enemy = run.combat.bosses[0]
	assert_array(_find(run, &"guard")).is_empty()
	assert_float(boss.hp).is_less(50.0)


func test_escorts_that_keep_pace_walk_at_the_boss_speed() -> void:
	var escort := Fixtures.enemy(5, 60, 1, 1, false, &"escort")
	var ph := _phase(1.0, escort, 2)
	ph.keep_pace = true
	var run := _run([Fixtures.spawn(_boss([ph], 100.0, 20.0), 1, 0, 1, 1)])
	run.start_wave()
	_steps(run, 2)
	for e: CombatSim.Enemy in _find(run, &"escort"):
		assert_float(e.speed).is_equal_approx(20.0, 1e-4)


func test_bosses_list_tracks_the_boss_on_the_field() -> void:
	var run := _with_boss(_boss([]))
	assert_int(run.combat.bosses.size()).is_equal(1)
	run.combat._apply_damage(run.combat.bosses[0], 1000.0)
	assert_array(run.combat.bosses).is_empty()
