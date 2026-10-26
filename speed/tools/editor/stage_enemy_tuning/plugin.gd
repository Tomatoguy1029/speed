@tool
extends EditorPlugin

const PANEL := preload("res://tools/editor/stage_enemy_tuning/dock_panel.gd")
var _dock: ScrollContainer
var _panel: Control
var _inspected: StageDef

func _enter_tree() -> void:
	add_to_group("speed_stage_enemy_tuning")
	# 折り返す説明文や一覧の最小サイズを、エディター全体へ伝えない。
	_dock = ScrollContainer.new()
	_dock.name = "ステージ敵調整"
	_dock.custom_minimum_size = Vector2(160, 320)
	_dock.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dock.follow_focus = true
	_panel = PANEL.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.saved.connect(_on_saved)
	_dock.add_child(_panel)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	add_tool_menu_item("ステージ敵調整", open_dock)
	EditorInterface.get_inspector().edited_object_changed.connect(_on_inspected)
	_on_inspected.call_deferred()

func open_dock() -> void:
	_dock.custom_minimum_size.x = 160
	if _panel.stage_path.is_empty():
		_panel.open_stage("res://data/stages/stage_1.tres")
	var tabs := _dock.get_parent() as TabContainer
	if tabs != null:
		tabs.current_tab = _dock.get_index()

func _exit_tree() -> void:
	remove_tool_menu_item("ステージ敵調整")
	EditorInterface.get_inspector().edited_object_changed.disconnect(_on_inspected)
	remove_control_from_docks(_dock)
	_dock.queue_free()

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
