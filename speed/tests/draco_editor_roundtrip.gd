extends Node
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func _ready() -> void:
	var editor=load("res://tools/editor/boss_flow/editor.gd").new()
	add_child(editor)
	editor.open_boss("res://data/bosses/ai/draco_action_rules.tres","res://data/bosses/ai/draco_flow.tres")
	for move in editor.rules.techniques:
		check(editor.open_technique(move.resource_path)==OK,"全技の設定を編集できる: "+String(move.technique))
	check(editor.has_method("set_arc_value"),"複数の弧をボス行動から編集できる")
	if editor.has_method("set_arc_value"):
		DirAccess.make_dir_recursive_absolute("res://.content/dev")
		var source: Resource=load("res://data/bosses/draco_moves/inhale.tres").duplicate(true)
		var path := "res://.content/dev/draco_arc_test.tres"
		check(ResourceSaver.save(source,path)==OK,"試遊用コピーを保存する")
		editor.open_technique(path)
		editor.set_arc_value(0,"radius",321.0)
		editor.set_arc_value(1,"offset_x",77.0)
		check(editor.save_current()==OK,"弧の編集を保存する")
		var reloaded: Resource=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		check(reloaded.parameters.arcs[0].radius==321.0 and reloaded.parameters.arcs[1].offset.x==77.0,"半径と弧の位置が再読込後も残る")
		DirAccess.remove_absolute(path)
	var spiral_source: Resource=load("res://data/bosses/draco_moves/spiral.tres").duplicate(true)
	var spiral_path := "res://.content/dev/draco_spiral_test.tres"
	check(ResourceSaver.save(spiral_source,spiral_path)==OK,"渦の試遊用コピーを保存する")
	check(editor.open_technique(spiral_path)==OK,"渦の調整項目を既存ボスAIで開く")
	var fields := {}
	for child in editor._fields.get_children():
		if child is SpinBox and child.has_meta("key"):
			fields[child.get_meta("key")]=child
	for key in ["radius_factor","aspect_ratio","pitch_ratio","coil_time","head_offset","pause","exit_duration"]:
		check(fields.has(key) and not fields[key].tooltip_text.is_empty(),"渦の調整項目と説明を表示する: "+key)
	check(not fields.has("first_lap") and not fields.has("second_lap") and not fields.has("warn"),"巻く速さを二重に編集させない")
	editor.set_value("radius_factor",1.05)
	editor.set_value("coil_time",0.8)
	editor.set_value("head_offset",370.0)
	check(editor.save_current()==OK,"渦の調整値を保存する")
	var spiral_reloaded: Resource=ResourceLoader.load(spiral_path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	check(is_equal_approx(spiral_reloaded.parameters.radius_factor,1.05) and is_equal_approx(spiral_reloaded.parameters.coil_time,0.8) and is_equal_approx(spiral_reloaded.parameters.head_offset,370.0),"渦半径・速度・頭終点が保存後の読み直しでも残る")
	DirAccess.remove_absolute(spiral_path)
	editor.free()
	print("[draco_editor_roundtrip] failures=",failures)
	get_tree().quit(1 if failures else 0)
