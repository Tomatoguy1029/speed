## 図の移動・条件線・複数コピーを、一つの履歴で安全に復元する。
extends SceneTree
func _initialize() -> void: call_deferred("exercise")
func exercise() -> void:
 root.size = Vector2i(1200, 800)
 var panel = load("res://addons/boss_flow/editor.gd").new()
 panel.theme = ThemeDB.get_default_theme()
 root.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 await process_frame
 var graph = panel.graph
 var initial: int = panel.rules.node_ids().size()
 graph._select_nodes(["bite_thrust", "wind_band"])
 graph.command("copy")
 graph.command("paste")
 await process_frame
 assert(panel.rules.node_ids().size() == initial + 2)
 assert(panel.rules.source_for("bite_thrust_copy_1") == "bite_thrust")
 assert(graph.is_node_connected("choose", 0, "bite_thrust_copy_1", 0))
 assert(panel.rules.conditions.bite_thrust_copy_1 == panel.rules.conditions.bite_thrust)
 panel.history.undo()
 assert(panel.rules.node_ids().size() == initial)
 panel.history.redo()
 await process_frame
 graph._connect("bite_thrust", false)
 assert(panel.rules.active_gates_for("bite_thrust").size() == 1)
 assert(not graph.is_node_connected("choose", 0, "bite_thrust", 0))
 panel.history.undo()
 assert(graph.is_node_connected("choose", 0, "bite_thrust", 0))
 graph._select_nodes(["bite_thrust_copy_1", "wind_band_copy_1"])
 graph.command("delete")
 assert(panel.rules.node_ids().size() == initial)
 panel.history.undo()
 assert(panel.rules.node_ids().size() == initial + 2)
 graph._select_nodes(["bite_thrust"])
 var before: Vector2 = graph.get_node("bite_thrust").position_offset
 graph._move_begin()
 graph.get_node("bite_thrust").position_offset += Vector2(100, 17)
 graph._move_end()
 assert(graph.get_node("bite_thrust").position_offset != before)
 graph.grab_focus()
 await process_frame
 var undo := InputEventKey.new()
 undo.keycode = KEY_Z
 undo.meta_pressed = true
 undo.pressed = true
 panel._input(undo)
 assert(graph.get_node("bite_thrust").position_offset == before)
 undo.shift_pressed = true
 panel._input(undo)
 assert(graph.get_node("bite_thrust").position_offset != before)
 panel._picked("condition", "bite_thrust_copy_1")
 var input: LineEdit
 for child in panel._fields.get_children():
  if child is SpinBox:
   input = child.get_line_edit()
   break
 input.grab_focus()
 await process_frame
 var version: int = panel.history.get_version()
 panel._input(undo)
 assert(panel.history.get_version() == version, "text editing must keep its own undo")
 panel._picked("condition", "bite_thrust")
 var old_max: float = panel.rules.conditions.bite_thrust.max
 var numbers: Array = panel._fields.get_children().filter(func(n): return n is SpinBox)
 numbers[1].value = old_max + 5.0
 var undo_button: Button
 for node in panel.find_children("*", "Button", true, false):
  if node.text == "元に戻す": undo_button = node
 undo_button.pressed.emit()
 numbers = panel._fields.get_children().filter(func(n): return n is SpinBox)
 assert(panel.rules.conditions.bite_thrust.max == old_max and numbers[1].value == old_max, "undo must refresh the displayed condition value as well as its data")
 var original_damage: float = panel.working["res://data/bosses/hydra_moves/bite_thrust.tres"].parameters.bite_dmg
 panel._picked("technique", "bite_thrust")
 panel.set_value("bite_dmg", original_damage + 1.0)
 panel.rebuild_ui()
 assert(panel.current.parameters.bite_dmg == original_damage + 1.0)
 panel.history.undo()
 assert(panel.current.parameters.bite_dmg == original_damage, "a UI rebuild must preserve user edits and undo history")
 panel.rules.combos.combo_clipboard = {"type": "sequence", "children": [{"type": "wait", "seconds": 1.0}]}
 panel.rules.costs.combo_clipboard = 2.0
 graph.show_rules(panel.rules)
 graph._select_nodes(["combo_clipboard"])
 graph.command("copy")
 panel.rules.combos.combo_clipboard.children[0].seconds = 3.0
 panel.rules.costs.combo_clipboard = 4.0
 graph.command("paste")
 assert(panel.rules.combos.combo_clipboard_copy_1.children[0].seconds == 1.0 and panel.rules.costs.combo_clipboard_copy_1 == 2.0, "pasting must preserve the combo and cost at the time of copying")
 panel.queue_free()
 await process_frame
 print("[boss-graph] PASS move/line/delete/copy groups, one-step undo and text-focus isolation")
 quit()
