class_name BuildMenu
extends Control
## The radial menu that opens on a build plot.
##
## Empty plot: every unit on a ring around the plot, each showing the unit as it will look,
## its damage-type badge, its name and its price (greyed with a red price when unaffordable).
## One tap builds.
## Built plot: a card with its stats (and the next level's), its damage type and the enemies
## it is strong against, an Upgrade button (or, at max level, the two masteries to choose
## from), and SELL (a 50% refund: replacing a unit costs).
##
## It covers the screen so a tap anywhere else closes it. It holds no rules: it asks Run for
## prices and emits requests; RunController calls Run.build / Run.upgrade.

signal build_requested(plot: int, unit_id: StringName)
signal upgrade_requested(plot: int)
signal sell_requested(plot: int)
signal repair_requested(plot: int)
signal mastery_requested(plot: int, index: int)
signal closed

const RING_RADIUS: float = 84.0
const BUTTON_SIZE: float = 60.0

var plot: int = -1
var _center: Vector2
var _unit_buttons: Dictionary[StringName, Button] = {}
var _price_labels: Dictionary[StringName, Label] = {}
var _icons: Dictionary[StringName, UnitIcon] = {}
var _upgrade: Button
var _sell: Button
var _repair: Button
var _masteries: Array[Button] = []
var _stats: Label
var _card: PanelContainer
var _card_above: bool = false
var _ring: Control
var _t: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func is_open() -> bool:
	return visible


func close() -> void:
	if not visible:
		return
	visible = false
	plot = -1
	closed.emit()


## Open on plot `index` at `screen_pos` (canvas coordinates).
func open(index: int, screen_pos: Vector2, run: Run) -> void:
	_clear()
	plot = index
	_t = 0.0
	var view: Vector2 = get_viewport_rect().size
	var margin: float = RING_RADIUS + BUTTON_SIZE * 0.6
	_center = Vector2(clampf(screen_pos.x, margin, view.x - margin),
			clampf(screen_pos.y, margin + Hud.HEIGHT, view.y - margin - 20.0))
	_ring = Control.new()
	_ring.position = _center
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	if run.plots[index].is_empty():
		_open_build(run)
	else:
		_open_upgrade(run)
	visible = true
	sync(run)


func _open_build(run: Run) -> void:
	var units: Array[UnitDef] = run.config.units
	for i: int in units.size():
		var u: UnitDef = units[i]
		var a: float = -PI / 2.0 + TAU * i / units.size()
		var p: Vector2 = Vector2.from_angle(a) * RING_RADIUS
		var b := Button.new()
		b.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		b.size = b.custom_minimum_size
		b.position = p - b.size / 2.0
		UiTheme.style_button(b, false, 12, int(BUTTON_SIZE / 2.0))
		b.pressed.connect(func() -> void: build_requested.emit(plot, u.id))
		var icon := UnitIcon.new()
		icon.unit = u
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 4
		icon.offset_top = 4
		icon.offset_right = -4
		icon.offset_bottom = -4
		b.add_child(icon)
		var badge := UiTheme.icon(damage_icon(u.damage_type), 20)
		badge.position = Vector2(BUTTON_SIZE - 18, -2)
		b.add_child(badge)
		_ring.add_child(b)
		var title := UiTheme.label(u.display_name, 11, UiTheme.TEXT, 4)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.custom_minimum_size = Vector2(90, 0)
		title.position = p + Vector2(-45, BUTTON_SIZE / 2.0 - 4)
		_ring.add_child(title)
		var price := UiTheme.label("", 13, UiTheme.ACCENT, 4)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.custom_minimum_size = Vector2(90, 0)
		price.position = p + Vector2(-45, BUTTON_SIZE / 2.0 + 9)
		_ring.add_child(price)
		_unit_buttons[u.id] = b
		_price_labels[u.id] = price
		_icons[u.id] = icon


func _open_upgrade(run: Run) -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiTheme.panel(UiTheme.PANEL, 12,
			Color(UiTheme.ACCENT, 0.35), 1))
	_card.custom_minimum_size = Vector2(230, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_card.add_child(box)
	_stats = UiTheme.label("", 14, UiTheme.TEXT, 3)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.custom_minimum_size = Vector2(206, 0)
	box.add_child(_stats)
	var u: UnitDef = run.plots[plot].def
	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 6)
	type_row.add_child(UiTheme.icon(damage_icon(u.damage_type), 18))
	var strong: Array[String] = []
	for e: EnemyDef in Counters.enemies_countered_by(run.config, u):
		strong.append(e.display_name)
	var type_label := UiTheme.label("%s · strong vs %s" % [UnitDef.DAMAGE_TYPE_NAMES[u.damage_type],
			", ".join(strong) if not strong.is_empty() else "—"], 12, UiTheme.GOOD, 3)
	type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	type_label.custom_minimum_size = Vector2(180, 0)
	type_row.add_child(type_label)
	box.add_child(type_row)
	_upgrade = Button.new()
	_upgrade.custom_minimum_size = Vector2(206, 44)
	UiTheme.style_button(_upgrade, true, 16)
	_upgrade.pressed.connect(func() -> void: upgrade_requested.emit(plot))
	box.add_child(_upgrade)
	for i: int in u.masteries.size():
		var m: MasteryDef = u.masteries[i]
		var mb := Button.new()
		mb.custom_minimum_size = Vector2(206, 44)
		UiTheme.style_button(mb, true, 13)
		mb.pressed.connect(func() -> void: mastery_requested.emit(plot, i))
		mb.tooltip_text = m.description
		box.add_child(mb)
		_masteries.append(mb)
	_repair = Button.new()
	_repair.custom_minimum_size = Vector2(206, 36)
	UiTheme.style_button(_repair, false, 14)
	_repair.pressed.connect(func() -> void: repair_requested.emit(plot))
	box.add_child(_repair)
	_sell = Button.new()
	_sell.custom_minimum_size = Vector2(206, 36)
	UiTheme.style_button(_sell, false, 14)
	_sell.pressed.connect(func() -> void: sell_requested.emit(plot))
	box.add_child(_sell)
	_ring.add_child(_card)
	# The card goes toward the screen's middle, clear of the unit.
	_card_above = _center.y > get_viewport_rect().size.y * 0.5


