## 独立した炎の編集用。調整値は複製して保持し、明示保存でプリセットへ反映する。
## @tool / Inspector buttons: https://docs.godotengine.org/en/4.6/tutorials/plugins/running_code_in_the_editor.html
@tool
extends Control

const DEFAULT_PRESET := "res://data/visuals/pixel_fire.tres"
const PANEL := preload("res://gyms/pixel_fire_controls.gd")

@export_file("*.tres") var preset_path := DEFAULT_PRESET
@export_tool_button("選択したプリセットを読み込む") var load_action = reload_preset
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "PixelFireSettings", PROPERTY_USAGE_EDITOR)
var settings: PixelFireSettings:
	set(value):
		if settings != null and settings.changed.is_connected(_changed):
			settings.changed.disconnect(_changed)
		settings = value.duplicate() if value != null else PixelFireSettings.new()
		settings.changed.connect(_changed)
		if is_instance_valid(fire):
			fire.settings = settings
		_changed()
@export_tool_button("調整値を保存") var save_action = save_preset
@export_file("*.tres") var copy_path := "res://data/visuals/pixel_fire_custom.tres"
@export_tool_button("別名で複製保存して切り替える") var copy_action = save_copy
@export_group("再生")
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var playing := true
## 0は連続燃焼。正の秒数で発生を止め、残った炎を消す。
@export_range(0.0, 3.0, 0.05) var emission_seconds := 0.0
@export var seed_value := 42
@export_tool_button("同じ設定で先頭から再実行") var restart_action = restart
@export_tool_button("停止して1コマ進む") var step_action = step
@export_custom(PROPERTY_HINT_MULTILINE_TEXT, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var status := ""

var fire: PixelFire
var stage: SubViewport
var _loaded_path := ""
var _source_hash := ""
var _panel: Control
var _status_label: Label
var _view_dirty := true

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var split := HSplitContainer.new()
	margin.add_child(split)
	if not Engine.is_editor_hint():
		_panel = PANEL.new()
		split.add_child(_panel)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	var title := Label.new()
	title.text = "ピクセル炎 — 粒子 → 密度 → 色面 → 発光"
	right.add_child(title)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(container)
	stage = SubViewport.new()
	stage.size = Vector2i(640, 480)
	stage.disable_3d = true
	stage.world_2d = World2D.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(stage)
	var background := ColorRect.new()
	background.color = Color("10141e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(background)
	fire = PixelFire.new()
	fire.manual = true
	stage.add_child(fire)
	stage.size_changed.connect(func(): _view_dirty = true)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status_label)
	settings = PixelFireSettings.new()
	reload_preset()
	if is_instance_valid(_panel):
		_panel.bind_preview(self)
	_set_status(status)

func _process(dt: float) -> void:
	if not is_instance_valid(fire):
		return
	# 編集中のシーンだけを進める。非表示タブと停止中は密度場を更新しない。
	if Engine.is_editor_hint() and get_tree().edited_scene_root != self:
		return
	if _view_dirty:
		_view_dirty = false
		fire.position = Vector2(stage.size.x * 0.5, stage.size.y * 0.85)
		var bounds := settings.field_size
		fire.scale = Vector2.ONE * maxf(0.2, minf(stage.size.x / (bounds.x + 60.0), stage.size.y / (bounds.y + 40.0)))
		stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	if playing:
		var before := fire.density_render_count
		fire.advance(dt)
		if fire.density_render_count != before:
			stage.render_target_update_mode = SubViewport.UPDATE_ONCE

func _changed() -> void:
	_view_dirty = true
	_set_status("未保存の調整値 / 保存先: " + _loaded_path)

func _set_status(value: String) -> void:
	status = value
	if is_instance_valid(_status_label):
		_status_label.text = value

func restart() -> void:
	if not is_instance_valid(fire):
		return
	fire.restart(seed_value, emission_seconds if emission_seconds > 0.0 else -1.0)
	_view_dirty = true

func step() -> void:
	playing = false
	if is_instance_valid(fire):
		fire.advance(1.0 / maxf(1.0, settings.update_fps))
		_view_dirty = true

func reload_preset() -> void:
	var path := preset_path.simplify_path()
	if not _valid_path(path) or not FileAccess.file_exists(path):
		_set_status("読込先には data/visuals 内の既存 .tres を指定してください。")
		return
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PixelFireSettings
	if loaded == null:
		_set_status("ピクセル炎の設定Resourceを読み込めません。")
		return
	_loaded_path = path
	_source_hash = FileAccess.get_md5(path)
	settings = loaded
	restart()
	notify_property_list_changed()
	if is_instance_valid(_panel):
		_panel.refresh()
	_set_status("保存値を読み込みました: " + _loaded_path)

func save_preset() -> void:
	if _loaded_path.is_empty() or preset_path.simplify_path() != _loaded_path:
		_set_status("保存前に、選択したプリセットを読み込んでください。")
		return
	if FileAccess.get_md5(_loaded_path) != _source_hash:
		_set_status("保存先が外部で変更されています。再読込してから調整してください。")
		return
	_write_preset(_loaded_path)

func save_copy() -> void:
	var path := copy_path.simplify_path()
	if not _valid_path(path) or FileAccess.file_exists(path):
		_set_status("複製先には data/visuals 内の新しい .tres パスを指定してください。既存ファイルは保護します。")
		return
	if _write_preset(path):
		preset_path = path
		notify_property_list_changed()
		if is_instance_valid(_panel):
			_panel.refresh()

func _valid_path(path: String) -> bool:
	return path.begins_with("res://data/visuals/") and path.ends_with(".tres")

func _write_preset(path: String) -> bool:
	if settings == null:
		return false
	# 書き出すコピーだけにパスを付け、共有キャッシュと調整中Resourceを分離する。
	var error := ResourceSaver.save(settings.duplicate(), path)
	if error != OK:
		_set_status("保存に失敗しました: " + error_string(error))
		return false
	_loaded_path = path
	_source_hash = FileAccess.get_md5(path)
	_set_status("保存しました: " + path)
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	return true
