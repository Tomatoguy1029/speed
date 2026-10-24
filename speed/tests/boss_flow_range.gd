extends SceneTree
func _initialize() -> void:
	var condition = load("res://scripts/bosses/flow/range_condition.gd")
	if condition == null:
		quit(1)
		return
	var gate := {"min": 100.0, "max": 300.0, "angle": 0.0, "half_angle": 45.0}
	assert(condition.allows(gate, Vector2(200, 0)))
	assert(not condition.allows(gate, Vector2(50, 0)))
	assert(not condition.allows(gate, Vector2(200, 250)))
	gate.angle = 180.0
	assert(condition.allows(gate, Vector2(-200, 0)))
	var preview = load("res://addons/boss_flow/range_preview.gd")
	if not preview.has_method("analyze"):
		print("[boss-range] FAIL coverage analysis missing")
		quit(1)
		return
	var analysis: Dictionary = preview.analyze([{ "min": 0.0, "max": 300.0, "half_angle": 180.0}], 300.0)
	assert(analysis.holes == 0)
	analysis = preview.analyze([{ "min": 100.0, "max": 300.0, "half_angle": 20.0}], 300.0)
	assert(analysis.holes > 0)
	print("[boss-range] PASS distance, sector and angle wrap")
	quit()
