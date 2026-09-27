class_name EnemyIcon
extends TextureRect
## An enemy as it looks on the field (frame 0 of its walk atlas), scaled into a UI box.


static func make(e: EnemyDef, box: float) -> EnemyIcon:
	var icon := EnemyIcon.new()
	var tex: Texture2D = Art.tex("enemies/%s" % e.id)
	if tex != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(Vector2.ZERO, Vector2(tex.get_width() / 2.0, tex.get_height()))
		icon.texture = atlas
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(box, box)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
