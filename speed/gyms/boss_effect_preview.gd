## 戦闘エフェクト画面に本番描画を映し、装備または選択技を試遊する。
extends VBoxContainer

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
var actor
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
var _equipment_level := OptionButton.new()
var _trait_level := OptionButton.new()
var _final_picker := OptionButton.new()
var _boss := ""
var _technique := ""
var _equipment_key := ""
var _final_preview := false
var _final_boss := "canis_major"
var _serial := 0
var _visual_time := 0.0
var _preview_origin := Vector2.ZERO
var _preview_heading := Vector2.RIGHT
var _loop_seconds := 0.0
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
	if manual != null: manual.finish()
	manual = null
	actor = null
	if path != _equipment_key and (path.begins_with("weapon/") or path.begins_with("trait/")):
		_select_equipment_for_effect(path)
	elif not path.begins_with("weapon/") and not path.begins_with("trait/"):
		_weapon_key = ""
		_trait_key = ""
	_equipment_key = ""
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
	if _final_preview:
		_boss = _final_boss
		_technique = "final_strike"
	else:
		var relative := path.trim_prefix(ROOT).trim_suffix("_visual.tscn")
		var parts := relative.split("/")
		if not path.begins_with(ROOT) or parts.size() != 2:
			_boss = ""
			_technique = ""
			_status.text = "ボス技の描画を選ぶと実戦プレビューを表示します"
			return
		_boss = parts[0]
		_technique = parts[1]
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
	actor = session.run.bosses.actor
	if actor == null:
		_status.text = "ボスを配置できません: " + _boss
		return
	actor.configure_flow(program)
	var hud: CanvasLayer = session.scene.view.get_node_or_null("Hud") if session.scene.view != null else null
	if hud != null: hud.visible = false
	if _boss != "hydra" and not _final_preview:
		var debugger := MANUAL.new()
		if debugger.bind(actor): manual = debugger
	if _final_preview: _start_final_strike(keep_playing)
	else: _execute_selected(keep_playing)

func _start_final_strike(keep_playing: bool) -> void:
	if not is_instance_valid(actor): return
	# 実験セッションは時間切れ判定を通さないため、同じ本番開始経路を明示して呼ぶ。
	session.run._begin_final_strike()
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
	if weapon_id != &"": settings["weapons"] = {weapon_id: _equipment_level.selected + 1}
	if trait_id != &"": settings["traits"] = {trait_id: _trait_level.selected + 1}
	await session.reset(settings)
	if serial != _serial: return
	session.run.state.view_center = Vector2.ZERO
	_pause_render_process()
	if no_equipment:
		_set_scene_processing(false)
		_status.text = "試遊する武器・特性を選んでください"
		refresh_effects()
		return
	var behavior = (session.run.loadout.trait_behaviors if play_trait else session.run.loadout.weapon_behaviors).get(play_id)
	if behavior == null:
		_status.text = "装備を試遊へ設定できません: " + play_key
		return
	EQUIPMENT.play(session, play_key, false, _preview_heading)
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

func _show_effect_canvas() -> void:
	if not is_instance_valid(session.scene) or session.scene.view == null: return
	var render := _render()
	if render == null: return
	var hud: CanvasLayer = session.scene.view.get_node_or_null("Hud")
	if hud != null: hud.visible = false
	var layers: Dictionary = render.get("_layers")
	for name in ["field", "dim"]:
		if layers.has(name): (layers[name] as CanvasItem).visible = false

func _flush_preview_events() -> void:
	var events: Array[Dictionary] = []
	for event in session.run.state.events:
		events.append(event)
		session.events.append(event)
	session.run.state.events.clear()
	if not events.is_empty(): session.run.frame_events.emit(events)

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
			var zoom: float = session.run.state.camera_zoom if session.run.state.camera_zoom > 0.0 else session.run._base_zoom()
			var fit: float = minf(_frame.size.x / 1280.0, _frame.size.y / 720.0)
			var target: Vector2 = center + (_preview_origin - session.run.state.view_center) * zoom * fit
			var direction: Vector2 = event.position - target
			if direction.length_squared() > 16.0:
				_preview_heading = direction.normalized()
				set_effect(_equipment_key, false)
	elif event is InputEventMouseMotion and _dragging_origin:
		var zoom: float = session.run.state.camera_zoom if session.run.state.camera_zoom > 0.0 else session.run._base_zoom()
		var fit: float = minf(_frame.size.x / 1280.0, _frame.size.y / 720.0)
		_preview_origin += event.relative / maxf(zoom * fit, 0.01)
		session.run.state.ship_pos = _preview_origin
		session.run.state.enemy_aim = _preview_origin
		_status.text = "発生位置を移動中"
		refresh_effects()

func _change_loadout() -> void:
	if not _equipment_key.is_empty(): set_effect(_equipment_key)

func _replay() -> void:
	if not _equipment_key.is_empty():
		set_effect(_equipment_key, false)
		return
	if _final_preview:
		set_effect("boss/final_strike", false)
		return
	_execute_selected(false)

func _execute_selected(keep_playing: bool) -> void:
	if not is_instance_valid(actor): return
	var started: bool = _execute_hydra() if _boss == "hydra" else manual != null and manual.execute(_technique, 1)
	if started:
		session.playing = keep_playing
		_set_scene_processing(keep_playing)
		_sync_play_button()
		_status.text = "%s / %s を試遊" % [_boss, _technique]
		refresh_effects()
	else:
		_status.text = "この技は単独再生できません: %s / %s" % [_boss, _technique]
		if manual != null and not manual.message.is_empty(): _status.text += " / " + manual.message

