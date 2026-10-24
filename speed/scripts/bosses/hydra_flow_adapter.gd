extends RefCounted
var actor: Node
var active: Array = []
var custom_run: RefCounted

class StepTicket:
	extends RefCounted
	var owner: WeakRef
	var actions: Array
	func running() -> bool:
		var host = owner.get_ref()
		return host != null and host._running_actions(actions)
	func cancel() -> void:
		var host = owner.get_ref()
		if host != null: host._cancel_actions(actions)
	func failed() -> bool:
		var host = owner.get_ref()
		if host == null: return true
		for action in actions:
			if action.category == "single" and action.heads.any(func(n): return not host.actor._alive(n)): return true
			if action.category != "single" and not host.actor.busy and host.actor.last_tech_result == &"interrupted": return true
		return false

func _init(value: Node) -> void: actor = value

func tick(dt: float) -> void:
	if custom_run != null:
		if blocked():
			custom_run.cancel()
			custom_run = null
		else:
			var result: StringName = custom_run.tick(dt)
			if result == &"failed": custom_run.cancel()
			if result != &"running": custom_run = null

func start_step(id: String) -> Object:
	var options: Array = candidates({"request": "any", "children_only": true}).candidates.filter(func(c): return c.id == id)
	if not active.is_empty() and active[0].has("program"):
		var reserved: Array = active[0].parts
		options = options.filter(func(c): return c.parts.all(func(part): return part in reserved))
	if options.is_empty(): return null
	var previous := active
	var chosen := [options[0]]
	var ok := start(chosen)
	active = previous
	if not ok: return null
	var ticket := StepTicket.new()
	ticket.owner = weakref(self)
	ticket.actions = chosen
	return ticket

func step_condition(gate: Dictionary) -> bool:
	var relative: Vector2 = (actor.run_state.ship_pos - actor.table.pos[actor.body]).rotated(-actor.table.facing[actor.body])
	return preload("res://scripts/bosses/flow/range_condition.gd").allows(gate, relative)

func blocked() -> bool:
	return not actor.has_body() or actor.growth_t > 0.0 or actor.separation_pending or actor.separation_t > 0.0 or actor.chance_t > 0.0 or actor.final_strike_t >= 0.0

func candidates(query: Dictionary) -> Dictionary:
	var result: Array = []
	if blocked(): return {"candidates": result, "reason": "状態移行中"}
	for id in actor._moves:
		if not query.get("children_only", false) and actor.action_rules != null and actor.action_rules.combos.has(String(id)): continue
		var move: Resource = actor._moves[id]
		if move.head_kind != &"":
			if query.get("request", "normal") == "major": continue
			for i in actor.necks.size():
				if actor.normal_ready(i, id): result.append(_candidate(id, [actor.necks[i]], "single"))
		else:
			if query.get("request", "normal") == "normal" and id not in actor.COMBOS: continue
			if query.get("request", "normal") == "major" and id in actor.COMBOS: continue
			if not actor.attack_ready(id): continue
			var heads: Array = []
			if id in [&"north", &"sequence"]: heads = actor.front_heads()
			elif id in actor.COMBOS:
				var kinds: Array = {&"tornado": [&"vortex", &"debris"], &"debris_shatter": [&"debris", &"beam"], &"beam_pincer": [&"beam", &"beam"]}[id]
				for first in actor.necks:
					if not actor._alive(first) or first.mode != &"idle" or first.kind != kinds[0]: continue
					for second in actor.necks:
						if second == first or not actor._alive(second) or second.mode != &"idle" or second.kind != kinds[1]: continue
						if kinds[0] == kinds[1] and first.row_id > second.row_id: continue
						result.append(_candidate(id, [first, second], "combo"))
				continue
			else: heads = actor.necks.filter(func(n): return actor._alive(n))
			if not heads.is_empty(): result.append(_candidate(id, heads, "combo" if id in actor.COMBOS else "major"))
	if not query.get("children_only", false) and query.get("request", "normal") != "major" and actor.action_rules != null and not actor.busy and actor.recovery_t <= 0.0:
		for id in actor.action_rules.combos:
			if not step_condition(actor.action_rules.conditions.get(id, {})): continue
			var needs: Dictionary = _requirements(actor.action_rules.combos[id])
			var heads: Array = []
			var possible := true
			for kind in needs:
				var available: Array = actor.necks.filter(func(n): return actor._alive(n) and n.kind == kind and n.mode == &"idle")
				if available.size() < needs[kind]: possible = false
				heads.append_array(available.slice(0, mini(needs[kind], available.size())))
			if possible:
				heads = actor.necks.filter(func(n): return actor._alive(n) and n.mode == &"idle")
				var parts: Array = []
				for head in heads: parts.append(head.row_id)
				result.append({"id": id, "heads": heads, "parts": parts, "category": "combo", "exclusive": true, "cost": float(actor.action_rules.costs.get(id, 2.0)), "program": actor.action_rules.combos[id]})
	return {"candidates": result, "reason": "距離・部位・再使用待ち"}

