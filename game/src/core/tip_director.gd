class_name TipDirector
extends RefCounted
## Decides which tip to show next, and never the same one twice. Pure logic: the view reports
## events (notify), shows pending(), and calls done() when the player has read it. Nothing here
## knows about nodes, time or input, so the queue is unit tested and a headless run never
## blocks on it (docs/2026-09-27-style-and-tutorials/).

## Events a tip can be triggered by. The run and campaign views emit these.
const EVENTS: Array[StringName] = [
	&"run_started", &"unit_built", &"crate_spawned", &"boost_crate", &"gate_struck",
	&"gate_damaged", &"card_offer", &"can_upgrade", &"mastery_ready", &"unit_jammed",
	&"unit_destroyed", &"new_enemy", &"new_portal", &"locked_pad", &"high_ground",
	&"barricade_ready", &"campaign_open", &"stars_to_spend", &"ability_ready", &"synergy_formed",
	&"ability_picked",
]
## Events that end a "do" card (TipCard.wait_for).
const WAIT_EVENTS: Array[StringName] = [&"plot_opened"]
## What a card can spotlight. The views resolve each to a rectangle on screen.
const FOCUSES: Array[StringName] = [
	&"", &"empty_pad", &"built_unit", &"crate", &"gate", &"gate_hp", &"start_wave",
	&"repair_gate", &"card_offer", &"jammed_unit", &"lost_pad", &"portal", &"locked_pad",
	&"high_ground", &"barricade_slot", &"coins", &"sector_play", &"skill_tree", &"ability_button",
]

## A tip waiting to be shown: its def and the event argument that triggered it.
class Pending:
	var def: TipDef
	var arg: StringName

	func _init(d: TipDef, a: StringName) -> void:
		def = d
		arg = a

	## The id recorded as seen: the tip's id, plus the argument for per-argument tips.
	func key() -> String:
		return String(def.id) + (":" + String(arg) if def.per_arg else "")


var tips: Array[TipDef] = []
## Seen tip keys (Pending.key). Shared with the save, so marking one seen persists with it.
var seen: Dictionary = {}
## When false, notify() queues nothing (tips off, autoplay, tests).
var enabled: bool = true
var _queue: Array[Pending] = []


func _init(tip_defs: Array[TipDef] = [], seen_keys: Dictionary = {}) -> void:
	tips = tip_defs
	seen = seen_keys


## Report that `event` happened (with `arg`, e.g. an enemy id). Queues every unseen tip it
## triggers, highest priority first; a tip already waiting is not queued twice.
func notify(event: StringName, arg: StringName = &"") -> void:
	if not enabled:
		return
	for t: TipDef in tips:
		if t.trigger != event:
			continue
		var p := Pending.new(t, arg)
		if seen.has(p.key()) or _is_queued(p.key()):
			continue
		var at: int = _queue.size()
		for i: int in _queue.size():
			if t.priority > _queue[i].def.priority:
				at = i
				break
		_queue.insert(at, p)


## The tip to show now, or null.
func pending() -> Pending:
	return _queue[0] if not _queue.is_empty() else null


## The player finished `p`: it is seen and leaves the queue.
func done(p: Pending) -> void:
	seen[p.key()] = true
	_queue.erase(p)


## Forget what was waiting (a new run starts).
func clear_queue() -> void:
	_queue.clear()


func has_seen(key: String) -> bool:
	return seen.has(key)


func _is_queued(key: String) -> bool:
	for p: Pending in _queue:
		if p.key() == key:
			return true
	return false
