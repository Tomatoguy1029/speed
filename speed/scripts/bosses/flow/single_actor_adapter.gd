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
	if not _start_attack(StringName(id)): return null
	var ticket := Ticket.new()
	ticket.owner = weakref(actor)
	return ticket

func candidates(query: Dictionary) -> Dictionary:
	var result: Array = []
	var evaluated: Array = []
	var observe: bool = actor.combat_trace.enabled(2)
	for move in actor.action_rules.techniques:
		var id := String(move.technique)
		var kind := String(move.category)
		var accepted := false
		var reasons: Array = []
		for gate in actor.action_rules.active_gates_for(id):
			var reason := ""
			if actor.has_method("technique_rejection"): reason = actor.technique_rejection(move.technique, gate)
			elif not actor.technique_ready(move.technique, gate): reason = "not_ready"
			if reason.is_empty():
				accepted = true
				break
			if observe and reasons.size() < 16: reasons.append(reason)
		if accepted: result.append({"id": id, "cost": actor.action_rules.costs.get(id, 1.0), "category": kind, "parts": [actor.body_id], "exclusive": true})
		if observe and evaluated.size() < 128:
			evaluated.append({"id": id, "category": kind, "cost": actor.action_rules.costs.get(id, 1.0), "eligible": accepted, "reasons": [] if accepted else reasons if not reasons.is_empty() else ["no_active_gate"]})
	for id in actor.action_rules.combos:
		var reason := ""
		if not actor.can_begin_sequence(): reason = "sequence_not_ready"
		elif not actor.action_rules.active_gates_for(String(id)).any(step_condition): reason = "combo_gate"
		elif not _available(actor.action_rules.combos[id]): reason = "combo_first_step_unavailable"
		if reason.is_empty(): result.append({"id": String(id), "cost": actor.action_rules.costs.get(id, 2.0), "category": "combo", "parts": [actor.body_id], "exclusive": true, "program": actor.action_rules.combos[id]})
		if observe and evaluated.size() < 128: evaluated.append({"id": String(id), "category": "combo", "cost": actor.action_rules.costs.get(id, 2.0), "eligible": reason.is_empty(), "reasons": [] if reason.is_empty() else [reason]})
	return {"candidates": result, "evaluated": evaluated, "reason": "距離・方向・形態・再使用待ち"}

func selection_bias() -> Dictionary:
	return actor.action_rules.selection_bias

func record_decision(query: Dictionary, result: Dictionary, section: Dictionary, history: Array, selected: Array, selection: Dictionary, reason: String) -> void:
	if not actor.combat_trace.enabled(2): return
	var evaluated: Array = result.get("evaluated", [])
	var cap := minf(float(section.get("cap", INF)), float(query.stamina_max))
	var remaining_budget := maxf(0.0, float(section.get("section_budget", INF)) - float(query.section_spent))
	for item in evaluated:
		if not item.eligible: continue
		var rejection := ""
		if (query.request == "major" and item.category != "major") or (query.request == "normal" and item.category == "major"): rejection = "request_category"
		elif section.has("allowed_techniques") and String(item.id) not in section.allowed_techniques: rejection = "section_not_allowed"
		elif float(item.cost) < 0.0 or float(item.cost) > cap: rejection = "section_cap"
		elif float(item.cost) > remaining_budget: rejection = "section_budget"
		elif float(item.cost) > float(query.stamina): rejection = "stamina"
		if not rejection.is_empty():
			item.eligible = false
			item.reasons = [rejection]
	actor.combat_trace.context() # synchronize a newly started recording before assigning the decision
	actor.combat_trace.decision_id = actor.ctx.bosses.diagnostics.next_id()
	actor.combat_trace.event("boss_decision", {"origin": "natural_ai", "action_id": null, "action": "", "section": query.section, "request": query.request,
		"stamina": query.stamina, "cap": cap, "candidates": evaluated, "selection": selection.duplicate(true),
		"history": history.map(func(a): return String(a.id)), "selected": selected.map(func(a): return String(a.id)), "reason": reason}, 2)

func _start_attack(id: StringName) -> bool:
	var previous: String = actor.combat_origin
	actor.combat_origin = "natural_ai"
	var started: bool = actor.start_attack(id)
	actor.combat_origin = previous
	return started

func start(actions: Array) -> bool:
	if blocked() or actions.size() != 1: return false
	var id := String(actions[0].id)
	if actions[0].has("program"):
		if not _available(actions[0].program): return false
		custom_run = preload("res://scripts/bosses/flow/combo_runner.gd").new(actions[0].program, self)
		return true
	if not actor.action_rules.active_gates_for(id).any(func(gate): return actor.technique_ready(StringName(id), gate)): return false
	return _start_attack(StringName(id))

func observing_decisions() -> bool:
	return actor.combat_trace.enabled(2)
