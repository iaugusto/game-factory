class_name TipLayer
extends Control
## Shows one tip at a time: the screen dims except a spotlight on the thing it is about, and a
## small card (picture, a short title, a line or two, page dots) slides in on the other half of
## the screen. A tap turns the card; on a "do" card only a tap inside the spotlight counts, and
## it is passed through (focus_pressed) so the player really does the thing.
##
## It holds no rules and no timing of the game: the owner decides when to show a tip, slows
## time to a near-stop while `freeze` rises (and stops ticking the run), and resolves each
## card's spotlight to a rectangle. Its own animation runs on unscaled time (delta divided by
## the time scale), so it keeps moving while the game is frozen, and in fixed-fps captures.

## The player finished the tip (every card read or done).
signal finished(pending: TipDirector.Pending)
## A tap inside the spotlight on a "do" card, to be handled as game input.
signal focus_pressed(event: InputEvent)

const SLIDE_TIME: float = 0.18
const FREEZE_TIME: float = 0.15
## Taps in the first moments of a card are ignored, so a tap meant for the game doesn't skip it.
const READ_GUARD: float = 0.35
const CARD_WIDTH: float = 460.0
## A card's clip (Page.clip) is shown this big, looping, above its text.
const CLIP_SIZE: Vector2 = Vector2(260, 260)
const MARGIN: float = 16.0
## The width of a card's text column (beside the picture): wrapping text there is this wide.
const TEXT_WIDTH: float = CARD_WIDTH - 72 - 14 - 28

## One card as shown: title, body, an optional picture and extra row, the spotlight rectangle
## (canvas coordinates; zero size for none) and the event a "do" card waits for.
class Page:
	var title: String = ""
	var body: String = ""
	var picture: Control = null
	var extra: Control = null
	## A looping clip above the text (a res:// .ogv path), or "" (a missing file is skipped).
	var clip: String = ""
	var focus: Rect2 = Rect2()
	## When set, the spotlight is re-measured every frame (focus_key, focus_arg) -> Rect2, so it
	## follows UI that is still animating in.
	var focus_key: StringName = &""
	var focus_arg: StringName = &""
	var wait_for: StringName = &""


## The tip being shown (null when idle).
var current: TipDirector.Pending = null
## 0..1: how far time should be stopped. The owner scales Engine.time_scale by 1 - freeze.
var freeze: float = 0.0
var pages: Array[Page] = []
## The owner's spotlight resolver, (focus_key, focus_arg) -> Rect2 in canvas coordinates.
var resolver: Callable
var page_index: int = 0

var _dim: ColorRect
var _card: PanelContainer
var _picture_slot: CenterContainer
var _clip_slot: CenterContainer
var _title: Label
var _body: Label
var _extra_slot: VBoxContainer
var _dots: Label
var _hint: Label
var _pointer: Control
## Unscaled seconds the current card has been up.
var _age: float = 0.0
var _pulse: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/spotlight.gdshader")
	mat.set_shader_parameter("dim_color", UiTheme.look.dim)
	mat.set_shader_parameter("ring_color", UiTheme.look.action)
	_dim.material = mat
	add_child(_dim)
	_pointer = Control.new()
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.draw.connect(_draw_pointer)
	add_child(_pointer)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiTheme.panel(Color(0, 0, 0, 0), -1,
			Color(UiTheme.look.action, 0.6), 2))
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	_clip_slot = CenterContainer.new()
	_clip_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_clip_slot)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_picture_slot = CenterContainer.new()
	_picture_slot.custom_minimum_size = Vector2(72, 72)
	_picture_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_picture_slot)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	_title = UiTheme.label("", &"label", UiTheme.look.title)
	text.add_child(_title)
	_body = UiTheme.label("", &"body")
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	text.add_child(_body)
	_extra_slot = VBoxContainer.new()
	_extra_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(_extra_slot)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(foot)
	_dots = UiTheme.label("", &"caption", UiTheme.look.text_dim)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_dots)
	_hint = UiTheme.label("", &"caption", UiTheme.look.action)
	foot.add_child(_hint)
	visible = false


func is_active() -> bool:
	return current != null


## Show tip `p` as `tip_pages` (built by the owner from its cards).
func show_tip(p: TipDirector.Pending, tip_pages: Array[Page]) -> void:
	current = p
	pages = tip_pages
	page_index = 0
	visible = true
	_show_page()


## The event a "do" card waits for has happened: turn the card.
func complete(event: StringName) -> void:
	if current != null and _page().wait_for == event:
		_advance()


## The current card's spotlight (for tests and the owner).
func focus_rect() -> Rect2:
	return _page().focus if current != null else Rect2()


## Turn the card as a tap would (tests, and the owner on a "do" card's event).
func advance() -> void:
	if current != null:
		_advance()


func _page() -> Page:
	return pages[page_index]


func _show_page() -> void:
	var pg: Page = _page()
	_title.text = pg.title
	_title.visible = pg.title != ""
	_body.text = pg.body
	_body.visible = pg.body != ""
	for slot: Container in [_picture_slot, _extra_slot, _clip_slot]:
		for c: Node in slot.get_children():
			slot.remove_child(c)
			c.free()  # at once: a queued free would linger as an orphan
	if pg.picture != null:
		_picture_slot.add_child(pg.picture)
	_picture_slot.visible = pg.picture != null
	if pg.extra != null:
		_fit_text(pg.extra)
		_extra_slot.add_child(pg.extra)
	var player: VideoStreamPlayer = clip_player(pg.clip)
	if player != null:
		_clip_slot.add_child(player)
	_clip_slot.visible = player != null
	var dots: PackedStringArray = []
	for i: int in pages.size():
		dots.append("●" if i == page_index else "○")
	_dots.text = " ".join(dots) if pages.size() > 1 else ""
	_hint.text = "TAP THE GLOW" if pg.wait_for != &"" else \
			("NEXT  ▸" if page_index + 1 < pages.size() else "GOT IT  ▸")
	_apply_focus()
	_card.reset_size()
	_age = 0.0
	_pulse = 0.0
	_layout_card(0.0)
	_pointer.queue_redraw()


