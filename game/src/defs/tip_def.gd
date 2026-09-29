class_name TipDef
extends Resource
## A tip: 1–3 cards shown, with time stopped, the first time `trigger` happens (TipDirector).
## Tips are content: adding one is a .tres in data/tips/ plus an entry in RunConfig.tips.

@export var id: StringName
## The event that shows it (TipDirector.EVENTS).
@export var trigger: StringName
## When true, the tip is seen once per event argument (e.g. once per new enemy type), and its
## cards may be built from that argument by the view.
@export var per_arg: bool = false
## Higher shows first when several tips are waiting.
@export var priority: int = 0
@export var cards: Array[TipCard] = []
