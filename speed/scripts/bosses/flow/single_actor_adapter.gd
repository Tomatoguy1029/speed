## 一体のボスの候補・開始・完了を共通フローへ接続する。
extends RefCounted
var actor

func _init(value: BossActor) -> void:
	actor = value

func blocked() -> bool:
	return not actor.body_alive() or not actor.selection_enabled or actor.mode in [&"phase", &"final", &"defeated"]

func running() -> bool:
	return actor.attack_playing()

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
	return {"candidates": result, "reason": "距離・方向・形態・再使用待ち"}

func start(actions: Array) -> bool:
	if blocked() or actions.size() != 1: return false
	var id := String(actions[0].id)
	if not actor.action_rules.active_gates_for(id).any(func(gate): return actor.technique_ready(StringName(id), gate)): return false
	return actor.start_attack(StringName(id))
