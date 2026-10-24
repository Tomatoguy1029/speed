extends SceneTree
var failed := 0
func check(ok: bool, label: String) -> void:
	print("[boss-compile] ", "PASS " if ok else "FAIL ", label)
	if not ok: failed += 1
func _initialize() -> void:
	var compiler = load("res://tools/content/build_boss_program.gd")
	check(compiler != null, "compiler available")
	if compiler == null:
		quit(1)
		return
	var source := {"techniques": [load("res://data/bosses/hydra_moves/bite_thrust.tres")], "layout": {"a": Vector2(0, 0)}}
	if FileAccess.file_exists("res://.content/tests/compiled_boss.tres"): DirAccess.remove_absolute("res://.content/tests/compiled_boss.tres")
	var result = compiler.compile(source, "res://.content/tests/compiled_boss.tres")
	check(result.error == OK and result.generated, "generate runtime program")
	source.layout.a = Vector2(900, 200)
	result = compiler.compile(source, "res://.content/tests/compiled_boss.tres")
	check(result.error == OK and not result.generated, "layout change reuses runtime data")
	check(result.program.data.techniques[0].parameters.bite_dmg == 16.0, "compiled values preserved")
	source.techniques[0] = source.techniques[0].duplicate(true)
	var compiled = compiler.compile(source, "res://.content/tests/embedded_boss.tres")
	source.techniques[0].parameters.bite_dmg = 999.0
	check(compiled.program.data.techniques[0].parameters.bite_dmg == 16.0, "runtime values are independent of editor resources")
	var rules = load("res://data/bosses/ai/hydra_action_rules.tres").duplicate(true)
	var signature: Variant = compiler.canonical({"rules": rules})
	rules.condition_groups = {"custom": {"title": "表示用の条件選択", "nodes": ["bite_thrust"]}}
	check(compiler.canonical({"rules": rules}) == signature, "editor-only condition groups leave the runtime signature unchanged")
	check(compiler.snapshot({"rules": rules}).rules.condition_groups.is_empty(), "condition group editing data stays out of the runtime payload")
	rules.conditions.bite_thrust.min = 900.0
	rules.conditions.bite_thrust.max = 100.0
	var invalid = compiler.compile({"rules": rules}, "res://.content/tests/invalid_boss.tres")
	check(invalid.error != OK, "invalid distance interval is rejected before writing")
	rules.conditions.bite_thrust = {"half_angle": -1.0}
	check(not compiler.validate({"rules": rules}).is_empty(), "negative sector angles are rejected")
	quit(1 if failed else 0)
