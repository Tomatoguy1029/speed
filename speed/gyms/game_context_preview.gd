## 目印・BOOST用の独立した本番表示。戦闘を進めず、編集Resourceを保存しない。
extends VBoxContainer

const AURA := preload("res://gyms/game_context_aura.gd")
const HUD := preload("res://gyms/game_context_hud.gd")
const GAUGE := preload("res://scripts/ui/boost_gauge_visual.gd")
const LIVE_VISUALS := preload("res://tools/content/visual_transforms.gd")
const EFFECTS := preload("res://data/visuals/effect_settings.tres")

var preview_paused := false
var _active := false
var _mode := "landmark"
var _clock := 0.0
var _settings: EnemyMarkSettings
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
var _base_radius := 0.0

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
	_stage.item_selected.connect(func(_index: int): _build_context())
	for caption in ["開始地点", "背景素材の付近"]: _placement.add_item(caption)
	environment.add_child(_placement)
	_placement.item_selected.connect(func(_index: int): _place_context())
	var pause := CheckButton.new()
	pause.text = "一時停止"
	pause.toggled.connect(func(value: bool): preview_paused = value)
	environment.add_child(pause)
	var restart := Button.new()
	restart.text = "先頭へ"
	restart.pressed.connect(preview_restart)
	environment.add_child(restart)
	add_child(_enemy_row)
	# HeroSystemの抽選と同じrank条件。部位は親のon_spawnから作る。
	for key in ContentManager.enemies:
		var definition: EnemyDef = ContentManager.enemies[key]
		if definition.rank >= 2 and definition.rank <= 5:
			_enemy_ids.append(StringName(key))
	_enemy_ids.sort()
	for key in _enemy_ids:
		_enemy.add_item(ContentManager.enemies[key].display_name)
	if &"telescope" in _enemy_ids: _enemy.select(_enemy_ids.find(&"telescope"))
	_enemy_row.add_child(_enemy)
	_enemy.item_selected.connect(func(_index: int): _spawn_target())
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
	for caption in ["通常", "不足", "経路描画中", "使用可能の波紋", "満タンの閃き"]: _boost.add_item(caption)
	_boost_row.add_child(_boost)
	_boost.item_selected.connect(func(_index: int): _apply_boost())
	var pointer := CheckButton.new()
	pointer.text = "マウスへ追従"
	pointer.toggled.connect(func(value: bool):
		_follow_cursor = value
		if is_instance_valid(_hud): _hud.follow_cursor = value)
	_boost_row.add_child(pointer)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(aspect)
	_frame = SubViewportContainer.new()
	_frame.stretch = true
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_refresh_mode()
	if _active: _build_context()

## editorが保持する未保存Resourceを受け取る。読み直し・保存・bakeを行わない。
func set_landmark_settings(settings: EnemyMarkSettings) -> void:
	_settings = settings
	_mode = "landmark"
	if is_instance_valid(_aura):
		_aura.settings = settings
		_aura.refresh()
	if is_node_ready(): _refresh_mode()

func set_boost_values(values: Dictionary) -> void:
	_boost_values = values.duplicate(true)
	_has_boost_values = true
	_mode = "boost"
	if is_instance_valid(_hud): _hud.preview_values = _boost_values
	if is_node_ready():
		_refresh_mode()
		_apply_boost()

func set_active(active: bool) -> void:
	_active = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if not is_node_ready(): return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if active and not is_instance_valid(_session): _build_context()

func _refresh_mode() -> void:
	_enemy_row.visible = _mode == "landmark"
	_boost_row.visible = _mode == "boost"
	if is_instance_valid(_session) and _target >= 0:
		_session.sim.enemies.table.landmark[_target] = 1 if _mode == "landmark" else 0
		_apply_boost()

