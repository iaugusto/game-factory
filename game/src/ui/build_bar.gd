class_name BuildBar
extends Control
## The BUILD phase's controls, in two parts (E9, the tall-screen layout):
## - the coming wave's **preview** (each enemy type's picture × its count, so the player can
##   build the right counters) in a slim panel at the top, just under the HUD, where the field
##   is empty before a wave;
## - **gate repair** and the big **start the wave** button in the bottom thumb strip
##   (ThumbStrip), where a thumb reaches on a tall phone.
## The field between stays live, so plots can be tapped.

signal start_pressed
signal repair_pressed

## Height of the top preview panel; tests check no plot sits under either part.
const PREVIEW_HEIGHT: float = 44.0

var start_button: Button
var repair_button: Button
var preview: HBoxContainer
var _top: Panel
var _bottom: Panel


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top = _panel()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_top = Hud.HEIGHT
	_top.offset_bottom = Hud.HEIGHT + PREVIEW_HEIGHT
	add_child(_top)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.offset_left = 14
	top.offset_right = -14
	top.add_theme_constant_override("separation", 6)
	_top.add_child(top)
	var next := UiTheme.label("NEXT", &"caption", UiTheme.look.text_dim)
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(next)
	preview = HBoxContainer.new()
	preview.add_theme_constant_override("separation", 8)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(preview)
	_bottom = _panel()
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_top = -ThumbStrip.HEIGHT
	_bottom.offset_bottom = 0
	add_child(_bottom)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 12
	row.offset_bottom = -14
	row.add_theme_constant_override("separation", 8)
	_bottom.add_child(row)
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


static func _panel() -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel(Color(UiTheme.look.panel, 0.92), 0,
			Color(0, 0, 0, 0), 0))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


## The screen rectangles the bar covers (its two panels), for tests and layout checks.
func covered_rects() -> Array[Rect2]:
	return [_top.get_global_rect(), _bottom.get_global_rect()]


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
