class_name UiTheme
extends RefCounted
## Shared look for the UI: dark, slightly translucent steel panels with an amber accent
## (the defenders' HUD), rounded corners, soft shadows. One place, so every screen matches.

const PANEL := Color(0.07, 0.08, 0.1, 0.9)
const PANEL_LIGHT := Color(0.13, 0.15, 0.19, 0.95)
const ACCENT := Color("#ffc24a")
const ACCENT_DARK := Color("#b8801e")
const TEAL := Color("#3de0c8")
const TEXT := Color("#f2ead8")
const TEXT_DIM := Color("#a8a090")
const BAD := Color("#ff6b5a")
const GOOD := Color("#8dffb0")


static func panel(bg: Color = PANEL, radius: int = 14, border: Color = Color(1, 1, 1, 0.08),
		border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	s.set_content_margin_all(12)
	return s


## Style a Button: amber primary (`primary`) or steel secondary, with pressed/disabled states.
static func style_button(b: Button, primary: bool = true, font_size: int = 20,
		radius: int = 12) -> void:
	var base: Color = ACCENT if primary else PANEL_LIGHT
	var text: Color = Color("#1a1206") if primary else TEXT
	var normal := panel(base, radius, base.lightened(0.25), 2)
	normal.shadow_size = 4
	var hover := panel(base.lightened(0.12), radius, base.lightened(0.35), 2)
	var pressed := panel(base.darkened(0.2), radius, base.lightened(0.1), 2)
	pressed.shadow_size = 1
	var disabled := panel(Color(0.2, 0.2, 0.22, 0.9), radius, Color(1, 1, 1, 0.05), 1)
	for pair: Array in [["normal", normal], ["hover", hover], ["pressed", pressed],
			["disabled", disabled], ["focus", normal]]:
		b.add_theme_stylebox_override(pair[0], pair[1])
	b.add_theme_color_override("font_color", text)
	b.add_theme_color_override("font_hover_color", text)
	b.add_theme_color_override("font_pressed_color", text)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE


static func label(text: String = "", size: int = 18, color: Color = TEXT,
		outline: int = 4) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func icon(key: String, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.tex(key)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
