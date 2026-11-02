## 目印・BOOST用の独立した本番表示。BOOSTだけ本番の移動・経路を操作する。
extends VBoxContainer

signal reward_context_ready
signal reward_context_error(message: String)

const AURA := preload("res://gyms/game_context_aura.gd")
const ELITE_AUTHORING_SHADER := preload("res://shaders/elite_mark.gdshader")
const HUD := preload("res://gyms/game_context_hud.gd")
const GAUGE := preload("res://scripts/ui/boost_gauge_visual.gd")
const BUILDER := preload("res://tools/content/build_run_content.gd")
const LIVE_VISUALS := preload("res://tools/content/visual_transforms.gd")
const EFFECTS := preload("res://data/visuals/effect_settings.tres")
const OPERATION_MODE := 5

var preview_paused := false
var _active := false
var _mode := "landmark"
var _clock := 0.0
var _settings: EnemyMarkSettings
var _elite_settings: EnemyMarkSettings
var _elite_landmark := CheckButton.new()
var _boost_values: Dictionary = {}
var _has_boost_values := false
var _follow_cursor := false
var _session: RunSession
var _render: RunPresentation
var _aura
var _hud
var _viewport: SubViewport
var _frame: SubViewportContainer
var _status := Label.new()
var _stage := OptionButton.new()
var _placement := OptionButton.new()
var _enemy := OptionButton.new()
var _form := OptionButton.new()
var _boost := OptionButton.new()
var _enemy_row := HBoxContainer.new()
var _boost_row := HBoxContainer.new()
var _pump := HSlider.new()
var _stage_ids: Array[int] = []
var _enemy_ids: Array[StringName] = []
var _target := -1
var _origin := Vector2.ZERO
var _center := Vector2.ZERO
var _source: RuntimeStage
var _config: GameConfig
var _definitions := {}
var _build_serial := 0
var _building := false
var _accumulator := 0.0
var _input: InputRouter
const DT := 1.0 / 120.0
var _pointer_inside := false
var _help := Label.new()
var _aspect: AspectRatioContainer
var _pause_control: CheckButton
var _restart_control: Button
var _reward_surface: Control
var _reward_parking := Control.new()
var _reward_building := false
var _reward_problem := ""
var _reward_stage_dirty := true

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var environment := HFlowContainer.new()
	add_child(environment)
	for index in ContentManager.stages:
		_stage_ids.append(int(index))
	_stage_ids.sort()
	for index in _stage_ids:
		_stage.add_item("ステージ%d" % index)
	environment.add_child(_stage)
	_stage.item_selected.connect(func(_index: int):
		_reward_stage_dirty = true
		_build_context())
	for caption in ["開始地点", "背景素材の付近"]: _placement.add_item(caption)
	environment.add_child(_placement)
	_placement.item_selected.connect(func(_index: int): _place_context())
	var pause := CheckButton.new()
	_pause_control = pause
	pause.text = "一時停止"
	pause.toggled.connect(func(value: bool):
		preview_paused = value
		if value: _release_input())
	environment.add_child(pause)
	var restart := Button.new()
	_restart_control = restart
	restart.text = "先頭へ"
	restart.pressed.connect(preview_restart)
	environment.add_child(restart)
	add_child(_enemy_row)
	_refresh_enemy_choices()
	_enemy_row.add_child(_enemy)
	_enemy.item_selected.connect(func(_index: int): _build_context())
	_elite_landmark.text = "目印の星と併せて表示"
	_enemy_row.add_child(_elite_landmark)
	_elite_landmark.toggled.connect(func(_value: bool):
		_refresh_mode())
	for caption in ["合体", "分離・上", "分離・下"]: _form.add_item(caption)
	_enemy_row.add_child(_form)
	_form.item_selected.connect(func(_index: int): _spawn_target())
	_pump.min_value = 0.0
	_pump.max_value = 1.0
	_pump.step = 0.01
	_pump.custom_minimum_size.x = 100
	_pump.tooltip_text = "ポンプの膨張（空から満タン）"
	_enemy_row.add_child(_pump)
	_pump.value_changed.connect(func(_value: float): _apply_pump())
	add_child(_boost_row)
	for caption in ["通常", "不足", "経路描画中", "使用可能の波紋", "満タンの閃き", "操作する"]: _boost.add_item(caption)
	_boost.select(OPERATION_MODE)
	_boost_row.add_child(_boost)
	_boost.item_selected.connect(func(_index: int):
		_release_input()
		_apply_boost(true))
	var pointer := CheckButton.new()
	pointer.text = "マウスへ追従"
	pointer.toggled.connect(func(value: bool):
		_follow_cursor = value
		if is_instance_valid(_hud): _hud.follow_cursor = value or _operating())
	_boost_row.add_child(pointer)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.text = "枠内でマウスへ移動。左クリック → 線を描く → もう一度クリックで突進。枠外で操作解除。「先頭へ」で位置とゲージを戻す。"
	add_child(_help)
	var aspect := AspectRatioContainer.new()
	_aspect = aspect
	aspect.ratio = 16.0 / 9.0
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(aspect)
	_frame = SubViewportContainer.new()
	_frame.stretch = true
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.gui_input.connect(_on_preview_input)
	_frame.mouse_entered.connect(func():
		if _ready_context(): _edit("pin",{"value":false,"position":_session.bridge.latest_frame().value.ui.ship.ship_pos})
		_pointer_inside = true)
	_frame.mouse_exited.connect(func():
		_pointer_inside = false
		_release_input())
	aspect.add_child(_frame)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(960, 540)
	_viewport.disable_3d = true
	_viewport.world_2d = World2D.new()
	_viewport.handle_input_locally = true
	_frame.add_child(_viewport)
	_viewport.size_changed.connect(_frame_changed)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_reward_parking.visible = false
	add_child(_reward_parking)
	_park_reward_surface()
	_refresh_mode()
	if _active: _build_context()

