class_name BalanceRun
extends RefCounted
## One headless bot run for the balance report (docs/2026-09-27-b4-balance-and-juice/): plays
## `cfg` with tree `mods` and seed `run_seed` as Autoplay strategy `strategy`, and returns a
## flat record of the outcome. Pure core, so the record shape is unit tested; the tool script
## (tools/balance_sim.gd) only loops over seeds and writes the records as JSON lines.

## The bot's skill-tree profiles: the stars a player brings to sector 1 (none), 2 (≈3), 3 (≈6).
const PROFILES: Dictionary = {
	"T0": [],
	"T3": [&"drill", &"thick_walls", &"war_chest"],
	"T6": [&"drill", &"thick_walls", &"war_chest", &"sharpshooters", &"reinforced_pads",
			&"scavengers"],
}


## The run modifiers of tree profile `profile` (PROFILES) on `base`'s skill tree.
static func profile_mods(base: RunConfig, profile: String) -> RunModifiers:
	var tree := SkillTree.new()
	for id: StringName in PROFILES.get(profile, []):
		tree.owned[id] = true
	return tree.to_modifiers(base.skill_tree)


## Play one run to the end and describe it: won, waves, gate, ticks, the ability and how often it
## was called ("casts"), links at the end,
## unspent coins, crates broken, kills, gate damage per enemy type ("leaks"), and the units
## standing at the end by type.
## `ability`: the special attack the bot takes (null: the config's default, the first).
static func play(cfg: RunConfig, mods: RunModifiers, run_seed: int, strategy: String,
		max_ticks: int = 60 * 60 * 30, ability: AbilityDef = null) -> Dictionary:
	var run := Run.new(cfg, run_seed, mods)
	if ability != null:
		run.choose_ability(ability)
	var bot: Autoplay = Autoplay.preset(strategy)
	var tally: Dictionary = {"casts": 0, "leaks": {}}
	run.combat.ability_called.connect(func(_c: CombatSim.Cast) -> void:
		tally["casts"] += 1)
	run.combat.enemy_struck.connect(func(e: CombatSim.Enemy, dmg: float) -> void:
		var leaks: Dictionary = tally["leaks"]
		leaks[String(e.def.id)] = float(leaks.get(String(e.def.id), 0.0)) + dmg)
	bot.play(run, max_ticks)
	var links: int = 0
	var units: Dictionary = {}
	for p: CombatSim.Plot in run.plots:
		links += p.links.size()
		if not p.is_empty():
			units[String(p.def.id)] = int(units.get(String(p.def.id), 0)) + 1
	return {
		"map": String(cfg.map.id),
		"strategy": strategy,
		"seed": run_seed,
		"won": run.phase == Run.Phase.WON,
		"waves": run.waves_cleared,
		"gate": snappedf(run.gate_fraction(), 0.001),
		"ticks": run.ticks,
		"ability": String(run.ability.id) if run.ability != null else "",
		"casts": int(tally["casts"]),
		"links": links / 2,
		"unspent": run.gold,
		"crates": run.combat.crates_broken,
		"kills": run.combat.kills,
		"leaks": tally["leaks"],
		"units": units,
	}
