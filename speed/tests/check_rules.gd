## 設計書 4.4 の決まりを自動で確かめる。違反があれば一覧を出して失敗する。
##   Godot --headless --path speed --script res://tests/check_rules.gd
##
## 確かめること：
##   1. Autoload はアプリ全体の4つだけ（設計書 4.3）
##   2. Manager はコンテンツ（ステージ・ボス・フィールドの仕掛け）に依存しない（決まり4）
##   3. 道具（addons/）は Godot 本体だけに依存する（設計書 4.1）
##   4. UI はランの状態を書き換えない（state.xxx = の代入をしない）（設計書 4.1）
extends SceneTree

const ALLOWED_AUTOLOADS := ["ConfigManager", "SaveManager", "AudioManager", "GameManager"]
const CONTENT_REFS := ["res://scenes/stages", "res://scenes/bosses", "res://scenes/gimmicks",
	"res://scripts/bosses", "res://scripts/gimmicks"]
const GAME_REFS := ["res://scripts", "res://scenes", "res://data", "ConfigManager", "SaveManager",
	"AudioManager", "GameManager"]

var errors: Array[String] = []

func _initialize() -> void:
	_check_autoloads()
	for path in _files("res://scripts/managers"):
		_forbid(path, CONTENT_REFS, "Manager がコンテンツを参照している")
	for path in _files("res://addons"):
		if path.begins_with("res://addons/limboai"):
			continue
		_forbid(path, GAME_REFS, "道具（addons）がゲームを参照している")
	for path in _files("res://scripts/ui"):
		_forbid_regex(path, "\\bstate\\.[a-z_]+\\s*[+\\-*/]?=[^=]", "UI がランの状態を書き換えている")
	if errors.is_empty():
		print("[check_rules] OK")
		quit(0)
	else:
		for e in errors:
			print("[check_rules] ", e)
		quit(1)

func _check_autoloads() -> void:
	var names: Array[String] = []
	for prop in ProjectSettings.get_property_list():
		var n: String = prop.name
		if n.begins_with("autoload/"):
			names.append(n.trim_prefix("autoload/"))
	for n in names:
		if not ALLOWED_AUTOLOADS.has(n):
			errors.append("決められていない Autoload: %s" % n)

func _forbid(path: String, words: Array, message: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("#"):
			continue
		for w in words:
			if line.contains(w):
				errors.append("%s：%s:%d（%s）" % [message, path, i + 1, w])

func _forbid_regex(path: String, pattern: String, message: String) -> void:
	var re := RegEx.create_from_string(pattern)
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("#"):
			continue
		if re.search(line) != null:
			errors.append("%s：%s:%d" % [message, path, i + 1])

func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for sub in da.get_directories():
		out.append_array(_files(dir.path_join(sub)))
	return out
