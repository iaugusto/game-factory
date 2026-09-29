class_name Hud
extends Control
## The top bar: wall HP (shield icon + bar), the wave, an Overdrive timer when active, the coin
## counter (counts up toward the real balance, pulses as flying coins land).

const HEIGHT: float = 50.0

var wave_label: Label
var coin_label: Label
var wall_label: Label
var wall_bar: ProgressBar
var boost_label: Label
var coin_icon: TextureRect
var _shown_gold: float = 0.0
var _pulse: float = 0.0
var _boost_row: HBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	var style := UiTheme.panel(Color(UiTheme.look.panel, 0.96), 0, Color(0, 0, 0, 0), 0)
	style.border_color = Color(UiTheme.look.title, 0.3)
	style.border_width_bottom = 2
	bg.add_theme_stylebox_override("panel", style)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -8
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	row.add_child(UiTheme.icon("ui/wall", 26))
	var wall_box := VBoxContainer.new()
	wall_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wall_box.add_theme_constant_override("separation", 0)
	wall_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(wall_box)
	wall_bar = ProgressBar.new()
	wall_bar.custom_minimum_size = Vector2(96, 12)
	wall_bar.show_percentage = false
	wall_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.look.gate
	fill.set_corner_radius_all(4)
	wall_bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = UiTheme.look.gate.darkened(0.8)
	back.set_corner_radius_all(4)
	back.border_color = Color(0, 0, 0, 0.8)
	back.set_border_width_all(1)
	wall_bar.add_theme_stylebox_override("background", back)
	wall_box.add_child(wall_bar)
	wall_label = UiTheme.label("100", &"caption", UiTheme.look.text_dim)
	wall_box.add_child(wall_label)
	var spacer_l := Control.new()
	spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer_l)
	var mid := VBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", -2)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mid)
	wave_label = UiTheme.label("WAVE 1/10", &"label", UiTheme.look.text)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(wave_label)
	_boost_row = HBoxContainer.new()
	_boost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_boost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boost_row.add_child(UiTheme.icon("ui/bolt", 14))
	boost_label = UiTheme.label("", &"caption", UiTheme.look.owned)
	_boost_row.add_child(boost_label)
	_boost_row.visible = false
	mid.add_child(_boost_row)
	var spacer_r := Control.new()
	spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer_r)
	coin_icon = UiTheme.icon("fx/coin", 24)
	coin_icon.pivot_offset = Vector2(12, 12)
	row.add_child(coin_icon)
	coin_label = UiTheme.label("0", &"label", UiTheme.look.coin)
	coin_label.custom_minimum_size = Vector2(46, 0)
	row.add_child(coin_label)


func sync(run: Run, delta: float = 0.0) -> void:
	wave_label.text = "WAVE %d/%d" % [mini(run.wave_index + 1, run.wave_count()), run.wave_count()]
	wall_bar.max_value = run.wall_max()
	wall_bar.value = maxf(0.0, run.wall_hp())
	wall_label.text = "%d / %d" % [ceili(maxf(0.0, run.wall_hp())), roundi(run.wall_max())]
	var boost: float = run.combat.boost_time
	_boost_row.visible = boost > 0.0
	boost_label.text = "OVERDRIVE %.1fs" % boost
	# The counter chases the real balance so income reads as a count-up, spending as a drop.
	if run.gold < _shown_gold or delta <= 0.0:
		_shown_gold = run.gold
	else:
		_shown_gold = minf(float(run.gold), _shown_gold + maxf(30.0, (run.gold - _shown_gold) * 6.0) * delta)
	coin_label.text = str(roundi(_shown_gold))
	_pulse = maxf(0.0, _pulse - delta * 5.0)
	coin_icon.scale = Vector2.ONE * (1.0 + 0.35 * _pulse)


func pulse_coins() -> void:
	_pulse = 1.0


## Centre of the coin icon in canvas coordinates (where flying coins go).
func coin_icon_center() -> Vector2:
	return coin_icon.get_global_rect().get_center()
