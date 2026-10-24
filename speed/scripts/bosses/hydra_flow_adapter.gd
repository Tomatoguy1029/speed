extends RefCounted
var actor: Node
var active: Array = []
func _init(value: Node) -> void: actor = value

func blocked() -> bool:
	return not actor.has_body() or actor.growth_t > 0.0 or actor.separation_pending or actor.separation_t > 0.0 or actor.chance_t > 0.0 or actor.final_strike_t >= 0.0

func candidates(query: Dictionary) -> Dictionary:
	var result: Array = []
	if blocked(): return {"candidates": result, "reason": "状態移行中"}
	for id in actor._moves:
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
				heads = actor.combo_heads({&"tornado": [&"vortex", &"debris"], &"debris_shatter": [&"debris", &"beam"], &"beam_pincer": [&"beam", &"beam"]}[id])
			else: heads = actor.necks.filter(func(n): return actor._alive(n))
			if not heads.is_empty(): result.append(_candidate(id, heads, "combo" if id in actor.COMBOS else "major"))
	return {"candidates": result, "reason": "距離・部位・再使用待ち"}

func _candidate(id: StringName, heads: Array, kind: String) -> Dictionary:
	var parts: Array = []
	for head in heads: parts.append(head.row_id)
	var params: Dictionary = actor.move_params(id)
	return {"id": String(id), "heads": heads, "parts": parts, "category": kind, "exclusive": kind != "single", "cost": float(params.get("stamina", params.get("cost", params.get("major_cost", 2.0))))}

func start(actions: Array) -> bool:
	# 同一更新内で全体を検証し、候補の具体的個体を固定する。
	if blocked() or actions.is_empty(): return false
	for action in actions:
		if not action.has("heads") or action.parts.size() != action.heads.size(): return false
		for i in action.heads.size():
			var head = action.heads[i]
			if not actor._alive(head) or head.row_id != action.parts[i]: return false
		if action.category == "single":
			if not actor.normal_ready(actor.necks.find(action.heads[0]), StringName(action.id)): return false
		elif not actor.attack_ready(StringName(action.id)): return false
	var started: Array = []
	for action in actions:
		var ok: bool
		if action.category == "single": ok = actor.start_normal(actor.necks.find(action.heads[0]), StringName(action.id))
		else: ok = actor.try_start_tech(StringName(action.id), 1.0, action.heads)
		if not ok:
			for previous in started:
				if previous.category == "single":
					actor._release_attack(previous.heads[0])
					actor._end(previous.heads[0], true)
				else: actor.interrupt_tech(StringName(previous.id))
			return false
		started.append(action)
	active = started
	return true

func running() -> bool:
	for action in active:
		if action.category != "single":
			if actor.busy or actor.recovery_t > 0.0: return true
		else:
			var head = action.heads[0]
			if actor._alive(head) and (head.mode != &"idle" or head.cd > 0.0): return true
	return false
