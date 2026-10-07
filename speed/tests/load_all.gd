## 確認用：すべてのスクリプトとシーンを読み込み、読み込めないものを一覧にする（Autoload を読み込んだ状態で行う）。
##   Godot --headless --path speed res://tests/load_all.tscn
extends Node

const DIRS := ["res://scripts", "res://scenes", "res://addons", "res://data", "res://tests", "res://gyms"]

func _ready() -> void:
	var failed: Array[String] = []
	var count := 0
	for d in DIRS:
		for path in _files(d):
			if not (path.ends_with(".gd") or path.ends_with(".tscn") or path.ends_with(".tres")):
				continue
			if path.begins_with("res://addons/") and path.ends_with("plugin.gd"):
				continue  # エディタ専用（EditorPlugin）はゲームの中では読めない
			count += 1
			var res := load(path)
			if res == null or (res is GDScript and not res.can_instantiate() and not res.is_abstract()):
				failed.append(path)
	print("[load_all] %d files, %d failed" % [count, failed.size()])
	for f in failed:
		print("[load_all] FAILED ", f)
	get_tree().quit(1 if not failed.is_empty() else 0)

func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		out.append(dir.path_join(f))
	for sub in da.get_directories():
		out.append_array(_files(dir.path_join(sub)))
	return out
