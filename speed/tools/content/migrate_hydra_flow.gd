extends SceneTree
var rules := preload("res://scripts/data_types/boss_action_rules.gd").new()

func collect(task: BTTask, gates: Array = []) -> void:
	var branch := gates.duplicate()
	if task is BTSequence:
		for i in task.get_child_count():
			var item := task.get_child(i)
			if item.has_method("allows"): branch.append(item)
	if task.has_method("get_hydra_settings"):
		var move: Resource = task.get_hydra_settings()
		if move != null:
			rules.techniques.append(move)
			var gate := {"min": 0.0, "max": 100000.0, "angle": 0.0, "half_angle": 180.0, "distance_origin": 0, "angle_origin": 0}
			for condition in branch:
				if condition.get("minimum_distance") != null:
					gate.min = condition.minimum_distance
					gate.max = condition.maximum_distance
					gate.distance_origin = condition.origin
				elif condition.get("half_angle_degrees") != null:
					gate.angle = condition.center_degrees
					gate.half_angle = condition.half_angle_degrees
					gate.angle_origin = condition.origin
					gate.ignore_when_separated = condition.ignore_when_separated
			rules.conditions[String(move.technique)] = gate
			rules.costs[String(move.technique)] = 1.0 if move.head_kind != &"" else 2.0 if String(move.technique) in ["tornado", "debris_shatter", "beam_pincer"] else 3.0
	for i in task.get_child_count(): collect(task.get_child(i), branch)

func _initialize() -> void:
	if ResourceLoader.exists("res://data/bosses/hydra_action_rules.tres"):
		print("既存の編集元を保護するため移行を省略しました")
		quit()
		return
	collect(load("res://scenes/bosses/hydra_head_bt.tres").root_task)
	collect(load("res://scenes/bosses/hydra_boss_bt.tres").root_task)
	var error := ResourceSaver.save(rules, "res://data/bosses/hydra_action_rules.tres")
	if error != OK:
		quit(1)
		return
	var flow := preload("res://scripts/data_types/boss_flow_def.gd").new()
	flow.maximum_stamina = 8.0
	flow.sections = [
		{"name": "牽制", "request": "normal", "cap": 2.0, "weights": {"single": 60.0, "parallel": 25.0, "combo": 15.0}, "next": 1},
		{"name": "圧力", "request": "normal", "cap": 3.0, "weights": {"single": 35.0, "parallel": 45.0, "combo": 20.0}, "next": 2},
		{"name": "大技候補", "request": "major", "cap": 3.0, "weights": {"major": 100.0}, "next": 0, "fallback": 0}]
	error = ResourceSaver.save(flow, "res://data/bosses/hydra_flow.tres")
	print("ヒュドラ移行: ", rules.techniques.size(), "技 / ", error_string(error))
	quit(0 if error == OK else 1)
