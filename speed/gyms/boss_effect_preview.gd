## 戦闘エフェクト画面に本番描画を映し、装備または選択技を試遊する。
extends VBoxContainer
const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase

const ROOT := "res://scenes/bosses/"
const BOSS_PROGRAM := preload("res://tools/content/build_boss_program.gd")
const EQUIPMENT := preload("res://gyms/equipment_effect_scenario.gd")
const SESSION := preload("res://gyms/enemy_lab/lab_session.gd")
const MANUAL := preload("res://gyms/boss_technique_debug.gd")
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
const SPEEDS := [0.25, 0.5, 1.0, 2.0, 4.0]
const FINAL_BOSSES := ["canis_major", "centaurus", "monoceros"]
const FINAL_BOSS_NAMES := ["おおいぬ座", "ケンタウルス座", "いっかくじゅう座"]

var session
var manual
var _viewport: SubViewport
var _frame: SubViewportContainer
var _status := Label.new()
var _play := Button.new()
var _speed := OptionButton.new()
var _loadout_row := HBoxContainer.new()
var _weapon_name := Label.new()
var _trait_name := Label.new()
var _clear_weapon := Button.new()
var _clear_trait := Button.new()
var _weapon_key := ""
var _trait_key := ""
var _preview_trait := false
var _post_effect := OptionButton.new()
var _post_count := SpinBox.new()
var _post_ids: Array[String] = []
var _post_max := {}
var _equipment_level := OptionButton.new()
var _trait_level := OptionButton.new()
var _final_picker := OptionButton.new()
var _boss := ""
var _technique := ""
var _equipment_key := ""
var _enemy_key := ""
var _enemy_id := -1
var _final_preview := false
var _final_boss := "canis_major"
var _serial := 0
var _visual_time := 0.0
var _preview_origin := Vector2.ZERO
var _preview_heading := Vector2.RIGHT
var _loop_seconds := 0.0
var _boss_frame := Rect2()
var _boss_frame_ready := false
var _preview_target := Vector2.ZERO
## 装備の試遊で映す世界の横幅（演出の試作の画面は横300ドット＝約710）
const EQUIPMENT_VIEW_WIDTH := 1000.0
var _dragging_origin := false

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var controls := HBoxContainer.new()
	add_child(controls)
	_play.text = "▶"
	_play.tooltip_text = "再生"
	_play.custom_minimum_size.x = 36
	_play.pressed.connect(_toggle_play)
	controls.add_child(_play)
	var step := Button.new()
	step.text = "⏭"
	step.tooltip_text = "1コマ進める"
	step.custom_minimum_size.x = 36
	step.pressed.connect(_step)
	controls.add_child(step)
	var replay := Button.new()
	replay.text = "⏮"
	replay.tooltip_text = "先頭から再生し直す"
	replay.custom_minimum_size.x = 36
	replay.pressed.connect(_replay)
	controls.add_child(replay)
	for value in SPEEDS:
		_speed.add_item(str(value) + "×")
	_speed.select(2)
	_speed.tooltip_text = "再生速度"
	_speed.item_selected.connect(func(index: int): session.speed = SPEEDS[index])
	controls.add_child(_speed)
	var add_enemy := Button.new()
	add_enemy.text = "敵を追加"
	add_enemy.pressed.connect(_add_preview_enemies)
	controls.add_child(add_enemy)
	add_child(_loadout_row)
	_loadout_row.visible = false
	_loadout_row.add_child(_weapon_name)
	_weapon_name.clip_text = true
	_weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for level in range(1,6): _equipment_level.add_item("Lv%d" % level)
	_equipment_level.select(4)
	_equipment_level.tooltip_text = "試遊する武器のレベル"
	_equipment_level.item_selected.connect(func(_index: int): _change_loadout())
	_loadout_row.add_child(_equipment_level)
	_clear_weapon.text = "×"
	_clear_weapon.tooltip_text = "試遊から武器を外す"
	_clear_weapon.pressed.connect(func():
		_weapon_key = ""
		_change_loadout())
	_loadout_row.add_child(_clear_weapon)
	_loadout_row.add_child(_trait_name)
	_trait_name.clip_text = true
	_trait_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for level in range(1,6): _trait_level.add_item("Lv%d" % level)
	_trait_level.select(4)
	_trait_level.tooltip_text = "試遊する特性のレベル"
	_trait_level.item_selected.connect(func(_index: int): _change_loadout())
	_loadout_row.add_child(_trait_level)
	_clear_trait.text = "×"
	_clear_trait.tooltip_text = "試遊から特性を外す"
	_clear_trait.pressed.connect(func():
		_trait_key = ""
		_change_loadout())
	_loadout_row.add_child(_clear_trait)
	var post_label := Label.new()
	post_label.text = "最大後"
	_loadout_row.add_child(post_label)
	for id in ContentManager.base.post_max.increments:
		if String(id)=="heal": continue
		_post_ids.append(String(id))
		_post_effect.add_item(tr("postmax."+String(id)))
	_loadout_row.add_child(_post_effect)
	_post_count.min_value = 0
	_post_count.max_value = 1000
	_post_count.step = 1
	_post_count.tooltip_text = "この試遊だけに適用する追加強化の段数"
	_loadout_row.add_child(_post_count)
	_post_effect.item_selected.connect(func(index: int): _post_count.set_value_no_signal(int(_post_max.get(_post_ids[index],0))))
	_post_count.value_changed.connect(func(value: float):
		var id: String = _post_ids[_post_effect.selected]
		if value<=0: _post_max.erase(id)
		else: _post_max[id] = int(value)
		_change_loadout())
	_refresh_equipment_labels()
	for boss_name in FINAL_BOSS_NAMES:
		_final_picker.add_item(boss_name)
	_final_picker.visible = false
	_final_picker.item_selected.connect(func(index: int):
		_final_boss = FINAL_BOSSES[index]
		if _final_preview: set_effect("boss/final_strike"))
	controls.add_child(_final_picker)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(aspect)
	_frame = SubViewportContainer.new()
	_frame.stretch = true
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.tooltip_text = "左ドラッグ: 発生位置を移動 / 右クリック: 発生方向を指定"
	_frame.gui_input.connect(_on_preview_input)
	var frame_material := ShaderMaterial.new()
	frame_material.shader = preload("res://shaders/lab_viewport.gdshader")
	_frame.material = frame_material
	aspect.add_child(_frame)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.disable_3d = true
	_viewport.handle_input_locally = false
	_viewport.audio_listener_enable_2d = true
	_frame.add_child(_viewport)
	_status.text = "ボス技を選択してください"
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_status)
	session = SESSION.new()
	session.viewport = _viewport
	add_child(session)

