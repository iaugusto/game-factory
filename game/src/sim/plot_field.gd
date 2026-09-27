class_name PlotField
extends Node2D
## The build plots and whatever stands on them: one PlotView per plot (a handful of nodes, so
## nodes are fine here). Reads Run.plots; reacts to CombatSim.unit_fired for recoil and muzzle
## flashes. Also answers "which plot is under this point?" for input.

## Taps within this distance of a plot centre select it.
const HIT_RADIUS: float = 34.0

var views: Array[PlotView] = []
var selected: int = -1


func setup(run: Run) -> void:
	for v: PlotView in views:
		v.queue_free()
	views.clear()
	selected = -1
	for plot: CombatSim.Plot in run.plots:
		var v := PlotView.new()
		v.plot = plot
		v.position = plot.position
		v.on_wall = plot.position.y > run.config.wall_y
		v.high_ground = plot.terrain_reach > 0.0
		v.set_selected(false)
		add_child(v)
		views.append(v)
	run.combat.unit_fired.connect(_on_unit_fired)


## The plot under `field_pos`, or -1.
func plot_at(field_pos: Vector2) -> int:
	var best: int = -1
	var best_d: float = HIT_RADIUS * HIT_RADIUS
	for v: PlotView in views:
		var d: float = v.position.distance_squared_to(field_pos)
		if d <= best_d:
			best_d = d
			best = v.plot.index
	return best


func select(index: int) -> void:
	selected = index
	for v: PlotView in views:
		v.set_selected(v.plot.index == index)


func sync(run: Run, delta: float) -> void:
	for v: PlotView in views:
		v.wave_number = run.wave_index + 1
		v.sync(run.combat, delta)


func _on_unit_fired(plot: CombatSim.Plot, target: Vector2) -> void:
	if plot.index < views.size():
		views[plot.index].on_fired(target)
