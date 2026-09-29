class_name SkillTreeDef
extends Resource
## The skill tree between sectors: its branches (columns) and nodes. content_test.gd checks
## every branch has tiers 1..n without gaps and every key is a RunModifiers field.

@export var branch_titles: PackedStringArray = PackedStringArray()
@export var skills: Array[SkillDef] = []


func skill_by_id(skill_id: StringName) -> SkillDef:
	for s: SkillDef in skills:
		if s.id == skill_id:
			return s
	return null


## The node at `tier` of `branch`, or null.
func at(branch: int, tier: int) -> SkillDef:
	for s: SkillDef in skills:
		if s.branch == branch and s.tier == tier:
			return s
	return null


## The nodes of `branch`, top tier first.
func branch_skills(branch: int) -> Array[SkillDef]:
	var out: Array[SkillDef] = []
	for s: SkillDef in skills:
		if s.branch == branch:
			out.append(s)
	out.sort_custom(func(a: SkillDef, b: SkillDef) -> bool: return a.tier < b.tier)
	return out


## Stars to own every node.
func total_cost() -> int:
	var n: int = 0
	for s: SkillDef in skills:
		n += s.cost
	return n