## 報酬は通常HUD自身のRewardPresentationへ重ねる。独立したlab状態だけを使う。
func set_reward_surface(surface: Control) -> void:
	_mode = "reward"
	_reward_surface = surface
	preview_paused = true
	if is_node_ready():
		_park_reward_surface()
		_refresh_mode()

func ensure_reward_context() -> bool:
	if _stage_ids.is_empty():
		_reward_failure("利用できるステージ定義がありません。仮の背景では再生しません。")
		return false
	var had_session := is_instance_valid(_session)
	set_active(true)
	if had_session and not _building and (_reward_stage_dirty or not _reward_problem.is_empty()): _build_context()
	return not _building and is_instance_valid(_session) and is_instance_valid(_hud) and _reward_problem.is_empty() and _reward_surface.get_parent() == _hud._rewards

func _park_reward_surface() -> void:
	if not is_instance_valid(_reward_surface): return
	if is_instance_valid(_hud) and _reward_surface.get_parent() == _hud._rewards:
		_hud._rewards.detach_authoring_surface()
	elif _reward_surface.get_parent() != null and _reward_surface.get_parent() != _reward_parking:
		_reward_surface.get_parent().remove_child(_reward_surface)
	if _reward_surface.get_parent() == null: _reward_parking.add_child(_reward_surface)

func release_reward_context() -> void:
	if _mode != "reward": return
	set_active(false)
	_park_reward_surface()
	_discard_context()
	_reward_building = false
	_reward_problem = ""
	_aspect.hide()
	_status.text = "再生画面を解放しました。再生・コマ送りで、選択中の実ステージ表示を再準備します。"

func set_idle_ui_active(active: bool) -> void:
	# 表示用ランを解放した後も、ステージ等の編集欄を操作できるようにする。
	_active = false
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _reward_failure(message: String) -> void:
	_building = false
	_reward_building = false
	_reward_problem = message
	_status.text = message
	if _mode == "reward":
		_aspect.hide()
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		reward_context_error.emit(message)

func _complete_reward_context() -> void:
	if _mode != "reward" or not _active or _reward_building or not _reward_problem.is_empty(): return
	if _reward_surface.get_parent() != _hud._rewards:
		_park_reward_surface()
		_reward_parking.remove_child(_reward_surface)
		if not _hud._rewards.attach_authoring_surface(_reward_surface):
			_reward_parking.add_child(_reward_surface)
			_reward_failure("報酬の再生面を通常HUDへ接続できません。")
			return
	_aspect.show()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_reward_stage_dirty = false
	_status.text = "生成済みの実ステージ・自機・敵・体力/EXP/装備/BOOSTの通常HUD。戦闘は停止。"
	reward_context_ready.emit()