func _build_context() -> void:
	if not _active or _stage_ids.is_empty(): return
	var index := _stage_ids[_stage.selected]
	var path := "res://.content/stage_%d.tres" % index
	# runtime_stage()は自動生成へ入るので、既存の生成物だけを直接取得する。
	if not ResourceLoader.exists(path):
		_status.text = "生成済みステージがありません: " + path
		return
	var stage := ResourceLoader.load(path) as RuntimeStage
	if stage == null: return
	if ContentManager.visual_index == null or not ResourceLoader.exists("res://.content/hero_aura.res"):
		_status.text = "生成済みの外観一覧・英雄オーラが必要です。自動生成は行いません。"
		return
	stage = stage.duplicate(true) as RuntimeStage
	# ステージ限定の外観一覧にない任意の対象も、本番の生成済み外観を使う。
	stage.resources.look_paths.merge(ContentManager.visual_index.look_paths, false)
	for key in ContentManager.visual_index.look_names:
		if key not in stage.resources.look_names: stage.resources.look_names.append(key)
	var options := {"lab": true, "stage": stage, "stage_index": index, "hud": false,
		"seed": 932, "enemies": ContentManager.enemies.duplicate(), "auto_spawn": false,
		"live_visuals": LIVE_VISUALS.live_look, "profile": ProfileManager.for_run(true, {}),
		"view_size": Vector2(_viewport.size)}
	var previous := _session
	_session = RunManager.create_session(_viewport, options, true)
	_session.auto_step = false
	_session.set_process(false)
	_session.set_physics_process(false)
	if is_instance_valid(previous): previous.free()
	var run := _session.sim
	run.input.process_mode = Node.PROCESS_MODE_DISABLED
	run.input.set_process_input(false)
	run.input.set_process_unhandled_input(false)
	run.state.events.clear()
	_origin = run.state.ship_pos
	_render = _session.view.get_node("RunPresentation") as RunPresentation
	_render.show_background = true
	for fire: PixelFire in _render._background_fires + _render._static_fires:
		fire.manual = true
	var runtime_aura: Node2D = _render._landmark_aura
	_aura = AURA.new()
	_aura.settings = _settings
	_aura.z_index = runtime_aura.z_index
	runtime_aura.get_parent().add_child(_aura)
	_aura.setup(_render)
	runtime_aura.free()
	_render._landmark_aura = _aura
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	layer.layer = maxi(10, _render._look_names.size() + 5)
	_session.view.add_child(layer)
	_hud = HUD.new()
	_hud.run = run
	_hud.follow_cursor = _follow_cursor
	_hud.preview_values = _boost_values if _has_boost_values else EFFECTS.values_for(GAUGE.KEY)
	layer.add_child(_hud)
	_place_context()
	_status.text = "本番の背景・星・船体・法線・HUD / 戦闘停止・カメラ固定"

func _place_context() -> void:
	if not is_instance_valid(_session): return
	_center = _origin
	var stage := _session.sim.state.stage
	if _placement.selected == 1 and not stage.backgrounds.is_empty():
		_center += stage.backgrounds[0].offset
	_session.sim.state.ship_pos = _center + Vector2(-120, 80)
	_session.sim.state.view_center = _center
	_spawn_target()
	_frame_changed()

func _spawn_target() -> void:
	if not is_instance_valid(_session) or _enemy_ids.is_empty(): return
	var run := _session.sim
	run.enemies.clear_all()
	var key := _enemy_ids[_enemy.selected]
	var definition := run.enemies.def_of(key)
	_target = run.enemies.spawn(definition, _center + Vector2(70, 0), {"facing": -PI / 2.0})
	var t := run.enemies.table
	t.landmark[_target] = 1 if _mode == "landmark" else 0
	_base_radius = t.r[_target]
	_form.visible = definition.behavior == &"ruler"
	_pump.visible = definition.behavior == &"pump"
	if definition.behavior == &"ruler":
		t.buds[_target] = 0 if _form.selected == 0 else -1 if _form.selected == 1 else 1
	_apply_pump()
	_apply_boost()
	# spawnの通知をHUD/音声へ配送しない。
	run.state.events.clear()

func _apply_pump() -> void:
	if not is_instance_valid(_session) or _target < 0: return
	var t := _session.sim.enemies.table
	if t.def[_target].behavior != &"pump": return
	t.r[_target] = _base_radius * (1.0 + float(t.def[_target].params.grow) * _pump.value)
	t.mode[_target] = EnemyTable.Mode.WINDUP if _pump.value >= 1.0 else EnemyTable.Mode.MOVE

func _apply_boost() -> void:
	if not is_instance_valid(_session): return
	var s := _session.sim.state
	s.stats.capacity = 1.5
	s.gauge = (0.1 if _boost.selected == 1 else 1.5 if _boost.selected == 4 else 1.1) / s.stats.capacity
	s.drawing = _mode == "boost" and _boost.selected == 2
	s.tracing = false
	s.draw_gauge = 1.1
	s.draw_limit = 300.0
	s.draw_length = 120.0
	s.draw_points = PackedVector2Array([s.ship_pos + Vector2(20, -30), s.ship_pos + Vector2(100, -110), s.ship_pos + Vector2(180, -90)])
	_hud.preview_mode = _boost.selected

func _frame_changed() -> void:
	if not is_instance_valid(_session): return
	var shown := Vector2(_viewport.size)
	_session.sim.options.view_size = shown
	# 本番の速度・base_viewから求まる倍率。サイズ変更で対象を追わない。
	var zoom := _session.sim._base_zoom()
	_render.view_override = {"center": _center, "zoom": zoom}
	_session.sim.state.view_half = shown / (2.0 * zoom)
	_hud.preview_cursor = shown * Vector2(0.68, 0.62)

func preview_restart() -> void:
	_clock = 0.0
	if is_instance_valid(_render):
		for fire: PixelFire in _render._background_fires + _render._static_fires:
			fire.restart()
	preview_step(0.0)

func preview_step(delta: float) -> void:
	_clock += delta
	if not is_instance_valid(_session): return
	_session.sim.state.world_time = _clock
	_session.sim.state.phase = RunState.Phase.PAUSED if preview_paused else RunState.Phase.PLAY
	_hud.preview_clock = _clock
	_hud.queue_redraw()
	if delta > 0.0:
		for fire: PixelFire in _render._background_fires + _render._static_fires:
			fire.advance(delta)

func _process(delta: float) -> void:
	preview_step(0.0 if preview_paused else delta)
