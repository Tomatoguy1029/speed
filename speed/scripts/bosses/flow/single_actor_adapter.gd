## 一体のボスの候補・開始・完了を共通フローへ接続する。
extends RefCounted
var actor
var custom_run: RefCounted

class Ticket:
	extends RefCounted
	var owner: WeakRef
	func running() -> bool:
		var host = owner.get_ref()
		return host != null and host.attack_playing()
	func failed() -> bool:
		var host = owner.get_ref()
		return host == null or host.attack_failed()
	func cancel() -> void:
		var host = owner.get_ref()
		if host != null: host.cancel_attack()

func _init(value: BossActor) -> void:
	actor = value

func blocked() -> bool:
	return actor.selection_blocked()

func running() -> bool:
	return custom_run != null or actor.attack_playing()

func tick(dt: float) -> void:
	if custom_run == null: return
	if blocked():
		cancel()
		return
	var result: StringName = custom_run.tick(dt)
	if result != &"running":
		if result == &"failed": custom_run.cancel()
		custom_run = null

func cancel() -> void:
	if custom_run != null: custom_run.cancel()
	custom_run = null

func step_condition(gate: Dictionary) -> bool:
	return preload("res://scripts/bosses/flow/range_condition.gd").allows(gate, (actor.run_state.enemy_aim - actor.table.pos[actor.body]).rotated(-actor.table.facing[actor.body]))

func _available(step: Dictionary) -> bool:
	var children: Array = step.get("children", [])
	match step.get("type", ""):
		"action": return actor.technique_ready(StringName(step.id), actor.action_rules.conditions.get(String(step.id), {}))
		"wait": return true
		"sequence": return not children.is_empty() and _available(children[0])
		"parallel": return not children.is_empty() and children.all(_available)
		"branch": return children.size() == 2 and _available(children[0 if step_condition(step.get("condition", {})) else 1])
	return false

func start_step(id: String) -> Object:
	if not actor.technique_ready(StringName(id), actor.action_rules.conditions.get(id, {})): return null
	if not actor.start_attack(StringName(id)): return null
	var ticket := Ticket.new()
	ticket.owner = weakref(actor)
	return ticket

func candidates(query: Dictionary) -> Dictionary:
	var result: Array = []
	for move in actor.action_rules.techniques:
		var id := String(move.technique)
		var kind := String(move.category)
		if query.get("request", "normal") == "major" and kind != "major": continue
		if query.get("request", "normal") == "normal" and kind == "major": continue
		for gate in actor.action_rules.active_gates_for(id):
			if actor.technique_ready(move.technique, gate):
				result.append({"id": id, "cost": actor.action_rules.costs.get(id, 1.0), "category": kind, "parts": [actor.body_id], "exclusive": true})
				break
	if query.get("request", "normal") != "major" and actor.can_begin_sequence():
		for id in actor.action_rules.combos:
			if not actor.action_rules.active_gates_for(String(id)).any(step_condition) or not _available(actor.action_rules.combos[id]): continue
			result.append({"id": String(id), "cost": actor.action_rules.costs.get(id, 2.0), "category": "combo", "parts": [actor.body_id], "exclusive": true, "program": actor.action_rules.combos[id]})
	return {"candidates": result, "reason": "距離・方向・形態・再使用待ち"}

func start(actions: Array) -> bool:
	if blocked() or actions.size() != 1: return false
	var id := String(actions[0].id)
	if actions[0].has("program"):
		if not _available(actions[0].program): return false
		custom_run = preload("res://scripts/bosses/flow/combo_runner.gd").new(actions[0].program, self)
		return true
	if not actor.action_rules.active_gates_for(id).any(func(gate): return actor.technique_ready(StringName(id), gate)): return false
	return actor.start_attack(StringName(id))
