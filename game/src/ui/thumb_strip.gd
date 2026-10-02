class_name ThumbStrip
extends Panel
## The bottom thumb strip of the run screen (E9, the tall-screen layout): a band along the
## screen's bottom edge, where a thumb reaches on a tall phone. It holds the run's controls:
## in BUILD, BuildBar's repair and start buttons (their own panel, drawn over this one); in a
## wave, the special attack (AbilityButton, placed by RunController._layout). It sits over the
## lower, decorative part of the wall art (the wall spots are above it) and stops taps from
## reaching the field beneath.

const HEIGHT: float = 84.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -HEIGHT
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := UiTheme.panel(Color(UiTheme.look.panel, 0.96), 0, Color(0, 0, 0, 0), 0)
	style.border_color = Color(UiTheme.look.title, 0.3)
	style.border_width_top = 2
	add_theme_stylebox_override("panel", style)