func _requirements(node: Dictionary) -> Dictionary:
	var result := {}
	if node.get("type", "") == "branch" and node.get("children", []).size() == 2:
		return _requirements(node.children[0 if step_condition(node.get("condition", {})) else 1])
	if node.get("type", "") == "action":
		var move: Resource = actor._moves.get(StringName(node.get("id", "")))
		if move == null: return {&"missing": 999}
		if move.head_kind != &"": return {move.head_kind: 1}
		# 本体・配置を使う既存技は全生存部位を候補に確保する。
		for n in actor.necks:
			if actor._alive(n): result[n.kind] = int(result.get(n.kind, 0)) + 1
		return result
	for child in node.get("children", []):
		var needs := _requirements(child)
		for kind in needs:
			result[kind] = int(result.get(kind, 0)) + int(needs[kind]) if node.get("type", "") == "parallel" else maxi(int(result.get(kind, 0)), int(needs[kind]))
	return result

func _candidate(id: StringName, heads: Array, kind: String) -> Dictionary:
	var parts: Array = []
	for head in heads: parts.append(head.row_id)
	var params: Dictionary = actor.move_params(id)
	var cost := float(params.get("stamina", params.get("cost", params.get("major_cost", 2.0))))
	if actor.action_rules != null: cost = float(actor.action_rules.costs.get(String(id), cost))
	return {"id": String(id), "heads": heads, "parts": parts, "category": kind, "exclusive": kind != "single", "cost": cost}

func start(actions: Array) -> bool:
	# 同一更新内で全体を検証し、候補の具体的個体を固定する。
	if blocked() or actions.is_empty(): return false
	for action in actions:
		if not action.has("heads") or action.parts.size() != action.heads.size(): return false
		for i in action.heads.size():
			var head = action.heads[i]
			if not actor._alive(head) or head.row_id != action.parts[i]: return false
		if action.has("program"): continue
		if action.category == "single":
			if not actor.normal_ready(actor.necks.find(action.heads[0]), StringName(action.id)): return false
		elif not actor.attack_ready(StringName(action.id)): return false
	var started: Array = []
	for action in actions:
		var ok: bool
		if action.has("program"):
			custom_run = preload("res://scripts/bosses/flow/combo_runner.gd").new(action.program, self)
			ok = true
		elif action.category == "single": ok = actor.start_normal(actor.necks.find(action.heads[0]), StringName(action.id))
		else: ok = actor.try_start_tech(StringName(action.id), 1.0, action.heads)
		if not ok:
			_cancel_actions(started + [action])
			return false
		started.append(action)
	active = started
	return true

func running() -> bool:
	return custom_run != null or _running_actions(active)

func _running_actions(actions: Array) -> bool:
	for action in actions:
		if action.has("program"): continue
		if action.category != "single":
			if actor.busy or actor.recovery_t > 0.0: return true
		else:
			var head = action.heads[0]
			if actor._alive(head) and (head.mode != &"idle" or head.cd > 0.0): return true
	return false

func _cancel_actions(actions: Array) -> void:
	for action in actions:
		if action.category == "single":
			if actor.ctx.projectiles.director != null: actor.ctx.projectiles.director.cancel_attack("neck:" + str(action.heads[0].row_id), action.heads[0].row_id)
			actor._release_attack(action.heads[0])
			actor._end(action.heads[0], true)
		else: actor.interrupt_tech(StringName(action.id))

func cancel_all() -> void:
	if custom_run != null:
		custom_run.cancel()
		custom_run = null
	_cancel_actions(active.filter(func(a): return not a.has("program")))
	active.clear()
