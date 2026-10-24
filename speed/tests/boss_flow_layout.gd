## 実際のメイン画面と同じContainer配下で、余白・拡縮と操作部品を確認する。
extends SceneTree
func _initialize() -> void: call_deferred("exercise")
func exercise() -> void:
 root.content_scale_size = Vector2i.ZERO
 var host := VBoxContainer.new()
 root.add_child(host)
 host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var panel = load("res://addons/boss_flow/editor.gd").new()
 panel.theme = ThemeDB.get_default_theme()
 host.add_child(panel)
 for dimension in [Vector2i(1200, 800), Vector2i(860, 620)]:
  root.size = dimension
  await process_frame
  await process_frame
  assert(panel.size.y >= host.size.y - 1.0, "main editor must expand vertically inside its Container")
  assert(panel.graph.size.y > host.size.y * 0.45, "the graph must use the available editor height")
  assert(panel.get_combined_minimum_size().x <= host.size.x, "controls must not force the editor outside its available width")
  panel._picked("condition", "bite_thrust")
  await process_frame
  assert(panel.preview.size.y <= 200.0 * panel._scale, "the condition preview must remain compact")
 assert(panel._settings is OptionButton and panel._techniques is OptionButton, "settings and techniques are selections, not rows of buttons")
 assert(panel.flow_bar is TabBar, "flow sections use a selection control")
 var original: float = panel.working["res://data/bosses/hydra_moves/bite_thrust.tres"].parameters.bite_dmg
 panel._picked("technique", "bite_thrust")
 panel.set_value("bite_dmg", original + 1.0)
 panel.rebuild_ui()
 assert(panel.current.parameters.bite_dmg == original + 1.0)
 panel.history.undo()
 assert(panel.current.parameters.bite_dmg == original)
 panel.queue_free()
 await process_frame
 var large = load("res://addons/boss_flow/editor.gd").new()
 large.theme = Theme.new()
 large.theme.default_font_size = 28
 root.size = Vector2i(1778, 1000)
 host.add_child(large)
 await process_frame
 await process_frame
 var occupied: Array[Rect2] = []
 for child in large.graph.get_children():
  if not child is GraphNode: continue
  var rect := Rect2(child.position_offset, child.get_combined_minimum_size())
  for other in occupied: assert(not rect.intersects(other), "default nodes must not overlap at editor font scale")
  occupied.append(rect)
 assert(large.get_combined_minimum_size().x <= host.size.x)
 large.queue_free()
 await process_frame
 print("[boss-layout] PASS native-container expansion, bounded preview and selection controls")
 quit()
