class_name SkillTree
extends RefCounted
## The player's owned skill-tree nodes (permanent, kept in SaveData). Stars are never stored as
## a balance: what's left to spend is the stars earned (Campaign.stars_total) minus spent(), so
## a free reset is just forgetting the owned set and nothing can drift out of sync.
##
## Ids no longer in the tree (content removed later) are kept but ignored: they cost nothing
## and give nothing.

var owned: Dictionary[StringName, bool] = {}


func has(skill_id: StringName) -> bool:
	return owned.has(skill_id)


## Stars tied up in owned nodes that still exist in `tree`.
func spent(tree: SkillTreeDef) -> int:
	var n: int = 0
	for s: SkillDef in tree.skills:
		if owned.has(s.id):
			n += s.cost
	return n


## True if `skill` is the next node of its branch: tier 1, or the tier above it owned.
func is_reachable(tree: SkillTreeDef, skill: SkillDef) -> bool:
	if skill.tier <= 1:
		return true
	var above: SkillDef = tree.at(skill.branch, skill.tier - 1)
	return above != null and owned.has(above.id)


## True if `skill` can be bought with `stars` earned in total.
func can_buy(tree: SkillTreeDef, skill: SkillDef, stars: int) -> bool:
	return not owned.has(skill.id) and is_reachable(tree, skill) \
			and stars - spent(tree) >= skill.cost


func buy(tree: SkillTreeDef, skill: SkillDef, stars: int) -> bool:
	if not can_buy(tree, skill, stars):
		return false
	owned[skill.id] = true
	return true


## The free respec: every star comes back.
func reset() -> void:
	owned.clear()


## The starting modifiers of a run, from the owned nodes.
func to_modifiers(tree: SkillTreeDef) -> RunModifiers:
	var mods := RunModifiers.new()
	if tree == null:
		return mods
	for s: SkillDef in tree.skills:
		if owned.has(s.id):
			mods.add(s.key, s.value)
	return mods
