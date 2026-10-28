## 技が使うシーンの選択・表示・専用コピー・新規作成。
@tool
extends RefCounted
static func append(editor: Control, move: Resource) -> void:
	editor._section_heading("見た目")
	_row(editor, move, "visual", "技の見た目")
	for key in move.field_names():
		if move.field_property(key).get("class_name", "") == &"PackedScene":
			_row(editor, move, key, move.field_description(key).split("\n")[0])

static func _row(editor: Control, move: Resource, key: String, title: String) -> void:
	var label := Label.new()
	label.text = title if not title.is_empty() else key
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	editor._fields.add_child(label)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor._fields.add_child(controls)
	var scene: PackedScene = move.get(key)
	var path := Label.new()
	path.text = scene.resource_path if scene != null else "未設定"
	path.tooltip_text = path.text
	path.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(path)
	var buttons := GridContainer.new()
	buttons.columns = 2
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(buttons)
	for action in ["選ぶ…", "開く", "専用に複製…", "新規作成…"]:
		var button := Button.new()
		button.text = {"専用に複製…": "専用コピー…", "新規作成…": "新規作成…"}.get(action, action)
		button.tooltip_text = action
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = scene == null and action in ["開く", "専用に複製…"]
		buttons.add_child(button)
		button.pressed.connect(func():
			if action == "開く":
				open_scene(editor, scene.resource_path)
				return
			_choose(editor, move, key, action))

static func open_scene(editor: Control, path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		editor._status.text = "表示ファイルが見つかりません。"
		return
	if Engine.is_editor_hint(): EditorInterface.open_scene_from_path(path)
	else: editor._status.text = "Godotのファイル一覧から開けます: " + path

static func _assign(editor: Control, move: Resource, key: String, scene: PackedScene) -> void:
	move.set(key, scene)
	move._values_dirty = true
	editor._mark_move_dirty(move)
	if editor.current == move: editor._refresh()

static func _choose(editor: Control, move: Resource, key: String, action: String) -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if action == "選ぶ…" else FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.tscn ; 見た目のシーン"])
	dialog.title = action
	if action != "選ぶ…":
		var directory := "res://scenes/bosses/%s" % String(editor.rules.adapter) if key == "visual" else "res://scenes/attacks"
		dialog.current_path = directory.path_join(String(move.technique) + "_" + key + ".tscn")
	dialog.file_selected.connect(func(path):
		var scene: PackedScene
		if action == "選ぶ…": scene = load(path) as PackedScene
		else:
			if FileAccess.file_exists(path):
				editor._status.text = "同名のファイルがあります。別の名前を指定してください。"
				dialog.queue_free()
				return
			if action == "専用に複製…": scene = move.get(key).duplicate(true)
			elif key == "visual": scene = _new_visual()
			else: scene = load("res://scenes/attacks/bullet.tscn").duplicate(true)
			var error := ResourceSaver.save(scene, path)
			if error != OK:
				editor._status.text = "シーンを保存できません: " + error_string(error)
				dialog.queue_free()
				return
			scene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if scene == null:
			editor._status.text = "シーンを読み込めません。"
			dialog.queue_free()
			return
		var source := scene.instantiate()
		var valid := source is Node2D if key == "visual" else source is AttackVisual
		source.free()
		if not valid:
			editor._status.text = "技の見た目はNode2D、弾の見た目はAttackVisualを使ってください。"
			dialog.queue_free()
			return
		editor.history.create_action("見た目のシーンを変更")
		editor.history.add_do_method(_assign.bind(editor, move, key, scene))
		editor.history.add_undo_method(_assign.bind(editor, move, key, move.get(key)))
		editor.history.commit_action()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	editor.add_child(dialog)
	dialog.popup_centered_ratio(0.65)

static func _new_visual() -> PackedScene:
	var root := Node2D.new()
	root.name = "TechniqueVisual"
	var tell := Polygon2D.new()
	tell.name = "Telegraph"
	root.add_child(tell)
	tell.owner = root
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	var library := AnimationLibrary.new()
	for phase in ["windup", "active", "recover", "hit"]:
		var animation := Animation.new()
		animation.length = 1.0
		library.add_animation(phase, animation)
	player.add_animation_library("", library)
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene
