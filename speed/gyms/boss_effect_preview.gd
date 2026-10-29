## 戦闘エフェクト画面に本番のボス描画を映し、選択技だけを試遊する。
extends VBoxContainer

const ROOT := "res://scenes/bosses/"
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
var _final_picker := OptionButton.new()
var _boss := ""
var _technique := ""
var _equipment_key := ""
var _final_preview := false
var _final_boss := "canis_major"
var _serial := 0

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var controls := HBoxContainer.new()
	add_child(controls)
	_play.text = "再生"
	_play.pressed.connect(_toggle_play)
	controls.add_child(_play)
	var step := Button.new()
	step.text = "1コマ"
	step.pressed.connect(_step)
	controls.add_child(step)
	var replay := Button.new()
	replay.text = "最初から"
	replay.pressed.connect(_replay)
	controls.add_child(replay)
	for value in SPEEDS:
		_speed.add_item(str(value) + "倍")
	_speed.select(2)
	_speed.item_selected.connect(func(index: int): session.speed = SPEEDS[index])
	controls.add_child(_speed)
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

func set_effect(path: String) -> void:
	_serial += 1
	var serial := _serial
	if manual != null: manual.finish()
	manual = null
	actor = null
	_equipment_key = ""
	_final_preview = path == "boss/final_strike"
	_final_picker.visible = _final_preview
	session.playing = false
	_play.text = "再生"
	if path.begins_with("weapon/") or path.begins_with("trait/"):
		_equipment_key = path
		await _setup_equipment(path, serial)
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
	var program_path := "res://.content/boss_%s.tres" % _boss
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
	if _final_preview: _start_final_strike()
	else: _replay()

func _start_final_strike() -> void:
	if not is_instance_valid(actor): return
	# 実験セッションは時間切れ判定を通さないため、同じ本番開始経路を明示して呼ぶ。
	session.run._begin_final_strike()
	session.playing = true
	_play.text = "停止"
	_status.text = "制限時間の一撃を再生中: " + FINAL_BOSS_NAMES[FINAL_BOSSES.find(_boss)]

func _setup_equipment(key: String, serial: int) -> void:
	var is_trait := key.begins_with("trait/")
	var catalog: Dictionary = ContentManager.catalog.table(&"traits" if is_trait else &"weapons")
	var code := key.get_slice("/", 1)
	var id := StringName()
	for candidate in catalog:
		if String(catalog[candidate].code_id) == code:
			id = candidate
			break
	if id == &"":
		_status.text = "装備が見つかりません: " + key
		return
	_status.text = "試遊を準備中: " + key
	var settings := {"empty": true, "stage": 1, "ship_pos": [0, 0], "invincible": true,
		"director": {"enabled": false}, "weapons": {}, "traits": {}}
	if is_trait: settings["traits"] = {id: 5}
	else: settings["weapons"] = {id: 5}
	await session.reset(settings)
	if serial != _serial: return
	var behavior = (session.run.loadout.trait_behaviors if is_trait else session.run.loadout.weapon_behaviors).get(id)
	if behavior == null:
		_status.text = "装備を試遊へ設定できません: " + key
		return
	var target := -1
	if key not in ["weapon/sonic", "weapon/dashRangeDrone", "weapon/afterimage", "weapon/mines"]:
		target = _spawn_preview_enemy(Vector2(120, 0))
	match key:
		"weapon/forward", "weapon/scatter", "weapon/rear":
			behavior.tick(10.0, false)
		"weapon/interceptor":
			behavior.tick(1.0, false)
			behavior.tick(1.0, false)
		"weapon/knockback":
			if target >= 0:
				var at: Vector2 = session.run.enemies.table.pos[target]
				session.run.enemies.mark_dead(target)
				behavior.def = behavior.def.duplicate(true)
				behavior.def.params.chance_by_level = [1.0,1.0,1.0,1.0,1.0]
				behavior.on_defeated(target, {"one_shot":true,"dir":Vector2.RIGHT})
		"weapon/contactWave":
			if target >= 0: behavior.on_contact(target, session.run.enemies.table.pos[target], Vector2.RIGHT)
		"weapon/contactArc":
			_spawn_preview_enemy(Vector2(170, 70))
			_spawn_preview_enemy(Vector2(180, -70))
			if target >= 0: behavior.on_any_contact(target)
		"weapon/barrier":
			behavior.block_segment(Vector2(100,0),Vector2.ZERO,1.0,10.0)
		"weapon/mines":
			behavior.on_end()
			if not behavior.mines.is_empty(): _spawn_preview_enemy(behavior.mines[0].to)
		"weapon/massTow":
			if target >= 0:
				session.run.state.tracing = true
				behavior.capture(target)
				session.run.state.tracing = false
				session.run.enemies.mark_dead(target)
				behavior.on_end()
				behavior.tick(0.1, false)
		"weapon/bipolar":
			behavior.on_launch(false)
			session.run.state.ship_pos = Vector2(240, 0)
			behavior.on_end()
		"weapon/sonic":
			behavior.on_launch(false)
			_start_preview_route()
		"weapon/dashRangeDrone", "weapon/afterimage":
			_start_preview_route()
		"trait/endBlast", "trait/vortex":
			session.run.loadout.on_end()
		"trait/killSonic":
			session.run.loadout.on_launch(true)
			for _i in behavior._every(): session.run.loadout.on_kill(&"shot")
		"trait/critBeam": session.run.loadout.on_critical(session.run.state.ship_pos)
	session.playing = true
	_play.text = "停止"
	_status.text = "試遊中: " + key

