@tool
extends EditorPlugin

const PANEL := preload("res://scripts/dev/stage_enemy_panel.gd")
var _panel: Control
var _inspected: StageDef

func _enter_tree() -> void:
	_panel = PANEL.new()
	_panel.name = "ステージ敵調整"
	_panel.custom_minimum_size = Vector2(280, 320)
	_panel.saved.connect(_on_saved)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _panel)
	EditorInterface.get_inspector().edited_object_changed.connect(_on_inspected)

func _exit_tree() -> void:
	EditorInterface.get_inspector().edited_object_changed.disconnect(_on_inspected)
	remove_control_from_docks(_panel)
	_panel.queue_free()

func _on_inspected() -> void:
	var object := EditorInterface.get_inspector().get_edited_object()
	if object is StageDef and not object is RuntimeStage:
		_inspected = object
		_panel.open_stage(object.resource_path)

func _on_saved(stage: StageDef) -> void:
	# タイムラインとInspectorが保持しているステージにも、保存済みの値だけを同期する。
	var cached := ResourceLoader.load(_panel.stage_path) as StageDef
	if cached != null: cached.enemy_tuning = stage.enemy_tuning.duplicate(true)
	if _inspected != null and _inspected.resource_path == _panel.stage_path:
		_inspected.enemy_tuning = stage.enemy_tuning.duplicate(true)
	EditorInterface.get_resource_filesystem().scan()
