class_name CardDef
extends Resource
## A run upgrade offered in the CARD phase. Picking it adds `value` to the RunModifiers field
## named `key`; the content test fails if `key` is not a RunModifiers field.

@export var id: StringName
@export var title: String = ""
@export var description: String = ""
@export var key: StringName
@export var value: float = 0.0
## Relative draw weight; 0 = never offered.
@export var weight: float = 1.0
## How many times one run may take it.
@export var max_stacks: int = 1
