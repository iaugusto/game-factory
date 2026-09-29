extends SceneTree
## Balance runs for `uv run balance` (tools/src/gf_tools/balance/): one process per sector ×
## profile × strategy cell, headless. Writes one JSON line per seed (BalanceRun.play).
##
##   godot --headless --path game --script res://tools/balance_sim.gd -- \
##       map=outpost profile=T0 strategy=smart seeds=1-50 out=/tmp/x.jsonl
##
## Optional: hp=MULT scales every wave's hp_scale (for tuning sweeps without editing data);
## ability=ID is the special attack the bot takes (default: the config's first, the strike).


func _init() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var base: RunConfig = load("res://data/run_config.tres")
	var m: MapDef = base.map_by_id(StringName(args.get("map", "outpost")))
	if m == null:
		push_error("balance_sim: unknown map %s" % args.get("map"))
		quit(2)
		return
	var cfg: RunConfig = base.for_map(m)
	if args.has("hp"):
		var waves: Array[WaveDef] = []
		for w: WaveDef in cfg.waves:
			var w2: WaveDef = w.duplicate()
			w2.hp_scale = w.hp_scale * float(args["hp"])
			waves.append(w2)
		cfg.waves = waves
	var strategy: String = args.get("strategy", "smart")
	if Autoplay.preset(strategy) == null:
		push_error("balance_sim: unknown strategy %s" % strategy)
		quit(2)
		return
	var ability: AbilityDef = null
	if args.has("ability"):
		ability = base.ability_by_id(StringName(args["ability"]))
		if ability == null:
			push_error("balance_sim: unknown ability %s" % args["ability"])
			quit(2)
			return
	var mods: RunModifiers = BalanceRun.profile_mods(base, args.get("profile", "T0"))
	var span: PackedStringArray = String(args.get("seeds", "1-8")).split("-")
	var out := FileAccess.open(args.get("out", "user://balance.jsonl"), FileAccess.WRITE)
	for s: int in range(int(span[0]), int(span[1]) + 1):
		var rec: Dictionary = BalanceRun.play(cfg, mods, s, strategy, 60 * 60 * 30, ability)
		rec["profile"] = args.get("profile", "T0")
		out.store_line(JSON.stringify(rec))
	out.close()
	quit(0)
