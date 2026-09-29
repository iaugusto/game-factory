class_name TipCard
extends Resource
## One card of a tip: a short title, one or two short lines, an optional picture, and what to
## spotlight. Text limits (TITLE_MAX, BODY_MAX) keep every card readable at a glance; the
## content test enforces them (docs/2026-09-27-style-and-tutorials/).

const TITLE_MAX: int = 24
const BODY_MAX: int = 80

@export var title: String = ""
@export_multiline var body: String = ""
## Art key for the card's picture (e.g. "fx/coin"); empty for none. A new-enemy tip shows the
## enemy's portrait instead.
@export var icon: String = ""
## What to spotlight (TipDirector.FOCUSES): a UI element or a thing on the field; &"" for
## nothing (the whole screen dims evenly).
@export var focus: StringName = &""
## A looping clip shown above the text (res://clips/*.ogv), for cards where seeing it beats
## reading about it (special attacks); "" for none. A missing file is skipped.
@export_file("*.ogv") var clip: String = ""
## A "do" step: the card stays until this event (TipDirector.WAIT_EVENTS) happens, and only a
## tap inside the spotlight gets through. &"" means a tap anywhere turns the card.
@export var wait_for: StringName = &""
