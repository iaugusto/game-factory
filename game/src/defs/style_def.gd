class_name StyleDef
extends Resource
## One visual direction for the whole UI: fonts, a type scale, a palette in which every colour
## has one meaning, the panel shape, and a grade for the painted ground. UiTheme reads the
## active one (res://data/styles/<id>.tres), so switching direction is data, not code
## (docs/2026-09-27-style-and-tutorials/).

@export var id: StringName
@export var display_name: String = ""

@export_group("Fonts")
## Titles, banners and buttons.
@export var display_font: Font
## Body text, captions and numbers.
@export var body_font: Font
## Headings and buttons are set in capitals when true.
@export var display_caps: bool = true

@export_group("Type scale")
## Sizes in logical px on the 540-wide canvas; nothing is ever set below `caption`.
@export var caption: int = 15
@export var body: int = 19
@export var label: int = 22
@export var heading: int = 28
@export var display: int = 44
## Text outline width at body size; other roles scale it with their size.
@export var outline: int = 4

@export_group("Palette")
## Panels and cards, the raised variant (secondary buttons, info boxes) and their hairline.
@export var panel: Color = Color(0.07, 0.08, 0.1, 0.92)
@export var panel_raised: Color = Color(0.13, 0.15, 0.19, 0.96)
@export var line: Color = Color(1, 1, 1, 0.1)
## Full-screen backdrop behind menus (campaign screen) and the modal dim.
@export var backdrop: Color = Color("#14110f")
@export var dim: Color = Color(0.02, 0.01, 0.03, 0.72)
@export var text: Color = Color("#f2ead8")
@export var text_dim: Color = Color("#a8a090")
@export var text_outline: Color = Color(0, 0, 0, 0.85)
## Titles and headings.
@export var title: Color = Color("#ffc24a")
## Primary buttons only: the one thing to press next.
@export var action: Color = Color("#ffc24a")
@export var action_text: Color = Color("#1a1206")
## Coins, prices and loot.
@export var coin: Color = Color("#ffd35a")
## Owned, active, tech: skills owned, Overdrive, empty pads.
@export var owned: Color = Color("#3de0c8")
## Enemies, damage, loss.
@export var threat: Color = Color("#ff6b5a")
## Strong against, gains, victory.
@export var good: Color = Color("#8dffb0")
## The gate's HP bar.
@export var gate: Color = Color("#6fd0ff")

@export_group("Shape")
@export var radius: int = 12
## 1 draws cut (chamfered) corners; higher values round them.
@export var corner_detail: int = 8
@export var border: int = 1
## A darker lip under buttons (px), for a chunky, pressable look; 0 for flat.
@export var button_lip: int = 0

@export_group("Field")
## Multiplies the painted ground, so the field sits under the UI and enemies pop.
@export var field_tint: Color = Color.WHITE


## Size in px for a text role: caption, body, label, heading or display.
func size_of(role: StringName) -> int:
	match role:
		&"caption":
			return caption
		&"label":
			return label
		&"heading":
			return heading
		&"display":
			return display
	return body


## Names, titles, banners and buttons use the display face; body text and captions the body face.
func font_of(role: StringName) -> Font:
	return body_font if role == &"body" or role == &"caption" else display_font
