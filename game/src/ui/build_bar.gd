class_name BuildBar
extends Control
## The BUILD phase's bar: the coming wave's preview (each enemy type's picture × its count, so
## the player can build the right counters), a gate repair, and the big "start the wave"
## button. It sits at the top, just under the HUD, where the field is empty before a wave; the
## bottom belongs to the wall and its build spots. The field below stays live, so plots can be
## tapped.

signal start_pressed
signal repair_pressed

## Height of the bar; tests check no plot sits under it.
const HEIGHT: float = 128.0

var start_button: Button
var repair_button: Button
var preview: HBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_top = Hud.HEIGHT
	offset_bottom = Hud.HEIGHT + HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(Color(UiTheme.look.panel, 0.9), 0,
			Color(0, 0, 0, 0), 0))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_right = -14
	box.offset_top = 6
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	var next := UiTheme.label("NEXT", &"caption", UiTheme.look.text_dim)
	top.add_child(next)
	preview = HBoxContainer.new()
	preview.add_theme_constant_override("separation", 8)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(preview)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	repair_button = Button.new()
	repair_button.custom_minimum_size = Vector2(130, 56)
	UiTheme.style_button(repair_button, false, &"caption")
	repair_button.pressed.connect(func() -> void: repair_pressed.emit())
	row.add_child(repair_button)
	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(0, 56)
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_button(start_button, true, &"label", 14)
	start_button.pressed.connect(func() -> void: start_pressed.emit())
	row.add_child(start_button)
	visible = false


## Show the bar for the build phase before wave `wave_number` (1-based) of `run`.
func show_for(wave_number: int, total: int, run: Run = null) -> void:
	start_button.text = "START WAVE %d/%d  ▶" % [wave_number, total]
	for c: Node in preview.get_children():
		preview.remove_child(c)
		c.free()  # at once: a queued free would linger as an orphan
	if run != null:
		var wave: WaveDef = run.config.waves[wave_number - 1]
		var counts: Dictionary = WaveSchedule.enemy_counts(wave)
		for e: EnemyDef in counts:
			preview.add_child(_preview_item(e, counts[e], null))
		for entry: SpawnEntry in wave.spawns:  # elite groups again, tinted and starred
			if entry.elite != null:
				preview.add_child(_preview_item(entry.enemy, entry.count, entry.elite))
		sync(run)
	visible = true


static func _preview_item(e: EnemyDef, count: int, elite: EliteDef) -> Control:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 0)
	var icon := EnemyIcon.make(e, 26)
	if elite != null:
		icon.modulate = elite.tint
		icon.tooltip_text = "%s: %s" % [elite.title, elite.description]
	item.add_child(icon)
	var text: String = "★×%d" % count if elite != null else "×%d" % count
	item.add_child(UiTheme.label(text, &"caption", elite.tint if elite != null else UiTheme.look.text))
	return item


## Keep the repair button's price and availability current.
func sync(run: Run) -> void:
	repair_button.text = "REPAIR GATE\n+%d  ● %d" % [roundi(run.config.gate_repair_hp),
			run.config.gate_repair_cost]
	repair_button.disabled = not run.can_repair_gate()


## Enemy ids previewed, in order (for tests).
func previewed_count() -> int:
	return preview.get_child_count()
