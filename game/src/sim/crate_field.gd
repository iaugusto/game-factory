class_name CrateField
extends Node2D
## Loot crates on the field: pooled CrateViews bound to core CombatSim.Crates by id (only a
## few are ever alive, so nodes are fine). Views are released when the core breaks or loses a
## crate, or when a wave ends.

var views: Dictionary[int, CrateView] = {}
var _pool: Array[CrateView] = []


func bind(c: CombatSim.Crate) -> void:
	var v: CrateView = _pool.pop_back() if not _pool.is_empty() else null
	if v == null:
		v = CrateView.new()
		add_child(v)
	v.bind(c)
	views[c.id] = v


func release(id: int) -> void:
	if views.has(id):
		var v: CrateView = views[id]
		views.erase(id)
		v.unbind()
		_pool.append(v)


func clear() -> void:
	for id: int in views.keys():
		release(id)


func pooled_count() -> int:
	return get_child_count()


func sync(delta: float) -> void:
	for v: CrateView in views.values():
		v.sync(delta)