func refresh_effects() -> void:
	if is_instance_valid(actor):
		var presentation: CanvasItem = actor.get("_presentation") as CanvasItem
		if presentation != null:
			EFFECT_SETTINGS.apply_key(presentation, "boss/body/" + _boss)
			presentation.queue_redraw()
	var render := _render()
	if render == null: return
	_refresh_scene_visuals(session.scene.view)
	render._present(0.0)
	_hide_preview_hud()
	if not _equipment_key.is_empty(): _show_effect_canvas()
	_sync_preview_shader_time(session.scene.view)

func _hide_preview_hud() -> void:
	if not is_instance_valid(session.scene) or session.scene.view == null: return
	var hud: CanvasLayer = session.scene.view.get_node_or_null("Hud")
	if hud != null: hud.visible = false

func _refresh_scene_visuals(node: Node) -> void:
	if node is AttackVisual:
		(node as AttackVisual)._apply_effect_settings()
	elif node is CanvasItem:
		EFFECT_SETTINGS.apply_to(node as CanvasItem)
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
	if not is_instance_valid(actor) and (session == null or not is_instance_valid(session.run)): return
	session.playing = not session.playing
	_set_scene_processing(session.playing)
	_sync_play_button()

func _process(_delta: float) -> void:
	if not is_instance_valid(session) or not is_instance_valid(session.run): return
	if _final_preview and session.playing and is_instance_valid(actor) \
			and session.run.state.phase == RunState.Phase.PLAY \
			and actor.final_strike_t >= session.run.cfg.time_up_charge_time:
		# 実験場では終了判定が止まるため、試遊セッションだけ同じ着弾・敗北表示へ進める。
		session.run._land_final_strike()
		session.run._begin_death()
	var render: RunPresentation = session.scene.view.get_node_or_null("RunPresentation") if session.scene.view != null else null
	if render == null: return
	if session.playing:
		_visual_time += _delta * session.speed
		render._present(_delta * session.speed)
		_hide_preview_hud()
		if not _equipment_key.is_empty():
			_show_effect_canvas()
			_loop_seconds += _delta * session.speed
			if _loop_seconds >= 10.0:
				set_effect(_equipment_key, true)
				return
	_sync_preview_shader_time(session.scene.view)
	(_frame.material as ShaderMaterial).set_shader_parameter("convert_hdr", _viewport.use_hdr_2d and not get_viewport().use_hdr_2d)
	var zoom: float = session.run.state.camera_zoom if session.run.state.camera_zoom > 0.0 else session.run._base_zoom()
	var center: Vector2 = session.run.state.view_center
	if not _equipment_key.is_empty():
		# 装備の試遊は機体を追い、演出の試作の画面に近い広さまで寄せる
		center = session.run.state.ship_pos
		zoom = 1280.0 / EQUIPMENT_VIEW_WIDTH
	var fit: float = minf(_frame.size.x / 1280.0, _frame.size.y / 720.0)
	render.view_override = {"center": center,
		"zoom": zoom * fit, "shake": _equipment_key.is_empty()}

func _step() -> void:
	if not is_instance_valid(actor) and (session == null or not is_instance_valid(session.run)): return
	session.playing = false
	_set_scene_processing(false)
	_sync_play_button()
	session.step()
	refresh_effects()

func _execute_hydra() -> bool:
	if not actor.has_body() or actor.action_rules == null: return false
	actor.interrupt_tech()
	if actor.count != 8 or actor.necks.any(func(neck): return not actor._alive(neck)):
		actor._set_count(8)
	actor._tech_cd = 0.0
	actor.combo_wait = 0.0
	actor.recovery_t = 0.0
	if _technique in ["grid", "swarm"] and not actor.separated: actor.begin_separation()
	for neck in actor.necks: neck.cd = 0.0
	var gate: Dictionary = actor.action_rules.conditions.get(_technique, {})
	var distance := (float(gate.get("min", 0.0)) + minf(1400.0, float(gate.get("max", 600.0)))) * 0.5
	var origin: Vector2 = actor.table.pos[actor.body]
	var move: Resource = actor._moves.get(StringName(_technique))
	if move == null: return false
	if move.head_kind != &"":
		var neck = actor._first(move.head_kind)
		if neck != null:
			actor.table.facing[actor.body] = -neck.base_angle
			neck.angle = 0.0
			neck.length = float(actor.def.params.neck_rest)
			origin = actor._head_pos(neck) if int(gate.get("distance_origin", 0)) == 1 else actor._neck_base(neck)
	var point := origin + Vector2.from_angle(deg_to_rad(float(gate.get("angle", 0.0)))) * distance
	session.pinned = point
	session.run.state.ship_pos = point
	session.run.state.enemy_aim = point
	session.run.state.view_center = point
	session.run.loadout.reset_loadout()
	var started := false
	if move.head_kind != &"":
		var neck = actor._first(move.head_kind)
		started = neck != null and actor.start_normal(actor.necks.find(neck), StringName(_technique), true)
	else:
		started = actor.try_start_tech(StringName(_technique), 1.0, [], true)
	if started: actor.hsm.set_active(false)
	return started

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
	session.run.combat.rebuild_grid()
	refresh_effects()