## A wrapping label with no width of its own wraps at almost zero width inside the card: one
## word per line, a card taller than the screen (the "How to use it" card did this). Give every
## wrapping label under `node` the text column's width.
static func _fit_text(node: Node) -> void:
	if node is Label and (node as Label).autowrap_mode != TextServer.AUTOWRAP_OFF \
			and (node as Label).custom_minimum_size.x <= 0.0:
		(node as Label).custom_minimum_size.x = TEXT_WIDTH
	for c: Node in node.get_children():
		_fit_text(c)


## The card's height as laid out (for tests: no card may outgrow the screen).
func card_height() -> float:
	return _card.get_combined_minimum_size().y


func _apply_focus() -> void:
	var pg: Page = _page()
	if pg.focus_key != &"" and resolver.is_valid():
		pg.focus = resolver.call(pg.focus_key, pg.focus_arg)
	var mat: ShaderMaterial = _dim.material
	mat.set_shader_parameter("has_focus", 1.0 if pg.focus.size.x > 0.0 else 0.0)
	mat.set_shader_parameter("rect_pos", pg.focus.position)
	mat.set_shader_parameter("rect_size", pg.focus.size)


## The card sits on the half of the screen the spotlight isn't in; `k` 0..1 is the slide.
func _layout_card(k: float) -> void:
	var view: Vector2 = get_viewport_rect().size
	var pg: Page = _page()
	var focus_low: bool = pg.focus.size.x > 0.0 and pg.focus.get_center().y > view.y * 0.5
	var w: float = minf(CARD_WIDTH, view.x - MARGIN * 2.0)
	_card.size.x = w
	var x: float = (view.x - w) / 2.0
	var y: float = Hud.HEIGHT + MARGIN if focus_low \
			else view.y - _card.size.y - MARGIN * 5.0
	if pg.focus.size.x > 0.0 and not focus_low:
		y = maxf(y, pg.focus.end.y + MARGIN)
		y = minf(y, view.y - _card.size.y - MARGIN)
	var ease_k: float = 1.0 - (1.0 - k) * (1.0 - k)
	var from: float = -40.0 if focus_low else 40.0
	_card.position = Vector2(x, y + from * (1.0 - ease_k))
	_card.modulate.a = ease_k


## Seconds the current card has been up (unscaled).
func age() -> float:
	return _age


func _process(delta: float) -> void:
	var real: float = minf(0.1, delta / maxf(Engine.time_scale, 0.0001))
	var target: float = 1.0 if current != null else 0.0
	freeze = move_toward(freeze, target, real / FREEZE_TIME)
	_dim.modulate.a = freeze  # the dim fades in and out with the freeze, never snaps
	if current == null:
		if freeze <= 0.0:
			visible = false
		return
	_age += real
	_apply_focus()
	_layout_card(minf(1.0, _age / SLIDE_TIME))
	_pulse = fmod(_pulse + real / 1.2, 1.0)
	var mat: ShaderMaterial = _dim.material
	mat.set_shader_parameter("pulse", _pulse)
	mat.set_shader_parameter("screen_size", size)
	_pointer.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if current == null:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var pressed: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) \
			and event.pressed
	if not pressed:
		return
	accept_event()
	var pg: Page = _page()
	if pg.wait_for != &"":
		if pg.focus.has_point(event.position):
			focus_pressed.emit(event)
		return
	if _age < READ_GUARD:
		return
	_advance()


func _advance() -> void:
	if page_index + 1 < pages.size():
		page_index += 1
		_show_page()
		return
	var done: TipDirector.Pending = current
	current = null
	_card.modulate.a = 0.0
	finished.emit(done)


## A looping, muted player for clip `path`, framed; null if the file doesn't exist.
static func clip_player(path: String) -> VideoStreamPlayer:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var v := VideoStreamPlayer.new()
	v.stream = load(path)
	v.expand = true
	v.custom_minimum_size = CLIP_SIZE
	v.loop = true
	v.autoplay = true
	v.volume_db = -80.0
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


## A row of unit icons under a caption ("WEAK TO", "SHRUGS OFF"), for new-enemy cards.
static func unit_row(caption: String, units: Array[UnitDef], color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.label(caption, &"caption", color)
	l.custom_minimum_size = Vector2(96, 0)
	row.add_child(l)
	for u: UnitDef in units:
		var icon := UnitIcon.new()
		icon.unit = u
		icon.custom_minimum_size = Vector2(32, 32)
		row.add_child(icon)
	return row


## A chevron bobbing above the spotlight on "do" cards: tap here.
func _draw_pointer() -> void:
	if current == null or _page().wait_for == &"" or _page().focus.size.x <= 0.0:
		return
	var r: Rect2 = _page().focus
	var bob: float = 6.0 * sin(_age * 6.0)
	var tip := Vector2(r.get_center().x, r.position.y - 8.0 + bob)
	var pts := PackedVector2Array([tip, tip + Vector2(-16, -22), tip + Vector2(16, -22)])
	_pointer.draw_colored_polygon(pts, UiTheme.look.action)
	_pointer.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]),
			UiTheme.look.text_outline, 2.0, true)
