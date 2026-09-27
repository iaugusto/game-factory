class_name RngStreams
extends RefCounted
## Named, independently seeded random streams for one run.
##
## Every source of gameplay randomness draws from its own stream ("spawn", "cards",
## "combat"), each seeded from "<seed>:<name>". Adding a new stream, or drawing more from one,
## never shifts the others — so a balance change to cards cannot reshuffle enemy paths.

var seed_value: int
var _streams: Dictionary[StringName, RandomNumberGenerator] = {}


func _init(run_seed: int) -> void:
	seed_value = run_seed


## The stream called `name`, created on first use.
func stream(name: StringName) -> RandomNumberGenerator:
	if not _streams.has(name):
		var rng := RandomNumberGenerator.new()
		rng.seed = ("%d:%s" % [seed_value, name]).hash()
		_streams[name] = rng
	return _streams[name]
