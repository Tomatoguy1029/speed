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
	print("[boss-select] PASS weighted category, history row, unavailable redistribution")
	quit()
