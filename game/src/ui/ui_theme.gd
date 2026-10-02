class_name UiTheme
extends RefCounted
## The shared look of every screen, read from one StyleDef (fonts, type scale, palette, shape).
## Call sites ask for a *role* ("body", "heading", …) and a palette colour (`UiTheme.look.coin`),
## never a raw size or hex, so a new direction restyles the whole game from data.
##
## The active style is DEFAULT_STYLE, or `--style=<id>` on the command line (for comparing
## directions and for captures). Loading it also sets Godot's fallback font and size, so any
## control that isn't styled explicitly still matches.

const DEFAULT_STYLE: StringName = &"hybrid"
const STYLE_DIR: String = "res://data/styles/"

## The active style. Set once when the class loads; `use()` swaps it (tests, the switch).
static var look: StyleDef


static func _static_init() -> void:
	var id: StringName = DEFAULT_STYLE
	for a: String in LaunchArgs.get_args():
		if a.begins_with("--style="):
			id = StringName(a.get_slice("=", 1))
	use(id)


## Make style `id` active. Falls back to DEFAULT_STYLE for an unknown id.
static func use(id: StringName) -> void:
	var path: String = STYLE_DIR + String(id) + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("unknown style '%s'; using %s" % [id, DEFAULT_STYLE])
		path = STYLE_DIR + String(DEFAULT_STYLE) + ".tres"
	look = load(path)
	ThemeDB.fallback_font = look.body_font
	ThemeDB.fallback_font_size = look.body


## A panel StyleBox in the style's shape. `bg` defaults to the panel colour, `border` to the
## hairline; `radius` < 0 takes the style's.
static func panel(bg: Color = Color(0, 0, 0, 0), radius: int = -1,
		border: Color = Color(0, 0, 0, 0), border_w: int = -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg if bg.a > 0.0 else look.panel
	s.set_corner_radius_all(radius if radius >= 0 else look.radius)
	s.corner_detail = look.corner_detail
	s.border_color = border if border.a > 0.0 else look.line
	s.set_border_width_all(border_w if border_w >= 0 else look.border)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	s.set_content_margin_all(12)
	return s


## Style a Button: the action colour (`primary`, the one thing to press next) or a raised
## secondary, with hover/pressed/disabled states and the style's lip. Text uses the display
## face at `role`.
static func style_button(b: Button, primary: bool = true, role: StringName = &"label",
		radius: int = -1) -> void:
	var base: Color = look.action if primary else look.panel_raised
	var text: Color = look.action_text if primary else look.text
	var r: int = radius if radius >= 0 else look.radius
	var normal := _button_box(base, r, base.lightened(0.25))
	var hover := _button_box(base.lightened(0.12), r, base.lightened(0.35))
	var pressed := _button_box(base.darkened(0.2), r, base.lightened(0.1))
	pressed.shadow_size = 1
	pressed.border_width_bottom = look.border + 1
	pressed.content_margin_top += look.button_lip
	var disabled := _button_box(Color(0.2, 0.2, 0.22, 0.9), r, Color(1, 1, 1, 0.05))
	for pair: Array in [["normal", normal], ["hover", hover], ["pressed", pressed],
			["disabled", disabled], ["focus", normal]]:
		b.add_theme_stylebox_override(pair[0], pair[1])
	b.add_theme_color_override("font_color", text)
	b.add_theme_color_override("font_hover_color", text)
	b.add_theme_color_override("font_pressed_color", text)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	b.add_theme_font_override("font", look.font_of(&"label"))
	b.add_theme_font_size_override("font_size", look.size_of(role))
	b.focus_mode = Control.FOCUS_NONE
	if not b.has_meta(&"squash"):
		b.set_meta(&"squash", true)
		b.button_down.connect(squash.bind(b))


## Press feedback: a quick squash and spring back, on real time (menus open in slow motion and
## tips nearly stop time).
static func squash(c: Control, amount: float = 0.94) -> void:
	if not c.is_inside_tree():
		return
	c.pivot_offset = c.size / 2.0
	var t: Tween = c.create_tween().set_ignore_time_scale(true)
	t.tween_property(c, "scale", Vector2.ONE * amount, 0.05)
	t.tween_property(c, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


static func _button_box(bg: Color, radius: int, border: Color) -> StyleBoxFlat:
	var s := panel(bg, radius, border, look.border + 1)
	s.shadow_size = 4
	s.set_content_margin_all(8)
	if look.button_lip > 0:
		s.border_width_bottom = look.button_lip
		s.border_color = bg.darkened(0.45)
	return s


## A Label in text role `role` (caption, body, label, heading, display). `color` defaults to
## the text colour; `outline` < 0 scales the style's outline with the size.
static func label(text: String = "", role: StringName = &"body",
		color: Color = Color(0, 0, 0, 0), outline: int = -1) -> Label:
	var l := Label.new()
	l.text = text
	restyle(l, role, color, outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Re-apply a role to an existing Label (e.g. a popup label from a pool).
static func restyle(l: Label, role: StringName, color: Color = Color(0, 0, 0, 0),
		outline: int = -1) -> void:
	var size: int = look.size_of(role)
	l.add_theme_font_override("font", look.font_of(role))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color if color.a > 0.0 else look.text)
	l.add_theme_constant_override("outline_size", outline if outline >= 0
			else maxi(2, roundi(look.outline * size / float(look.body))))
	l.add_theme_color_override("font_outline_color", look.text_outline)
	l.uppercase = look.display_caps and (role == &"heading" or role == &"display")


## A full-screen modal dim in the style's colour, ignoring the mouse.
static func dim(alpha: float = -1.0) -> ColorRect:
	var d := ColorRect.new()
	d.color = look.dim if alpha < 0.0 else Color(look.dim, alpha)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


static func icon(key: String, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.tex(key)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