## editorが保持する未保存Resourceを受け取る。読み直し・保存・bakeを行わない。
func set_landmark_settings(settings: EnemyMarkSettings) -> void:
	var changed := _mode != "landmark"
	_settings = settings
	_mode = "landmark"
	_configure_landmark_preview()
	if is_node_ready():
		if changed:
			_refresh_enemy_choices()
			_build_context()
		_refresh_mode()

func _configure_landmark_preview() -> void:
	if not is_instance_valid(_render): return
	var frames: Node2D = _render.frame_view
	if not is_instance_valid(_aura):
		var previous: Node2D = frames.landmark_aura
		_aura = AURA.new()
		_aura.settings = _settings
		_aura.z_index = previous.z_index
		previous.get_parent().add_child(_aura)
		_aura.setup(_session.resources)
		previous.free()
		frames.landmark_aura = _aura
	else:
		_aura.settings = _settings
		_aura.refresh()

func set_elite_settings(settings: EnemyMarkSettings) -> void:
	var changed := _mode != "elite"
	_elite_settings = settings
	_mode = "elite"
	if is_instance_valid(_render): _render.frame_view.elite_crackle.set_settings(settings, ELITE_AUTHORING_SHADER)
	if is_node_ready():
		if changed:
			_refresh_enemy_choices()
			_build_context()
		_refresh_mode()

func _refresh_enemy_choices() -> void:
	var previous: StringName = _enemy_ids[_enemy.selected] if not _enemy_ids.is_empty() and _enemy.selected >= 0 else &""
	var masks := load("res://assets/effects/landmark/masks.tres")
	var candidates: Array = masks.get_meta("candidates", [])
	var elites: Array = masks.get_meta("elite_candidates", [])
	_enemy_ids.clear()
	_enemy.clear()
	for key in ContentManager.enemies:
		var definition: EnemyDef = ContentManager.enemies[key]
		var eligible := definition.rank >= 2 and definition.rank <= 5
		if _mode in ["landmark", "elite"]: eligible = String(key) in candidates
		if eligible or (_mode == "elite" and String(key) in elites): _enemy_ids.append(StringName(key))
	_enemy_ids.sort()
	for key in _enemy_ids: _enemy.add_item(ContentManager.enemies[key].display_name)
	var preferred: StringName = previous if previous in _enemy_ids else &"pulser" if _mode == "elite" else &"telescope"
	if preferred in _enemy_ids: _enemy.select(_enemy_ids.find(preferred))

func set_boost_values(values: Dictionary) -> void:
	_boost_values = values.duplicate(true)
	_has_boost_values = true
	var changed := _mode != "boost"
	_mode = "boost"
	if is_instance_valid(_hud): _hud.preview_values = _boost_values
	if is_node_ready():
		if changed:
			_refresh_enemy_choices()
			_build_context()
		_refresh_mode()
		_apply_boost()

func set_active(active: bool) -> void:
	if not active: _release_input()
	_active = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if not is_node_ready(): return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active and _building: _discard_context()
	if active and not is_instance_valid(_session): _build_context()

func _refresh_mode() -> void:
	_enemy_row.visible = _mode in ["landmark", "elite", "reward"]
	_elite_landmark.visible = _mode == "elite"
	_boost_row.visible = _mode == "boost"
	_pause_control.visible = _mode != "reward"
	_restart_control.visible = _mode != "reward"
	_frame.focus_mode = Control.FOCUS_ALL if _mode == "reward" else Control.FOCUS_NONE
	_help.visible = _operating()
	if is_instance_valid(_hud): _apply_boost()

func _discard_context() -> void:
	_build_serial += 1
	_building = false
	_reward_building = false
	_input = null
	if is_instance_valid(_session): _session.free()
	_session = null
	_render = null
	_hud = null
	_aura = null
	_target = -1