## The UI icon key for a damage type.
static func damage_icon(type: UnitDef.DamageType) -> String:
	return "ui/dmg_%s" % UnitDef.DAMAGE_TYPE_NAMES[type].to_lower()


## Refresh prices and affordability (coins change mid-wave while the menu is open).
func sync(run: Run) -> void:
	if not visible or plot < 0:
		return
	for id: StringName in _unit_buttons:
		var cost: int = run.unit_cost(id)
		var ok: bool = run.gold >= cost and run.can_spend()
		_unit_buttons[id].disabled = not ok
		_icons[id].dimmed = not ok
		_price_labels[id].text = "● %d" % cost
		_price_labels[id].add_theme_color_override("font_color", UiTheme.ACCENT if ok else UiTheme.BAD)
	if _upgrade != null:
		var p: CombatSim.Plot = run.plots[plot]
		if p.is_empty():
			return
		var cost: int = run.upgrade_cost(plot)
		var u: UnitDef = p.def
		var lvl: int = p.level
		var next: int = mini(lvl + 1, u.max_level())
		var reload_now: float = run.combat.plot_reload(p)
		var reload_next: float = run.combat.reload_for(u, next, p.mastery)
		var dmg_now: float = run.combat.plot_damage(p)
		var dmg_next: float = run.combat.damage_for(u, next, p.mastery)
		var mastery: String = "\n★ %s: %s" % [p.mastery.title, p.mastery.description] \
				if p.mastery != null else ""
		if cost < 0:
			_stats.text = "%s  ·  Lv %d/%d\nDamage %.1f  ·  Reload %.2fs\nReach %d%s" % [
					u.display_name, lvl, u.max_level(), dmg_now, reload_now,
					roundi(run.combat.plot_reach(p)), mastery]
		else:
			_stats.text = "%s  ·  Lv %d → %d\nDamage %.1f → %.1f\nReload %.2fs → %.2fs\nReach %d" % [
					u.display_name, lvl, next, dmg_now, dmg_next, reload_now, reload_next,
					roundi(run.combat.plot_reach(p))]
		# Upgrade until max level; then the masteries (once one is bought, none).
		var m_cost: int = run.mastery_cost(plot)
		_upgrade.visible = cost >= 0 or (m_cost < 0 and p.mastery == null)
		_upgrade.text = "UPGRADE  ● %d" % cost if cost >= 0 else "MAX LEVEL"
		_upgrade.disabled = cost < 0 or run.gold < cost or not run.can_spend()
		for i: int in _masteries.size():
			var mb: Button = _masteries[i]
			var m: MasteryDef = u.masteries[i]
			mb.visible = m_cost >= 0
			mb.text = "%s  ● %d\n%s" % [m.title.to_upper(), m_cost, m.description]
			mb.disabled = m_cost < 0 or run.gold < m_cost or not run.can_spend()
		var repair: int = run.unit_repair_cost(plot)
		_repair.visible = repair >= 0
		_repair.text = "REPAIR  %d/%d HP  ● %d" % [ceili(p.hp), roundi(p.max_hp), repair]
		_repair.disabled = repair < 0 or run.gold < repair or not run.can_spend()
		_sell.text = "SELL  +%d" % run.sell_value(plot)
		_sell.disabled = not run.can_spend()
		# Placed after the text is in, so its real height is known.
		_card.reset_size()
		_card.position = Vector2(-_card.size.x / 2.0, -_card.size.y - 36) if _card_above \
				else Vector2(-_card.size.x / 2.0, 36)


func _process(delta: float) -> void:
	if not visible or _ring == null:
		return
	_t += delta
	var k: float = minf(1.0, _t / 0.14)
	_ring.scale = Vector2.ONE * (0.6 + 0.4 * (1.0 - (1.0 - k) * (1.0 - k)))
	_ring.modulate.a = k


func _gui_input(event: InputEvent) -> void:
	# A press that no button took is a tap outside: close.
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		accept_event()
		close()


func _clear() -> void:
	if _ring != null:
		_ring.queue_free()
	_ring = null
	_unit_buttons.clear()
	_price_labels.clear()
	_icons.clear()
	_upgrade = null
	_sell = null
	_repair = null
	_masteries.clear()
	_stats = null
	_card = null
