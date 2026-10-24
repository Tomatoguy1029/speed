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
	quit(1 if failed else 0)