func _spawn_preview_enemy(at: Vector2) -> int:
	session.perform("spawn", {"type": "drifter", "pos": [at.x, at.y]})
	return session.selected

func _start_preview_route() -> void:
	session.perform("route", {"points": [[0, 0], [300, 0]], "draw_seconds": 0.3})

func _replay() -> void:
	if not _equipment_key.is_empty():
		set_effect(_equipment_key)
		return
	if _final_preview:
		set_effect("boss/final_strike")
		return
	if not is_instance_valid(actor): return
	var started: bool = _execute_hydra() if _boss == "hydra" else manual != null and manual.execute(_technique, 1)
	if started:
		session.playing = true
		_play.text = "停止"
		_status.text = "%s / %s を再生中" % [_boss, _technique]
	else:
		_status.text = "この技は単独再生できません: %s / %s" % [_boss, _technique]
		if manual != null and not manual.message.is_empty(): _status.text += " / " + manual.message

func refresh_effects() -> void:
	if not _equipment_key.is_empty():
		set_effect(_equipment_key)
		return
	if _final_preview:
		set_effect("boss/final_strike")
		return
	if not is_instance_valid(actor): return
	var presentation: CanvasItem = actor.get("_presentation") as CanvasItem
	if presentation != null:
		EFFECT_SETTINGS.apply_key(presentation, "boss/body/" + _boss)
		presentation.queue_redraw()
	_replay()

func _toggle_play() -> void:
	if not is_instance_valid(actor) and (session == null or not is_instance_valid(session.run)): return
	session.playing = not session.playing
	_play.text = "停止" if session.playing else "再生"

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
	(_frame.material as ShaderMaterial).set_shader_parameter("convert_hdr", _viewport.use_hdr_2d and not get_viewport().use_hdr_2d)
	var zoom: float = session.run.state.camera_zoom if session.run.state.camera_zoom > 0.0 else session.run._base_zoom()
	var fit := minf(_frame.size.x / 1280.0, _frame.size.y / 720.0)
	render.view_override = {"center": session.run.state.view_center, "zoom": zoom * fit, "shake": true}

func _step() -> void:
	if not is_instance_valid(actor) and (session == null or not is_instance_valid(session.run)): return
	session.playing = false
	_play.text = "再生"
	session.step()

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
	if not active and session != null: session.playing = false
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED

func _exit_tree() -> void:
	if manual != null: manual.finish()
