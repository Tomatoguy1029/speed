extends SceneTree
func _initialize() -> void:
	var script = load("res://scripts/bosses/flow/selector.gd")
	if script == null:
		quit(1)
		return
	var selector = script.new()
	var a := {"id": "a", "category": "single", "cost": 1.0, "parts": [1]}
	var c := {"id": "c", "category": "combo", "cost": 2.0, "parts": [1, 2]}
	var section := {"weights": {"single": 100.0, "combo": 0.0}, "probability_rules": [{"previous": "single", "weights": {"single": 0.0, "combo": 100.0}}]}
	assert(selector.choose([a, c], section, []).front().id == "a")
	assert(selector.choose([a, c], section, [a]).front().id == "c")
	assert(selector.choose([a], {"weights": {"single": 1.0, "combo": 99.0}}, []).front().id == "a")
	var b := {"id": "b", "category": "single", "cost": 1.0, "parts": [2]}
	var together := {"weights": {"parallel": 100.0}, "cap": 2.0}
	if selector.choose([a, b], together, []).size() != 2:
		print("[boss-select] FAIL parallel choice missing")
		quit(1)
		return
	assert(selector.choose([a, b], together, [], [["a", "b"]]).is_empty())
	b.parts = [1]
	assert(selector.choose([a, b], together, []).is_empty())
	b.parts = [2]
	var avoid := {"weights": {"single": 100.0}, "avoid_repeat": true}
	selector.random.seed = 0
	if selector.choose([a, b], avoid, [a]).front().id != "b":
		print("[boss-select] FAIL repeat avoidance missing")
		quit(1)
		return
	assert(selector.choose([a], avoid, [a]).front().id == "a")
	assert(not selector.choose([a, b], avoid, [a, b]).is_empty())
	selector.random.seed = 17
	var biased := {"weights": {"single": 100.0}, "technique_weights": {"a": 20.0, "b": 1.0}, "avoid_repeat": false}
	var a_count := 0
	for _draw in 200:
		if selector.choose([a, b], biased, []).front().id == "a": a_count += 1
	assert(a_count > 170 and a_count < 200, "policy bias prefers but does not veto the other eligible technique")
	assert(selector.choose([b], biased, []).front().id == "b", "bias does not exclude the remaining eligible choice")
	print("[boss-select] PASS category, history, redistribution and nonexclusive technique bias")
	quit()