func _build_context() -> void:
	if not _active or _stage_ids.is_empty() or _enemy_ids.is_empty(): return
	_release_input()
	_park_reward_surface()
	_discard_context()
	var serial := _build_serial
	_building = true
	_reward_building = _mode == "reward"
	_reward_problem = ""
	_reward_stage_dirty = true
	_status.text = "選択中のステージと敵の表示を準備しています。"
	var index := _stage_ids[_stage.selected]
	var path := "res://.content/stage_%d.tres" % index
	# 通常出撃の生成物とSourceは編集しない。明示した選択変更だけで制作コピーを変換する。
	_source = ResourceLoader.load(path) as RuntimeStage if ResourceLoader.exists(path) else null
	if _source == null:
		_reward_failure("生成済みステージがありません: " + path)
		_building = false
		return
	_source = _source.duplicate(true) as RuntimeStage
	_source.resources = _source.resources.duplicate(true)
	if ContentManager.visual_index == null:
		_reward_failure("生成済みの外観一覧がありません。")
		return
	_source.resources.look_paths.merge(ContentManager.visual_index.look_paths,false)
	_source.resources.look_names = ContentManager.visual_index.look_names.duplicate()
	_source.resources.enemy_ids = PackedStringArray([String(_enemy_ids[_enemy.selected])])
	_source.resources.paths = PackedStringArray()
	_source.phases.clear()
	_source.clips.clear()
	_source.zako_curves.clear()
	_source.scene_path = ""
	_source.boss_enabled = false
	_source.boss_id = &""
	_source.encounter_profile = {}
	_source.time_limit = -1.0
	_config = ContentManager.base.duplicate(true)
	_definitions = {}
	for id: String in _source.resources.enemy_ids:
		_definitions[StringName(id)] = ContentManager.enemies[StringName(id)].duplicate(true)
	var key := _enemy_ids[_enemy.selected]
	if _mode == "reward":
		var definition: EnemyDef = _definitions[key]
		var look := RunPresentation.load_look(key,_source)
		if look == null or not look.prepared or not look.previews.has(look.preview_key(definition.armor_colors)):
			_reward_failure("この敵の生成済み外観がありません。別の敵を選ぶか、既存の生成済み資源を準備してください。自動生成・仮図形への置換は行いません。")
			_building = false
			return
	var output := "res://.content/dev/context_%d_%d" % [OS.get_process_id(),get_instance_id()]
	var built: Error = BUILDER.build(_source,_config,output,"制作プレビュー".sha256_text(),_definitions)
	if built != OK:
		_reward_failure("選択した表示用データを準備できません: " + error_string(built))
		_building = false
		return
	var index_path := output.path_join("stage_%d.json" % index)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	_session = RunManager.create_session(_viewport,{"runtime":"cpp","cpp_index":index_path,"cpp_signature":manifest.input_sha256,
		"seed":932,"hud":false,"cpp_start":{"lab_mode":true},"cpp_profile":ProfileManager.for_cpp(true,{}),
		"cpp_edit_source":{"stage":_source,"config":_config,"definitions":_definitions}},true)
	_session.remove_from_group("recordable_runs")
	_session.auto_step = false
	var pending := _session
	while is_instance_valid(pending) and pending.bridge == null and pending.cpp_error == OK:
		await get_tree().process_frame
		if serial != _build_serial: return
	if serial != _build_serial: return
	_building = false
	if not is_instance_valid(pending) or pending.bridge == null:
		_reward_failure("C++の表示用ランを開始できません。")
		return
	# この独立セッションでは音声・録画・共有ランへの通知を使わない。
	_session.bridge.unsubscribe("audio")
	_session.bridge.unsubscribe("laser_audio")
	_input = _session.cpp_input_source.get_object() as InputRouter
	_input.set_process_input(false)
	_input.set_process_unhandled_input(false)
	if not _command("dev_set_scenario",{"kind":"lab","params":{"lab_mode":true,"auto_spawn":false,"auto_boss":false,"invincible":true,"enemy_ai":false}}).ok: return
	if not _command("dev_remove_weapon",{"id":"W01"}).ok: return
	var frame: Dictionary = _session.bridge.latest_frame()
	_origin = frame.value.ui.ship.ship_pos
	_render = _session.view.get_node("RunPresentation") as RunPresentation
	_render.frame_view.authoring_frame = _authoring_frame
	_render.cpp_background.set_manual(true)
	if _mode != "reward":
		# 変更した外観だけを明示的に再準備し、このSessionのScopeに保持する。
		for entry: Dictionary in _session.cpp_resources.visuals:
			if int(entry.role) != 6: continue
			var look: EnemyLook = _session.resources.resources.get(entry.path)
			if look == null: continue
			var definition: EnemyDef = _definitions.get(key)
			if definition != null and entry.path == _source.resources.look_paths.get(_source.enemy_sprite_path(key).get_file().get_basename(),""):
				_session.resources.provide(entry.path,LIVE_VISUALS.live_look(look,definition.armor_colors))
	if _mode == "landmark": _configure_landmark_preview()
	if _mode == "elite": _render.frame_view.elite_crackle.set_settings(_elite_settings,ELITE_AUTHORING_SHADER)
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	layer.layer = maxi(10,_session.cpp_resources.visuals.size()+8)
	_session.view.add_child(layer)
	_hud = HUD.new()
	_hud.bridge = _session.bridge
	_hud.cpp_scope = _session.resources
	_hud.cpp_resources = _session.cpp_resources
	_hud.config = _config
	_hud.reward_preview = _mode == "reward"
	_hud.preview_owned = _reward_surface.call("owned_snapshot").duplicate(true) if _mode == "reward" else {}
	_hud.follow_cursor = _follow_cursor
	_hud.preview_values = _boost_values if _has_boost_values else EFFECTS.values_for(GAUGE.KEY)
	layer.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.apply_snapshot(_session.bridge.latest_frame().value.ui)
	_place_context()
	_reward_building = false
	if _mode == "reward":
		_hud.preview_paused = true
		_complete_reward_context()
	else: _status.text = "本番の背景・星・船体・法線・HUD"

