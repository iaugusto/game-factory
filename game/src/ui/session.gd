extends Node
## Autoload "Session": the glue between the campaign screen and the run scene. Holds the
## player's SaveData (loaded on first use), which sector a campaign run is on, and saves after
## each recorded result. Holds no rules: stars, unlocks and the tree live in core (Campaign,
## SkillTree, SaveData).
##
## A run is "active" (recorded) only when the campaign screen launched it. Runs started
## directly (a dev launch with run arguments, tests, captures, the bot) never touch the save.
##
## Launch arguments (after `--`):
##   --save=PATH   use this save file instead of user://save.json

const CAMPAIGN_SCENE: String = "res://scenes/campaign.tscn"
const RUN_SCENE: String = "res://scenes/run.tscn"
## Arguments that mean "play a run now", skipping the campaign screen (dev, captures, perf).
const RUN_ARGS: PackedStringArray = ["map", "seed", "autoplay", "stress", "skip", "skip-to-wave",
		"open-plot", "tree", "perf", "quit-on-end", "ability", "demo", "pick"]

var save_path: String = SaveData.DEFAULT_PATH
## The sector the active run is on.
var map_id: StringName = &""
## True while a run launched from the campaign is being played.
var active: bool = false
var _save: SaveData = null


func _ready() -> void:
	DesktopWindow.fit(get_window())
	var args: Dictionary = RunController.parse_args(LaunchArgs.get_args())
	if args.has("save"):
		save_path = String(args["save"])


## The player's save, loaded on first use.
func profile() -> SaveData:
	if _save == null:
		_save = SaveData.load_from(save_path)
	return _save


## Use `save` (and write it to `path`) from now on: tests point this at a temporary file.
func use_save(save: SaveData, path: String) -> void:
	_save = save
	save_path = path


func persist() -> void:
	var err: Error = profile().save_to(save_path)
	if err != OK:
		push_warning("Session: could not write the save to %s (error %d)" % [save_path, err])


## The starting modifiers the skill tree gives a run.
func run_mods(cfg: RunConfig) -> RunModifiers:
	return profile().tree.to_modifiers(cfg.skill_tree)


## Record the finished `run` on the active sector and save. Returns Campaign.record's result.
func record(cfg: RunConfig, run: Run) -> Dictionary:
	var result: Dictionary = profile().record_result(map_id, run.phase == Run.Phase.WON,
			run.waves_cleared, run.gate_fraction(), cfg)
	persist()
	return result


## True if the command line asks for a run straight away.
static func wants_direct_run(args: Dictionary) -> bool:
	for key: String in RUN_ARGS:
		if args.has(key):
			return true
	return false


func goto_run(sector: StringName) -> void:
	map_id = sector
	active = true
	get_tree().change_scene_to_file(RUN_SCENE)


func goto_campaign() -> void:
	active = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(CAMPAIGN_SCENE)
