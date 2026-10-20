## 出現タイムラインのパネル。上に操作のボタン、下にトラック（timeline_canvas.gd）を並べる。
## 編集はエディターの取り消し・やり直しに載せ、確定するたびにステージ（と、別ファイルの時間帯）を保存する。
@tool
extends VBoxContainer

const Canvas := preload("res://addons/spawn_timeline/timeline_canvas.gd")

var undo_redo: EditorUndoRedoManager
var _pin_buttons: Dictionary = {}
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
	custom_minimum_size = Vector2(0, 300)
	# 幅が足りなければ折り返す（トラックの幅をボタンの並びに引っ張られないようにする）
	var bar := HFlowContainer.new()
	add_child(bar)
	_title = Label.new()
	_title.text = "ステージを開くと表示します"
	bar.add_child(_title)
	for spec in [["＋クリップ", _add_clip], ["クリップを消す", _remove_clip], ["＋雑魚の曲線", _add_curve_menu],
			["ボスピン", func() -> void: canvas.clocks.toggle_pin("boss_time")],
			["終了ピン", func() -> void: canvas.clocks.toggle_pin("time_limit")],
			["▶ ここから試す", _launch_here],
			["縮小", func() -> void: canvas.zoom(0.8)], ["拡大", func() -> void: canvas.zoom(1.25)], ["全体", func() -> void: canvas.fit()],
			["操作", _show_help]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		bar.add_child(b)
		if spec[0] in ["ボスピン", "終了ピン"]:
			_pin_buttons["boss_time" if spec[0] == "ボスピン" else "time_limit"] = b
			b.disabled = true
	_info = Label.new()
	bar.add_child(_info)
	# トラックは縦にスクロールする（目盛り・時間帯・雑魚の数はトラックの描画が上に留める）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	canvas = Canvas.new()
	canvas.timeline = self
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(canvas)
	scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: canvas.queue_redraw())

func _notification(what: int) -> void:
	# 下のパネルと上部の画面のどちらで編集しても、表示し直したときに最新を描く
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and stage != null:
		refresh()

func set_stage(value: Resource) -> void:
	stage = value
	_types_cache.clear()
	_title.text = stage.resource_path.get_file() if stage != null else ""
	canvas.fit()
	refresh()

func refresh() -> void:
	for prop in _pin_buttons:
		var button: Button = _pin_buttons[prop]
		var label := "ボスピン" if prop == "boss_time" else "終了ピン"
		var exists: bool = stage != null and canvas.clocks.value(prop) >= 0.0
		button.text = ("− " if exists else "＋ ") + label + ("を削除" if exists else "を配置")
		button.disabled = stage == null
		button.tooltip_text = "ピンを削除します" if exists else "再生位置に配置します。0:00なら既存の配置の末尾に置きます。配置後はドラッグ・ダブルクリックで時刻を変更できます。"
	var n: int = canvas.mismatches().size() if stage != null else 0
	_info.text = "再生位置 %s　　種類が合わないクリップ %d" % [Canvas.clock(canvas.playhead), n]
	if stage != null:
		canvas.custom_minimum_size.y = canvas.content_height()
	canvas.queue_redraw()

func phases() -> Array:
	return stage.get("phases") if stage != null else []

func clips() -> Array:
	return stage.get("clips") if stage != null else []

## 敵の種類の名前（敵の定義の display_name。読めなければ type ID）。
func enemy_name(id: StringName) -> String:
	if not _names.has(id):
		var dir := str(ProjectSettings.get_setting("spawn_timeline/enemy_dir", ""))
		var path := dir.path_join(String(id) + ".tres")
		var res: Resource = load(path) if dir != "" and ResourceLoader.exists(path) else null
		_names[id] = str(res.get("display_name")) if res != null and res.get("display_name") != null and str(res.get("display_name")) != "" else String(id)
	return _names[id]

var _names: Dictionary = {}

## 敵の種類の区分（敵の定義の rank。雑魚は 1）。読めなければ 0。
func enemy_rank(id: StringName) -> int:
	var dir := str(ProjectSettings.get_setting("spawn_timeline/enemy_dir", ""))
	var path := dir.path_join(String(id) + ".tres")
	var res: Resource = load(path) if dir != "" and ResourceLoader.exists(path) else null
	return int(res.get("rank")) if res != null and res.get("rank") != null else 0