func _refresh_equipment_labels() -> void:
	_weapon_name.text = "武器"
	_trait_name.text = "特性"
	_weapon_name.tooltip_text = _equipment_name(_weapon_key)
	_trait_name.tooltip_text = _equipment_name(_trait_key)
	_weapon_name.visible = not _weapon_key.is_empty()
	_trait_name.visible = not _trait_key.is_empty()
	_equipment_level.visible = not _weapon_key.is_empty()
	_trait_level.visible = not _trait_key.is_empty()
	_clear_weapon.visible = not _weapon_key.is_empty()
	_clear_trait.visible = not _trait_key.is_empty()

func _sync_play_button() -> void:
	_play.text = "⏸" if session != null and session.playing else "▶"
	_play.tooltip_text = "一時停止" if session != null and session.playing else "再生"

func _equipment_name(path: String) -> String:
	if path.is_empty(): return "なし"
	var category: StringName = &"traits" if path.begins_with("trait/") else &"weapons"
	var definition: Resource = ContentManager.catalog.table(category).get(_equipment_id(path))
	return definition.get_display_name() if definition != null else path

func _select_equipment_for_effect(path: String) -> void:
	if path.begins_with("weapon/"):
		_weapon_key = path
		_preview_trait = false
	else:
		_trait_key = path
		_preview_trait = true
		if _weapon_key.is_empty() and (path in EQUIPMENT.PASSIVE_KEYS or path in ["trait/fullBurst", "trait/duplicator"]):
			_weapon_key = "weapon/endBlast" if path == "trait/bigSwing" else "weapon/forward"
	_refresh_equipment_labels()

