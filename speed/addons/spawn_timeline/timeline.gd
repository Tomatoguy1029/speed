## 出現タイムラインのパネル。上に操作のボタン、下にトラック（timeline_canvas.gd）を並べる。
## 編集はエディターの取り消し・やり直しに載せ、確定するたびにステージ（と、別ファイルの時間帯）を保存する。
@tool
extends VBoxContainer

const Canvas := preload("res://addons/spawn_timeline/timeline_canvas.gd")
## 攻撃の組み合わせの表の場所を書くプロジェクト設定
const SETTING_RULES := "spawn_timeline/attack_rules"

var undo_redo: EditorUndoRedoManager
var stage: Resource = null
var canvas: Control
var _title: Label
var _info: Label
## 組み合わせのシーンのパス → 中に置いた敵の種類の一覧
var _types_cache: Dictionary = {}

## 時間帯の配列 phases と出現のクリップの配列 clips を持つリソースか。
static func is_stage(object: Object) -> bool:
	if not object is Resource:
		return false
	var names := {}
	for p in object.get_property_list():
		names[p.name] = true
	return names.has("phases") and names.has("clips")

func _init() -> void:
	name = "SpawnTimeline"
	custom_minimum_size = Vector2(0, 260)
	var bar := HBoxContainer.new()
	add_child(bar)
	_title = Label.new()
	_title.text = "ステージを開くと表示します"
	bar.add_child(_title)
	for spec in [["クリップを足す", _add_clip], ["選んだクリップを消す", _remove_clip], ["ここから試す", _launch_here]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		bar.add_child(b)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_info)
	canvas = Canvas.new()
	canvas.timeline = self
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(canvas)

func set_stage(value: Resource) -> void:
	stage = value
	_types_cache.clear()
	_title.text = stage.resource_path.get_file() if stage != null else ""
	canvas.fit()
	refresh()

func refresh() -> void:
	var n: int = canvas.conflicts().size() if stage != null else 0
	_info.text = "再生位置 %s　　重なり %d" % [Canvas.clock(canvas.playhead), n]
	canvas.queue_redraw()

func phases() -> Array:
	return stage.get("phases") if stage != null else []

func clips() -> Array:
	return stage.get("clips") if stage != null else []

## 組み合わせのシーンに置いた敵の種類（置き場所のノードの enemy）。シーンごとに1回だけ調べる。
func formation_types(clip: Resource) -> Array:
	var scene = clip.get("formation")
	if not scene is PackedScene:
		return []
	var path: String = scene.resource_path
	if not _types_cache.has(path):
		var found := {}
		var root: Node = scene.instantiate()
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			var e = n.get("enemy")
			if e != null and String(e) != "":
				found[StringName(e)] = true
			stack.append_array(n.get_children())
		root.free()
		_types_cache[path] = found.keys()
	return _types_cache[path]

## 攻撃の組み合わせの表（gap(a, b) を持つリソース）。設定がなければ null。
func rules() -> Resource:
	var path := str(ProjectSettings.get_setting(SETTING_RULES, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var r: Resource = load(path)
	return r if r != null and r.has_method("gap") else null

## 編集を取り消し・やり直しに載せる。changes は [対象, プロパティ, 前の値, 後の値] の並び。
## 値はすでに後の値になっている前提で、実行はしない。
func commit(label: String, changes: Array) -> void:
	undo_redo.create_action(label)
	for c in changes:
		undo_redo.add_do_property(c[0], c[1], c[3])
		undo_redo.add_undo_property(c[0], c[1], c[2])
	undo_redo.add_do_method(self, "_save")
	undo_redo.add_undo_method(self, "_save")
	undo_redo.commit_action(false)
	_save()

## ステージと、別のファイルにある時間帯を保存する。
func _save() -> void:
	if stage == null:
		return
	for p in phases():
		if p is Resource and p.resource_path != "" and not p.resource_path.contains("::"):
			ResourceSaver.save(p)
	ResourceSaver.save(stage)
	refresh()

## clips の要素の型（プロパティの型の指定から、プロジェクトのクラスを探して作る）。
func _new_clip() -> Resource:
	for p in stage.get_property_list():
		if p.name != "clips":
			continue
		var cls := String(p.hint_string).get_slice(":", 1)
		for g in ProjectSettings.get_global_class_list():
			if String(g["class"]) == cls:
				return load(g.path).new()
	return null

func _add_clip() -> void:
	if stage == null:
		return
	var clip := _new_clip()
	if clip == null:
		return
	clip.set("label", "新しいクリップ")
	clip.set("time", snappedf(canvas.playhead, 1.0))
	var before: Array = clips()
	var after: Array = before.duplicate()
	after.append(clip)
	stage.set("clips", after)
	canvas.selected = after.size() - 1
	commit("クリップを足す", [[stage, "clips", before, after]])
	EditorInterface.inspect_object(clip, "", true)

func _remove_clip() -> void:
	if stage == null or canvas.selected < 0 or canvas.selected >= clips().size():
		return
	var before: Array = clips()
	var after: Array = before.duplicate()
	after.remove_at(canvas.selected)
	stage.set("clips", after)
	canvas.selected = -1
	commit("クリップを消す", [[stage, "clips", before, after]])

## 再生位置の時刻から、このステージを起動する（ステージの起動の道具 stage_launcher の予約を使う）。
func _launch_here() -> void:
	if stage == null:
		return
	var request: GDScript = load("res://addons/stage_launcher/launch_request.gd")
	request.request(int(stage.get("index")), canvas.playhead)
	EditorInterface.play_main_scene()
