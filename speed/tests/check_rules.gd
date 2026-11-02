## 設計書 4.4 の決まりを自動で確かめる。違反があれば一覧を出して失敗する。
##   Godot --headless --path speed --script res://tests/check_rules.gd
##
## 確かめること：
##   1. Autoload はアプリ全体の窓口と、開発用の起動だけ
##   2. Manager はコンテンツ（ステージ・ボス・フィールドの仕掛け）に依存しない（決まり4）
##   3. 再利用する道具は Godot 本体だけに依存し、content_build はゲーム専用の生成を受け持つ
##   4. UI はランの状態を書き換えない（state.xxx = の代入をしない）（設計書 4.1）
extends SceneTree

const ALLOWED_AUTOLOADS := ["ContentManager", "SaveManager", "AudioManager", "GameManager", "RunManager", "ProfileManager", "DevBootstrap"]
const CONTENT_REFS := ["res://scenes/stages", "res://scenes/bosses", "res://scenes/gimmicks",
	"res://scripts/bosses", "res://scripts/gimmicks"]
const GAME_REFS := ["res://scripts", "res://scenes", "res://data", "ContentManager", "SaveManager",
	"AudioManager", "GameManager"]

var errors: Array[String] = []

func _initialize() -> void:
	if "--package-runtime" in OS.get_cmdline_user_args() or "--package-missing-runtime" in OS.get_cmdline_user_args():
		call_deferred("_package_runtime")
		return
	_check_autoloads()
	for path in _files("res://scripts/managers"):
		_forbid(path, CONTENT_REFS, "Manager がコンテンツを参照している")
	for path in _files("res://addons"):
		if path.begins_with("res://addons/content_build/"):
			continue
		_forbid(path, GAME_REFS, "道具（addons）がゲームを参照している")
	for path in _files("res://scripts/ui"):
		_forbid_regex(path, "\\bstate\\.[a-z_]+\\s*[+\\-*/]?=[^=]", "UI がランの状態を書き換えている")
	for path in _files("res://scripts/encounters"):
		_forbid(path, ["projectiles.director ="], "攻撃directorの所有はRunSimulationに集約する")
	_forbid("res://scripts/runtime/run_simulation.gd", ["res://scripts/dev/", "&\"debug_"], "シミュレーションが開発用機能を参照している")
	_forbid("res://scenes/run/run.tscn", ["res://scripts/dev/"], "本番の表示が開発用機能を参照している")
	_forbid("res://scripts/ui/main.gd", ["res://gyms/", "res://addons/"], "画面の入口が開発用機能を参照している")
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


## export済みPCKだけを持つ配布エンジンから外部Scriptとして呼ぶ。
## 生成器・テスト資源・エディターキャッシュは配布へ加えない。
func _package_runtime() -> void:
	var missing := "--package-missing-runtime" in OS.get_cmdline_user_args()
	var loaded := ClassDB.class_exists(&"SpeedRunCore")
	Engine.max_fps = 60
	if loaded == missing:
		push_error("配布拡張の存在と読込結果が一致しません")
		quit(1)
		return
	var manager = root.get_node_or_null("RunManager")
	if manager==null:
		push_error("配布のラン入口を読み込めません")
		quit(1)
		return
	var session = manager.create_run()
	root.add_child(session)
	session.auto_step = false
	for frame in range(600):
		if session.bridge!=null or session.cpp_error!=OK: break
		await process_frame
	if missing:
		var rejected: bool = session.bridge==null and not _package_has_legacy(session) and session.cpp_error!=OK
		session.free()
		if rejected: print("[package_missing_runtime] OK")
		else: push_error("拡張欠落時にランの準備失敗が必要です")
		quit(0 if rejected else 1)
		return
	if session.bridge==null or _package_has_legacy(session):
		push_error("配布の通常入口がC++ランを開始しません")
		session.free()
		quit(1)
		return
	var bridge = session.bridge
	var before: Dictionary = bridge.read_frame()
	var updated: Dictionary = bridge.step(1.0/120.0,bridge.pack_intent(load("res://scripts/input/intent.gd").new()), {"logical_size":Vector2(1280,720)})
	var after: Dictionary = bridge.read_frame()
	var ok: bool = before.ok and updated.ok and after.ok and after.value.tick==before.value.tick+1
	session.free()
	await process_frame
	if ok: print("[package_runtime] OK cpu="+Engine.get_architecture_name())
	else: push_error("配布ランを最小更新できません")
	quit(0 if ok else 1)

func _package_has_legacy(session: Object) -> bool:
	for property: Dictionary in session.get_property_list():
		if property.name=="_sim": return session.get("_sim")!=null
	return false