func _equipment_id(key: String) -> StringName:
	if key.is_empty(): return &""
	var category: StringName = &"traits" if key.begins_with("trait/") else &"weapons"
	var table: Dictionary = ContentManager.catalog.table(category)
	for id in table:
		if String(table[id].code_id) == key.get_slice("/", 1):
			return id
	return &""

func set_effect(path: String, resume: Variant = null) -> void:
	var keep_playing: bool = session.playing if resume == null else bool(resume)
	_serial += 1
	var serial := _serial
	_loop_seconds = 0.0
	_boss_frame_ready = false
	if manual != null: manual.finish()
	manual = null
	if path != _equipment_key and (path.begins_with("weapon/") or path.begins_with("trait/")):
		_select_equipment_for_effect(path)
	elif not path.begins_with("weapon/") and not path.begins_with("trait/"):
		_weapon_key = ""
		_trait_key = ""
	_equipment_key = ""
	_enemy_key = ""
	_loadout_row.visible = path.begins_with("weapon/") or path.begins_with("trait/")
	_refresh_equipment_labels()
	_final_preview = path == "boss/final_strike"
	_final_picker.visible = _final_preview
	_set_scene_processing(false)
	session.playing = false
	_sync_play_button()
	if path.begins_with("weapon/") or path.begins_with("trait/"):
		_equipment_key = path
		await _setup_equipment(path, serial, keep_playing)
		return
	if path.begins_with("enemy/"):
		_enemy_key = path
		await _setup_enemy(serial, keep_playing)
		return
	if _final_preview:
		_boss = _final_boss
		_technique = "final_strike"
	elif path.begins_with("boss/move/"):
		var parts := path.split("/")
		if parts.size() != 4: return
		_boss = parts[2]
		_technique = parts[3]
	else:
		# 本体表示の入口だけは既存scene参照を受け、登録された技IDへ解決する。
		var parts := path.trim_prefix(ROOT).split("/")
		if not path.begins_with(ROOT) or parts.size() != 2:
			_boss = ""
			_technique = ""
			_status.text = "ボス技の描画を選ぶと実戦プレビューを表示します"
			return
		_boss = parts[0]
		_technique = ""
		var rules: Resource = load("res://data/bosses/ai/%s_action_rules.tres" % _boss)
		if rules != null:
			for move: Resource in rules.get("techniques"):
				if move != null and move.visual != null and move.visual.resource_path == path:
					_technique = String(move.technique)
					break
		if _technique.is_empty():
			_status.text = "この表示に対応する登録技がありません: " + path
			return
	if not ContentManager.bosses.has(StringName(_boss)):
		_status.text = "登録されていないボス: " + _boss
		return
	var stage: int = {"hydra": 4, "draco": 5, "centaurus": 2, "canis_major": 3}.get(_boss, 1)
	var settings := {"empty": true, "stage": stage, "ship_pos": [400, 0] if _boss == "hydra" else [500, 0],
		"invincible": true, "director": {"enabled": false}}
	if _boss == "hydra":
		settings["hero"] = "hercules"
		settings["config"] = {"base_attack": ContentManager.base.base_attack * 6.0}
	_status.text = "ボス技を準備中: %s / %s" % [_boss, _technique]
	await session.reset(settings)
	if serial != _serial: return
	_pause_render_process()
	var program_path := "res://.content/boss_%s.tres" % _boss
	var built: Dictionary = BOSS_PROGRAM.build_boss(_boss, program_path)
	if built.get("error", ERR_INVALID_DATA) != OK:
		_status.text = "ボス技データを生成できません: " + program_path
		return
	if not ResourceLoader.exists(program_path):
		_status.text = "ボス技データを読めません: " + program_path
		return
	var program: Resource = ResourceLoader.load(program_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if program == null or program.get("data") is not Dictionary or program.data.get("rules") == null:
		_status.text = "ボス技データが不正です: " + program_path
		return
	session.perform("boss", {"type": _boss, "pos": [0, 0]})
	if session._selected_id < 0:
		_status.text = "ボスを配置できません: " + _boss
		return
	_preview_target = session.run.state.ship_pos
	var hud: CanvasLayer = session.scene.view.get_node_or_null("Hud") if session.scene.view != null else null
	if hud != null: hud.visible = false
	var debugger := MANUAL.new()
	if debugger.bind(session,_boss,program): manual = debugger
	if manual == null:
		_status.text = "ボスの試行入口を準備できません: " + _boss
		return
	if _final_preview: _start_final_strike(keep_playing)
	else: _execute_selected(keep_playing)

func _start_final_strike(keep_playing: bool) -> void:
	if manual == null: return
	var result: Dictionary = session.bridge.command("dev_boss_final",{"entity_id":manual.entity_id,"charge":session.run.cfg.time_up_charge_time})
	if not result.ok:
		_status.text = result.message
		return
	session._refresh_projection()
	session.bridge.collect_frame()
	session.playing = keep_playing
	_set_scene_processing(keep_playing)
	_sync_play_button()
	_status.text = "制限時間の一撃: " + FINAL_BOSS_NAMES[FINAL_BOSSES.find(_boss)]
	refresh_effects()

func _setup_equipment(_key: String, serial: int, keep_playing: bool) -> void:
	var weapon_key := _weapon_key
	var trait_key := _trait_key
	var weapon_id := _equipment_id(weapon_key)
	var trait_id := _equipment_id(trait_key)
	if (not weapon_key.is_empty() and weapon_id == &"") or (not trait_key.is_empty() and trait_id == &""):
		_status.text = "試遊装備が見つかりません"
		return
	var no_equipment := weapon_key.is_empty() and trait_key.is_empty()
	var play_trait := _preview_trait
	if (play_trait and trait_key.is_empty()) or (not play_trait and weapon_key.is_empty()):
		play_trait = weapon_key.is_empty()
	var play_key := trait_key if play_trait else weapon_key
	var play_id := trait_id if play_trait else weapon_id
	var catalog: Dictionary = ContentManager.catalog.table(&"traits" if play_trait else &"weapons")
	_status.text = "試遊を準備中: " + play_key
	var settings := {"empty": true, "stage": 1, "ship_pos": [_preview_origin.x, _preview_origin.y], "invincible": true,
		"director": {"enabled": false}, "weapons": {}, "traits": {}}
	settings.post_max = _post_max.duplicate(true)
	if weapon_id != &"": settings["weapons"] = {weapon_id: _equipment_level.selected + 1}
	if trait_id != &"": settings["traits"] = {trait_id: _trait_level.selected + 1}
	await session.reset(settings)
	if serial != _serial: return
	if session.bridge==null:
		_status.text = "試遊を開始できません"
		return
	_pause_render_process()
	if no_equipment:
		_set_scene_processing(false)
		_status.text = "試遊する武器・特性を選んでください"
		refresh_effects()
		return
	var owned: Dictionary = session.run.state.traits if play_trait else session.run.state.weapons
	if not owned.has(play_id):
		_status.text = "装備を試遊へ設定できません: " + play_key
		return
	if not EQUIPMENT.play(session, play_key, false, _preview_heading):
		_status.text = "装備の試行条件を適用できません"
		return
	_flush_preview_events()
	_show_effect_canvas()
	session.playing = keep_playing
	_set_scene_processing(keep_playing)
	_sync_play_button()
	_status.text = "%s / Lv%d を試遊" % [catalog[play_id].get_display_name(), _trait_level.selected + 1 if play_trait else _equipment_level.selected + 1]
	if not weapon_key.is_empty() and not trait_key.is_empty(): _status.text += "（武器・特性を併用）"
	if _equipment_key not in [weapon_key, trait_key]: _status.text += "（編集中の効果は未装備）"
	if play_key in ["weapon/knockback","trait/duplicator"]: _status.text += "（試遊では確率の演出を必ず発動）"
	refresh_effects()

func _setup_enemy(serial: int, keep_playing: bool) -> void:
	var type := _enemy_key.get_slice("/", 1)
	_boss = ""
	_technique = ""
	_status.text = "敵の技を準備中: " + type
	await session.reset({"empty": true, "stage": 1, "ship_pos": [400, 0], "invincible": true, "director": {"enabled": false}})
	if serial != _serial: return
	_pause_render_process()
	session.perform("spawn", {"type": type, "pos": [0, 0], "count": 1})
	_enemy_id = session._selected_id
	if _enemy_id < 0:
		_status.text = "敵を配置できません: " + type
		return
	_preview_target = session.run.state.ship_pos
	_boss_frame_ready = false
	session.playing = keep_playing
	_set_scene_processing(keep_playing)
	_sync_play_button()
	_status.text = "敵の行動と専用の描画を試遊: " + type
	refresh_effects()

func _show_effect_canvas() -> void:
	if not is_instance_valid(session.scene) or session.scene.view == null: return
	var render := _render()
	if render == null: return
	var hud: CanvasLayer = session.scene.view.get_node_or_null("Hud")
	if hud != null: hud.visible = false
	if render.cpp_background!=null: render.cpp_background.visible = false

func _flush_preview_events() -> void:
	if session.bridge!=null: session.bridge.collect_frame()

func _on_preview_input(event: InputEvent) -> void:
	if _equipment_key.is_empty() or not is_instance_valid(session.run): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging_origin = true
				session.playing = false
				_set_scene_processing(false)
				_sync_play_button()
			elif _dragging_origin:
				_dragging_origin = false
				set_effect(_equipment_key, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var center: Vector2 = _frame.size * 0.5
			var zoom: float = 1280.0/EQUIPMENT_VIEW_WIDTH
			var fit: float = minf(_frame.size.x / 1280.0, _frame.size.y / 720.0)
			var target: Vector2 = center + (_preview_origin - _render().cam_center) * zoom * fit
			var direction: Vector2 = event.position - target
			if direction.length_squared() > 16.0:
				_preview_heading = direction.normalized()
				set_effect(_equipment_key, false)
	elif event is InputEventMouseMotion and _dragging_origin:
		var zoom: float = 1280.0/EQUIPMENT_VIEW_WIDTH
		var fit: float = minf(_frame.size.x / 1280.0, _frame.size.y / 720.0)
		_preview_origin += event.relative / maxf(zoom * fit, 0.01)
		session.perform("ship",{"pos":_preview_origin})
		_status.text = "発生位置を移動中"
		refresh_effects()

func _change_loadout() -> void:
	if not _equipment_key.is_empty(): set_effect(_equipment_key)

func _replay() -> void:
	if not _enemy_key.is_empty():
		set_effect(_enemy_key, false)
		return
	if not _equipment_key.is_empty():
		set_effect(_equipment_key, false)
		return
	if _final_preview:
		set_effect("boss/final_strike", false)
		return
	_execute_selected(false)

func _execute_selected(keep_playing: bool) -> void:
	if manual == null: return
	var phase := 4 if _boss=="hydra" and _technique in ["grid","swarm"] else 3 if _boss=="hydra" else 1
	if _boss=="hydra": session.perform("loadout",{"reset":true})
	var started: bool = manual.execute(_technique,phase,true)
	if started:
		# 構図の基準だけを記録する。吸引・吐出による標的の移動は本番処理へ任せる。
		_preview_target = session.run.state.ship_pos
		_boss_frame_ready = false
		session.playing = keep_playing
		_set_scene_processing(keep_playing)
		_sync_play_button()
		_status.text = "%s / %s を試遊" % [_boss, _technique]
		refresh_effects()
	else:
		_status.text = "この技は単独再生できません: %s / %s" % [_boss, _technique]
		if manual != null and not manual.message.is_empty(): _status.text += " / " + manual.message

func refresh_effects() -> void:
	var render := _render()
	if render == null: return
	_refresh_scene_visuals(session.scene.view)
	_update_preview_camera(render)
	render._present_cpp(0.0)
	_hide_preview_hud()
	if not _equipment_key.is_empty(): _show_effect_canvas()
	_sync_preview_shader_time(session.scene.view)

func _hide_preview_hud() -> void:
	if not is_instance_valid(session.scene) or session.scene.view == null: return
	var hud: CanvasLayer = session.scene.view.get_node_or_null("Hud")
	if hud != null: hud.visible = false

func _refresh_scene_visuals(node: Node) -> void:
	if node is CanvasItem and node.has_meta("shader_tuning_profile"):
		ShaderTuning.apply((node as CanvasItem).material as ShaderMaterial, node.get_meta("shader_tuning_profile"), node.get_meta("shader_tuning_fallback", ""), node.get_meta("shader_tuning_component", ""))
	if node is AttackVisual:
		(node as AttackVisual)._apply_effect_settings()
	elif node is CanvasItem:
		EFFECT_SETTINGS.apply_to(node as CanvasItem)
	if node.has_method("refresh_visual_settings"): node.refresh_visual_settings()
	if node is CanvasItem: (node as CanvasItem).queue_redraw()
	for child in node.get_children(): _refresh_scene_visuals(child)

func _render() -> RunPresentation:
	if not is_instance_valid(session) or not is_instance_valid(session.scene) or not is_instance_valid(session.scene.view): return null
	return session.scene.view.get_node_or_null("RunPresentation") as RunPresentation

func _pause_render_process() -> void:
	var render := _render()
	if render != null:
		render.set_process(false)

func _set_scene_processing(playing: bool) -> void:
	if is_instance_valid(session.scene):
		session.scene.process_mode = Node.PROCESS_MODE_INHERIT if playing else Node.PROCESS_MODE_DISABLED

func _sync_preview_shader_time(node: Node) -> void:
	var canvas := node as CanvasItem
	if canvas != null and canvas.material is ShaderMaterial:
		var material := canvas.material as ShaderMaterial
		if material.shader != null and material.shader.resource_path in ["res://shaders/picaro.gdshader", "res://shaders/water_flood.gdshader"]:
			material.set_shader_parameter("preview_clock", _visual_time)
	for child in node.get_children(): _sync_preview_shader_time(child)

func _toggle_play() -> void:
	if session == null or not is_instance_valid(session.run): return
	session.playing = not session.playing
	_set_scene_processing(session.playing)
	_sync_play_button()

func _process(_delta: float) -> void:
	if not is_instance_valid(session) or not is_instance_valid(session.run): return
	if manual != null: manual.advance()
	var render: RunPresentation = session.scene.view.get_node_or_null("RunPresentation") if session.scene.view != null else null
	if render == null: return
	_update_preview_camera(render)
	if session.playing:
		_visual_time += _delta * session.speed
		render._present_cpp(_delta * session.speed)
		_hide_preview_hud()
		if not _equipment_key.is_empty() or not _enemy_key.is_empty():
			if not _equipment_key.is_empty(): _show_effect_canvas()
			_loop_seconds += _delta * session.speed
			if _loop_seconds >= 10.0:
				set_effect(_enemy_key if not _enemy_key.is_empty() else _equipment_key, true)
				return
	_sync_preview_shader_time(session.scene.view)
	(_frame.material as ShaderMaterial).set_shader_parameter("convert_hdr", _viewport.use_hdr_2d and not get_viewport().use_hdr_2d)

## ボスと技の範囲を映す、このプレビューだけのカメラ。標的や本編のカメラ状態を追わない。
func _update_preview_camera(render: RunPresentation) -> void:
	if not _equipment_key.is_empty():
		var fit := minf(_frame.size.x / 1280.0, _frame.size.y / 720.0)
		render.view_override = {"center": session.run.state.ship_pos, "zoom": 1280.0 / EQUIPMENT_VIEW_WIDTH * fit, "shake": false}
		return
	var origin := Vector2.ZERO
	var body_radius := 180.0
	if not _enemy_key.is_empty():
		var snapshot: Dictionary = session.bridge.read_lab()
		if snapshot.ok:
			for enemy: Dictionary in snapshot.value.enemies:
				if enemy.id == _enemy_id:
					origin=enemy.pos
					body_radius=maxf(body_radius,float(enemy.r))
					break
	else:
		var body: Dictionary = manual.body_snapshot() if manual != null else {}
		if body.is_empty() or not body.has("position"): return
		origin = body.position
		body_radius = maxf(body_radius,float(body.get("radius",0.0)))
	if not _boss_frame_ready:
		var width := 2800.0 if _boss == "hydra" else 1800.0
		var size := Vector2(width, width * 9.0 / 16.0)
		_boss_frame = Rect2((origin + _preview_target) * 0.5 - size * 0.5, size)
		_boss_frame_ready = true
	_boss_frame = _boss_frame.merge(Rect2(origin, Vector2.ZERO).grow(body_radius + 100.0))
	# 本番の描画値を読むだけにし、敵表や攻撃状態をプレビューへ複製しない。
	var read: Dictionary = session.bridge.read_render(_boss_frame.grow(10000.0),1.0)
	if read.ok:
		for shape: Dictionary in read.value.get("shapes",[]):
			var margin := 100.0
			for width in shape.get("widths",PackedFloat32Array()): margin=maxf(margin,float(width))
			for point: Vector2 in shape.get("points",PackedVector2Array()): _fit_point(point,margin)
		for technique: Dictionary in read.value.get("boss_techniques",[]): _fit_geometry(technique)
		for body: Dictionary in read.value.get("boss_bodies",[]):
			_fit_geometry(body)
			if body.has("position"): _fit_point(body.position,float(body.get("radius",100.0)))
			for point: Vector2 in body.get("last_slash",PackedVector2Array()): _fit_point(point,100.0)
			if body.get("mode",-1)==3 and body.has("final_to"): _fit_point(body.final_to,float(body.get("final_width",100.0)))
	# 一回の試行中は範囲を広げるだけにし、攻撃が消える瞬間の急なズームを避ける。
	var zoom := minf(_frame.size.x / _boss_frame.size.x, _frame.size.y / _boss_frame.size.y)
	render.view_override = {"center": _boss_frame.get_center(), "zoom": maxf(zoom, 0.001), "shake": false}

## 制作用カメラは描画の位置だけを使い、方向・速度・倍率は範囲へ入れない。
func _fit_geometry(value: Dictionary) -> void:
	var margin := maxf(100.0,float(value.get("radius",value.get("width",0.0))))
	for key in value:
		var item = value[key]
		if item is Vector2 and String(key) in ["position","pos","start","end","center","target","origin","from","to","aim","free_pos","leap_from","leap_to"]:
			_fit_point(item,margin)
		elif item is PackedVector2Array and String(key) in ["points","line","path","targets","attack_points","last_slash"]:
			for point: Vector2 in item: _fit_point(point,margin)
		elif item is Dictionary: _fit_geometry(item)
		elif item is Array:
			for child in item:
				if child is Dictionary: _fit_geometry(child)

func _fit_point(point: Vector2, margin: float) -> void:
	_boss_frame = _boss_frame.merge(Rect2(point,Vector2.ZERO).grow(maxf(100.0,margin)))

func _step() -> void:
	if session == null or not is_instance_valid(session.run): return
	session.playing = false
	_set_scene_processing(false)
	_sync_play_button()
	session.step()
	refresh_effects()

func set_active(active: bool) -> void:
	if not active and session != null:
		session.playing = false
		_set_scene_processing(false)
		_sync_play_button()
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED

func _exit_tree() -> void:
	if manual != null: manual.finish()

func _add_preview_enemies() -> void:
	if _equipment_key.is_empty() or not is_instance_valid(session.run): return
	var origin: Vector2 = session.run.state.ship_pos
	for offset in [Vector2(180,0),Vector2(240,80),Vector2(240,-80)]:
		EQUIPMENT.spawn(session,origin+offset.rotated(_preview_heading.angle()))
	refresh_effects()
