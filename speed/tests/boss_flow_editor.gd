extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	print("[boss-flow-editor] ", "PASS " if ok else "FAIL ", message)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("exercise")

func exercise() -> void:
	var script = load("res://tools/editor/boss_flow/editor.gd")
	check(script != null, "editor is available")
	if script == null:
		quit(1)
		return
	var panel = script.new()
	root.add_child(panel)
	var original = load("res://data/bosses/hydra_moves/bite_thrust.tres")
	DirAccess.make_dir_recursive_absolute("res://.content/tests")
	var path := "res://.content/tests/boss_flow_editor_test.tres"
	ResourceSaver.save(original.duplicate(true), path)
	check(panel.open_technique(path) == OK, "open a separate editable resource")
	var before: float = panel.current.parameters.bite_dmg
	panel.set_value("bite_dmg", before + 7.0)
	check(panel.current.parameters.bite_dmg == before + 7.0, "edit changes working value")
	panel.history.undo()
	check(panel.current.parameters.bite_dmg == before, "undo restores value")
	panel.history.redo()
	check(panel.save_current() == OK, "explicit save succeeds")
	check(panel.open_technique(path) == OK and panel.current.parameters.bite_dmg == before + 7.0, "reload preserves saved value")
	check(original.parameters.bite_dmg == before, "source stays untouched")
	panel.graph.node_selected.emit(panel.graph.get_node("bite_thrust"))
	check(panel.source_path == "res://data/bosses/hydra_moves/bite_thrust.tres", "native graph node selection opens the technique")
	await process_frame
	var from = panel.graph.get_node("choose_normal")
	var to = panel.graph.get_node("bite_thrust")
	var origin: Vector2 = (from.position_offset + from.get_output_port_position(0)) * panel.graph.zoom
	var target: Vector2 = (to.position_offset + to.get_input_port_position(0)) * panel.graph.zoom
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var line: PackedVector2Array = panel.graph.get_connection_line(origin, target)
	click.position = line[-2].lerp(line[-1], 0.5) - panel.graph.scroll_offset
	panel.graph._input_graph(click)
	check(panel.editing_rules and panel.preview.gate == panel.rules.conditions.bite_thrust, "connection hit test selects its conditions")
	DirAccess.remove_absolute(path)
	panel.queue_free()
	await process_frame
	quit(1 if failures else 0)