func _command(kind: String, payload := {}) -> Dictionary:
	if not is_instance_valid(_session) or _session.bridge == null: return {"ok":false}
	var result: Dictionary = _session.bridge.command(kind,payload)
	if not result.ok: _reward_failure(result.get("message","表示用ランの命令に失敗しました。"))
	return result

func _edit(kind: String, payload: Dictionary) -> Dictionary:
	return _command("dev_edit",{"kind":kind,"payload":payload})

func _ready_context() -> bool:
	return not _building and is_instance_valid(_session) and _session.bridge != null and is_instance_valid(_render)

func _place_context() -> void:
	if not _ready_context(): return
	_release_input()
	_center = _origin
	if _placement.selected == 1 and not _source.backgrounds.is_empty(): _center += _source.backgrounds[0].offset
	_edit("ship",{"position":_center+Vector2(-120,80),"gauge":1.0})
	_spawn_target()
	_frame_changed()

func _spawn_target() -> void:
	if not _ready_context() or _enemy_ids.is_empty(): return
	# 読取スナップショットのIDだけで片付ける。敵表のコピーをゲーム状態にしない。
	var snapshot: Dictionary = _session.bridge.read_lab()
	if not snapshot.ok: return
	for enemy: Dictionary in snapshot.value.enemies:
		_command("dev_remove",{"entity_id":int(enemy.id)})
	var key := _enemy_ids[_enemy.selected]
	var definition: EnemyDef = _definitions.get(key)
	if definition == null: return
	var result := _command("dev_spawn",{"definition_id":String(key),"position":_center+Vector2(70,0),"facing":-PI/2.0,"elite":_mode=="elite"})
	_target = int(result.value) if result.ok else -1
	_form.visible = definition.behavior == &"ruler"
	_pump.visible = definition.behavior == &"pump"
	_apply_boost(true)
	_complete_reward_context()

func _apply_pump() -> void:
	if is_instance_valid(_render): _render.frame_view.queue_redraw()

func _apply_boost(reset_operation := false) -> void:
	if not is_instance_valid(_hud): return
	_hud.preview_mode = _boost.selected
	_hud.follow_cursor = _follow_cursor or _operating()
	_help.visible = _operating()
	if _operating() and reset_operation:
		_edit("ship",{"position":_session.bridge.latest_frame().value.ui.ship.ship_pos,"gauge":1.0,"capacity":1.5})

## 形態や膨張、確認用の線は表示だけに反映する。選択した敵のC++状態は変えない。
func _authoring_frame(frame: Dictionary) -> Dictionary:
	var shown: Dictionary = frame.duplicate()
	shown.batches = []
	for source: Dictionary in frame.batches:
		var row: Dictionary = source.duplicate()
		if row.has("marks"):
			var marks := PackedInt32Array()
			for _id: int in row.ids:
				marks.append((1 if _mode=="landmark" or (_mode=="elite" and _elite_landmark.button_pressed) else 0) | (2 if _mode=="elite" else 0))
			row.marks = marks
		if row.has("ruler_sides"):
			var sides: PackedInt32Array = row.ruler_sides.duplicate()
			for i in sides.size(): sides[i] = 0 if _form.selected==0 else -1 if _form.selected==1 else 1
			row.ruler_sides = sides
		if row.has("pump"):
			var pump: PackedFloat32Array = row.pump.duplicate()
			for i in range(0,pump.size(),9):
				pump[i+4] = _pump.value
				pump[i+6] = _clock
				pump[i+8] = 0.0 if _pump.value>=1.0 else 1.0
			row.pump = pump
		shown.batches.append(row)
	if _mode=="boost" and _boost.selected==2:
		var at: Vector2 = _session.bridge.latest_frame().value.ui.ship.ship_pos
		shown.shapes = frame.shapes.duplicate()
		shown.shapes.append({"kind":0,"layer":12,"order":0,"owner_id":0,
			"points":PackedVector2Array([at+Vector2(20,-30),at+Vector2(100,-110),at+Vector2(180,-90)]),
			"offsets":PackedInt32Array([0,3]),"widths":PackedFloat32Array([3.64]),"colors":PackedColorArray([Color("#8feaff")])})
	return shown

