extends SceneTree
func _initialize() -> void:
	if not ResourceLoader.exists("res://data/bosses/hydra_action_rules.tres"):
		print("[boss-migration] FAIL migrated rules missing")
		quit(1)
		return
	var rules = load("res://data/bosses/hydra_action_rules.tres")
	assert(rules.techniques.size() == 18)
	assert(rules.conditions.size() == 18)
	assert(rules.conditions.bite_thrust.max == 620.0)
	assert(rules.conditions.wind_blades.min == 260.0)
	assert(rules.costs.north == 3.0 and rules.costs.bite_thrust == 1.0)
	print("[boss-migration] PASS all 18 techniques, conditions and new stamina costs")
	quit()
