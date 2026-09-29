class_name SkillDef
extends Resource
## One node of the skill tree (docs/2026-09-27-sectors-and-skill-tree/), bought once with stars
## between runs. Like a card, its whole effect is adding `value` to the RunModifiers field `key`
## at the start of every run, so a new node is a .tres plus at most one modifier field.
## A node needs the node one tier above it in its branch (SkillTree.can_buy).

@export var id: StringName
@export var title: String = ""
@export var description: String = ""
## Index into SkillTreeDef.branch_titles.
@export var branch: int = 0
## 1 = the top of the branch; tier n needs tier n - 1 of the same branch.
@export var tier: int = 1
## Price in stars.
@export var cost: int = 1
@export var key: StringName
@export var value: float = 0.0