func _frame_changed() -> void:
	if not _ready_context(): return
	var shown := Vector2(_viewport.size)
	var factor := pow(_config.zoom_ref_speed/maxf(_config.zoom_ref_speed,_config.base_max_speed),_config.zoom_exp)
	var zoom := minf(shown.x,shown.y)/_config.base_view*clampf(factor,_config.zoom_min,1.0)
	var center: Vector2 = _session.bridge.latest_frame().value.ui.ship.ship_pos if _operating() else _center
	_render.view_override = {"center":center,"zoom":zoom}
	_edit("camera",{"center":center,"zoom":zoom,"size":shown,"bars":0.0})
	_hud.preview_cursor = shown*Vector2(0.68,0.62)

func preview_restart() -> void:
	_clock = 0.0
	_accumulator = 0.0
	if _operating(): _place_context()
	if is_instance_valid(_render): _render.cpp_background.restart()
	preview_step(0.0)

func preview_step(delta: float) -> void:
	if not _ready_context() or not is_instance_valid(_hud): return
	if _mode != "reward": _clock += delta
	_render.frame_view.authoring_clock = _clock
	_render.frame_view.authoring_paused = preview_paused or _mode=="reward"
	_hud.preview_clock = _clock
	_hud.preview_paused = preview_paused or _mode=="reward"
	_hud.queue_redraw()
	if delta>0.0: _render.cpp_background.advance(delta)

func _process(delta: float) -> void:
	preview_step(0.0 if preview_paused else delta)

func _operating() -> bool:
	return _mode == "boost" and _boost.selected == OPERATION_MODE

func _on_preview_input(event: InputEvent) -> void:
	if _mode == "reward":
		if event is InputEventMouseButton and event.pressed: _frame.grab_focus()
		return
	if not _active or not _operating() or preview_paused or not _ready_context(): return
	if not (event is InputEventMouseMotion or event is InputEventMouseButton): return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT: return
	var local_event := event.duplicate() as InputEvent
	var factor := Vector2(_viewport.size)/_frame.size.max(Vector2.ONE)
	if local_event is InputEventMouse: local_event.position *= factor
	if not _pointer_inside: _edit("pin",{"value":false,"position":_session.bridge.latest_frame().value.ui.ship.ship_pos})
	_pointer_inside = true
	_input._input(local_event)
	_input._unhandled_input(local_event)
	_frame.accept_event()

func _release_input() -> void:
	_pointer_inside = false
	_accumulator = 0.0
	if is_instance_valid(_input): _input.cancel_gesture()
	if not _ready_context(): return
	_edit("finish_input",{})
	_edit("pin",{"value":true,"position":_session.bridge.latest_frame().value.ui.ship.ship_pos})

func _physics_process(delta: float) -> void:
	if not _active or not _operating() or preview_paused or not _ready_context(): return
	# 本番と同じ固定更新だけを使う。枠外では自機を固定して充填を続ける。
	_accumulator += delta
	while _accumulator>=DT:
		_accumulator -= DT
		var result: Dictionary
		if _pointer_inside:
			result = _session.bridge.poll_and_step(DT,_session.cpp_input_source,Vector2(_viewport.size))
		else:
			result = _session.bridge.step(DT,preload("res://scripts/runtime/run_bridge.gd").pack_intent(Intent.new()),{"logical_size":Vector2(_viewport.size)})
		if not result.ok:
			_reward_failure(result.message)
			return
	_frame_changed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _release_input()

func _exit_tree() -> void:
	_release_input()
	_build_serial += 1
