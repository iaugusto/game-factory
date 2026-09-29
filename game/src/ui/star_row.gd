class_name StarRow
extends HBoxContainer
## A row of campaign stars: `earned` gold ones, then empty sockets up to `total`
## (art: ui/star, ui/star_empty). Used by the campaign screen and the result screen.

var earned: int = 0
var total: int = 3
var star_size: float = 28.0


static func make(earned_stars: int, size: float = 28.0, total_stars: int = 3) -> StarRow:
	var row := StarRow.new()
	row.star_size = size
	row.total = total_stars
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(size * 0.12))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_stars(earned_stars)
	return row


func set_stars(n: int) -> void:
	earned = clampi(n, 0, total)
	for child: Node in get_children():
		remove_child(child)
		child.free()
	for i: int in total:
		add_child(UiTheme.icon("ui/star" if i < earned else "ui/star_empty", star_size))


## The earned stars pop in one by one after `delay` real seconds (the result screen's reward
## beat): each grows from nothing past full size and settles.
func pop_in(delay: float = 0.0, stagger: float = 0.22) -> void:
	if not is_inside_tree():
		return
	for i: int in earned:
		var star: Control = get_child(i)
		star.pivot_offset = Vector2.ONE * star_size / 2.0
		# Hidden by alpha, not scale: the container's sort resets children's scale to 1.
		star.modulate.a = 0.0
		var t: Tween = star.create_tween().set_ignore_time_scale(true)
		t.tween_interval(delay + stagger * i)
		t.tween_callback(func() -> void:
			star.scale = Vector2.ONE * 0.3
			star.modulate.a = 1.0)
		t.tween_property(star, "scale", Vector2.ONE * 1.35, 0.14).set_ease(Tween.EASE_OUT)
		t.tween_property(star, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