## 雑魚の目標の数の曲線（zako_curves）。
func curves() -> Array:
	return stage.get("zako_curves") if stage != null and stage.get("zako_curves") != null else []

## フォーメーション（組み合わせのシーン）に置いた敵の種類（置き場所のノードの enemy）。シーンごとに1回だけ調べる。
func scene_types(scene: PackedScene) -> Array:
	if scene == null:
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

## クリップのフォーメーションのうち、クリップの種類の組み合わせにない敵を置いているもの：[[シーンの名前, 種類], …]
func clip_mismatch(clip: Resource) -> Array:
	var out := []
	var allowed: Array = clip.get("types")
	for scene in clip.get("formations"):
		for t in scene_types(scene):
			if not allowed.has(t):
				out.append([scene.resource_path.get_file().get_basename(), t])
	return out

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
	return _new_element("clips")

## 配列のプロパティ prop の要素の型のリソースを作る。
func _new_element(prop: String) -> Resource:
	for p in stage.get_property_list():
		if p.name != prop:
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
	clip.set("length", 60.0)
	var before: Array = clips()
	var after: Array = before.duplicate()
	after.append(clip)
	stage.set("clips", after)
	canvas.selected = after.size() - 1
	commit("クリップを足す", [[stage, "clips", before, after]])
	EditorInterface.inspect_object(clip, "", true)

## ステージの敵のうち、まだ曲線のない雑魚（区分 1）を選んで、雑魚の目標の数の曲線を足す。
func _add_curve_menu() -> void:
	if stage == null:
		return
	var have := {}
	for c in curves():
		have[c.get("type")] = true
	var menu := PopupMenu.new()
	for id in stage.get("enemies"):
		if not have.has(id) and enemy_rank(id) == 1:
			menu.add_item(enemy_name(id))
			menu.set_item_metadata(menu.item_count - 1, String(id))
	if menu.item_count == 0:
		menu.add_item("（ステージの敵の一覧に、曲線のない雑魚がいない）")
		menu.set_item_disabled(0, true)
	menu.id_pressed.connect(func(index: int) -> void:
		_add_curve(StringName(menu.get_item_metadata(menu.get_item_index(index))))
		menu.queue_free())
	menu.popup_hide.connect(menu.queue_free)
	add_child(menu)
	menu.popup(Rect2i(get_screen_position() + get_local_mouse_position(), Vector2i.ZERO))

func _add_curve(type: StringName) -> void:
	var curve := _new_element("zako_curves")
	if curve == null:
		return
	curve.set("type", type)
	curve.set("points", PackedVector2Array([Vector2(0.0, 10.0)]))
	var before: Array = curves()
	var after: Array = before.duplicate()
	after.append(curve)
	stage.set("zako_curves", after)
	commit("雑魚の曲線を足す", [[stage, "zako_curves", before, after]])

## 選んでいる雑魚の曲線を消す。
func _remove_curve() -> void:
	if stage == null or canvas.curve_selected < 0 or canvas.curve_selected >= curves().size():
		return
	var before: Array = curves()
	var after: Array = before.duplicate()
	after.remove_at(canvas.curve_selected)
	stage.set("zako_curves", after)
	canvas.curve_selected = -1
	canvas.point_selected = -1
	commit("雑魚の曲線を消す", [[stage, "zako_curves", before, after]])

func _remove_clip() -> void:
	if stage == null or canvas.selected < 0 or canvas.selected >= clips().size():
		return
	var before: Array = clips()
	var after: Array = before.duplicate()
	after.remove_at(canvas.selected)
	stage.set("clips", after)
	canvas.selected = -1
	commit("クリップを消す", [[stage, "clips", before, after]])

## 操作の説明を、ボタンの下に出す（外をクリックすると閉じる）。
func _show_help() -> void:
	var panel := PopupPanel.new()
	var label := Label.new()
	label.text = Canvas.HELP
	panel.add_child(label)
	panel.popup_hide.connect(panel.queue_free)
	add_child(panel)
	panel.popup(Rect2i(get_screen_position() + get_local_mouse_position() + Vector2(0, 24), Vector2i.ZERO))

## 再生位置の時刻から、このステージを起動する（ステージの起動の道具 stage_launcher の予約を使う）。
func _launch_here() -> void:
	if stage == null:
		return
	var request: GDScript = load("res://addons/stage_launcher/launch_request.gd")
	request.request(int(stage.get("index")), canvas.playhead)
	EditorInterface.play_main_scene()
