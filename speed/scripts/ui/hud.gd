## ラン中の HUD（仕様書 17）。状態を読んで表示するだけで、選んだ結果は RunSimulation に命令として渡す。
##
## 時間・経験値バー・状態の文字・装備一覧・ゲージのリング・3択・ボスの表示・ポーズ・
## 「描く」ボタン（タッチ）・CLEAR! と GAME OVER。
extends Control

## 描けるようになったときに広がる輪の時間（実秒）
const RING_PULSE_TIME := 0.35
## リングが1周溜まりきったときに白く光る時間（実秒）
const RING_FLASH_TIME := 0.3
## 制作済みの色・円帯・目盛りと、3周目以降の間隔
const BOOST_STYLE := preload("res://data/visuals/boost_gauge_runtime.tres")
const RING_GAP := 7.0
const SETTINGS_SCENE := preload("res://scenes/app/settings.tscn")
## 装備一覧の枠の大きさ（素材のpx）
const LOADOUT_SLOT := 16.0
const LOADOUT_STEP := 18.0
const LOADOUT_WEAPON := Vector2(9, 320)
const LOADOUT_TRAIT := Vector2(9, 338)
const LOADOUT_HERO := Vector2(81, 320)
const LOADOUT_REGION := Rect2(9, 320, 107, 35)
## ミニマップの半径（素材のpx）
const MINIMAP_R := 43.0
const MINIMAP_CENTER := Vector2(584, 55)
const ART_SIZE := Vector2(640, 360)
const CYAN := Color("#5bc8db")
const ART := "res://assets/ui/combat/"
const RADAR := preload(ART + "combat_ui_radar.png")
const HEALTH := preload(ART + "combat_ui_health_bar.png")
const BOOST_GAUGE := preload("res://scripts/ui/boost_gauge_visual.gd")
const EXPERIENCE := preload(ART + "combat_ui_exp_bar.png")
const SLOTS := preload(ART + "combat_ui_components.png")
const COMET_SLOT_FRAME := preload(ART + "comet_slot_frame.gdshader")
const CARDS := preload(ART + "combat_ui_boxes.png")
const CARD_VIEW := preload("res://scripts/ui/reward_card_view.gd")
const SPEED_INDICATOR := preload("res://scripts/ui/speed_indicator.gd")
const ICONS := preload(ART + "icons.png")
const ICON_IDS := preload("res://scripts/ui/module_icons.gd").IDS

## ミニマップと、ミニマップ以外の表示（経験値バー・時間・状態の文字・装備一覧・ボス・ゲージのリング）を描くか
## （実験場では初めは消す）
var show_minimap := true
var show_status := true
## 彗星限定の武器の枠の色（段階の色と重ならない赤）
const COMET_ONLY_COLOR := Color("#ff3b4e")
const RANK_COLORS := [Color("#d5dbea"), Color("#8ed7a3"), Color("#3989ff"), Color("#bf91ef"), Color("#efcb70")]

## カードを表示してから選択を受け付けるまでの実秒。
@export_range(0.0, 1.0, 0.05) var card_input_delay := 0.3

@export_group("報酬演出")
@export_range(0.3, 1.0, 0.05) var continuation_seconds := 0.55
@export_range(0.5, 3.0, 0.05) var ult_cutin_seconds := 1.15
@export_range(1.0, 8.0, 0.1) var ult_details_seconds := 3.0
## 800×450 の演出座標。任意で setup(HeroDef) / set_progress(0..1) を受け取る Control シーン。
@export var ult_cutin_scene: PackedScene

var _cards_accept_at := 0
var _reward_advanced_frame := -1
var _card_blocked_pointer_frame := -1
var _card_blocked_pointer_pos := Vector2.ZERO
## 表示切替前からの押下と、離すまで破棄する押下（マウス・タッチ・選択キー）。
var _card_held: Dictionary = {}
var _card_discard: Dictionary = {}
var _cpp_retry: Button
var _cpp_cancel: Button

## 通常 ULT のカットインと独立した仮演出。setup / set_progress の契約はシーンのスクリプトを参照。
@export_group("伝説獲得の仮演出")
@export var legendary_reveal_scene: PackedScene
@export_file("*.tscn") var legendary_reveal_path := "res://scenes/run/legendary_reveal.tscn"
var _legendary_reveal: Control
var _finish_skip: Button
var _entrance_skip: Button
var _rewards: Control
## RunSession が木に入れる前に入れる
var bridge: RefCounted
var _cpp_ui: Dictionary = {}
var run: RunSimulation
var _laser_audio: Node
var _font: Font
var _cards_box: Control
var _cards_dim: ColorRect
var _reroll_button: Button
var _cards_title: Label
var _cards_row: Control
var _swap_box: Control
var _swap_grid: GridContainer
var _swap_new_card: Button
var _swap_new_name: Label
var _swap_new_desc: Label
var _swap_keep: Button
var _swap_keep_index := -1
var _loadout_icons: Control
var _loadout_key := ""
var _health_fill: AtlasTexture
var _experience_fill: AtlasTexture
var _pause_box: VBoxContainer
var _draw_button: Button
var _banner := ""
var _banner_color := Color.WHITE
var _banner_t := 0.0
var _warning_t := 0.0
var _hero_notice_t := 0.0
var _ring_usable := true
## ポーズ中に開いている設定（なければ null）
var _settings: UiScreen
var _ring_pulse_t := 0.0
var _ring_flash_t := 0.0
var _ring_flash_max := RING_FLASH_TIME
## 前のフレームの溜まっている量（1周溜まりきった瞬間を見つける）
var _ring_amount := 1.0
var _pause_after_reward := false
var _menu_overlay: Control
var _overlay_focus: WeakRef
var _speed_indicator: SPEED_INDICATOR

func _ready() -> void:
	if bridge!=null:
		_ready_cpp()
		return
	_speed_indicator = SPEED_INDICATOR.new()
	add_child(_speed_indicator)
	_laser_audio = preload("res://scripts/ui/enemy_laser_audio.gd").new()
	add_child(_laser_audio)
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_health_fill = _make_bar_fill(HEALTH)
	_experience_fill = _make_bar_fill(EXPERIENCE)
	_loadout_icons = Control.new()
	_loadout_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loadout_icons)
	_build_cards()
	_rewards = preload("res://scripts/ui/reward_presentation.gd").new()
	_rewards.continuation_seconds = continuation_seconds
	_rewards.ult_cutin_seconds = ult_cutin_seconds
	_rewards.ult_details_seconds = ult_details_seconds
	_rewards.ult_cutin_scene = ult_cutin_scene
	_rewards.add_module_icon = _add_icon
	add_child(_rewards)
	_rewards.active_changed.connect(_on_reward_active)
	resized.connect(_layout_art)
	_build_pause()
	_draw_button = Button.new()
	_draw_button.text = "hud.draw"
	_draw_button.custom_minimum_size = Vector2(120, 120)
	_draw_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_draw_button.position = Vector2(-150, -170)
	_draw_button.visible = DisplayServer.is_touchscreen_available()
	_draw_button.pressed.connect(func(): run.command(&"draw_button"))
	add_child(_draw_button)
	_finish_skip = Button.new()
	_finish_skip.text = tr("hud.skip_finish")
	_finish_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_finish_skip.position = Vector2(-210, -58)
	_finish_skip.size = Vector2(190, 38)
	_finish_skip.hide()
	_finish_skip.pressed.connect(func(): run.command(&"skip_finish"))
	add_child(_finish_skip)
	_entrance_skip = Button.new()
	_entrance_skip.name = "BossEntranceSkip"
	_entrance_skip.text = tr("hud.skip_finish")
	_entrance_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_entrance_skip.position = Vector2(-210, -58)
	_entrance_skip.size = Vector2(190, 38)
	_entrance_skip.hide()
	_entrance_skip.pressed.connect(func(): run.command(&"skip_boss_entrance"))
	add_child(_entrance_skip)
	run.phase_changed.connect(_on_phase)
	run.cards_changed.connect(_show_cards)
	run.frame_events.connect(_on_events)
	if not run.state.lab_mode:
		AudioManager.play_music(&"boss" if run.state.boss_spawned else &"battle", 0.6, self)

func _on_reward_active(active: bool) -> void:
	run.ui_reward_active = active
	run.input.cancel_gesture()
	_card_discard.merge(_card_held)
	_sync_menu_visibility()
	if not active:
		if _pause_after_reward:
			_pause_after_reward = false
			run.command(&"pause")
		_cards_accept_at = Time.get_ticks_usec() + roundi(card_input_delay * 1_000_000.0)

func _on_phase(phase: RunState.Phase) -> void:
	if phase == RunState.Phase.FINISHING:
		_pause_after_reward = false
		_rewards.cancel()
		_warning_t = 0.0
		_hero_notice_t = 0.0
		_draw_button.hide()
		var definition := run.finish_legendary()
		if definition != null and (legendary_reveal_scene != null or not legendary_reveal_path.is_empty()):
			var scene: PackedScene = legendary_reveal_scene if legendary_reveal_scene != null else load(legendary_reveal_path)
			_legendary_reveal = scene.instantiate() as Control
			_legendary_reveal.setup(definition)
			add_child(_legendary_reveal)
			_legendary_reveal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			if _legendary_reveal.has_method("set_timing"):
				_legendary_reveal.set_timing(run.cfg.boss_finish_relic_appear_time, run.cfg.boss_finish_relic_hold_time, run.cfg.boss_finish_relic_collect_time)
			_legendary_reveal.hide()
			move_child(_finish_skip, -1)
	elif phase == RunState.Phase.ENDED:
		_finish_skip.hide()
		if _legendary_reveal != null:
			_legendary_reveal.hide()
	run.input.cancel_gesture()
	_card_discard.merge(_card_held)
	_cards_accept_at = Time.get_ticks_usec() + roundi(card_input_delay * 1_000_000.0)
	_sync_menu_visibility()
	if _pause_box.visible:
		_pause_box.get_child(1).grab_focus()

## 開発用パネルなどを重ねる入口。選択・報酬・ポーズの状態は裏に保持する。
func can_show_menu_overlay() -> bool:
	return _settings == null and _menu_overlay == null and run.state.phase in [RunState.Phase.PLAY, RunState.Phase.LEVELUP, RunState.Phase.PAUSED]

func show_menu_overlay(overlay: Control) -> bool:
	if not can_show_menu_overlay():
		return false
	var focus := get_viewport().gui_get_focus_owner()
	_overlay_focus = weakref(focus) if focus != null else null
	_menu_overlay = overlay
	run.ui_overlay_active = true
	run.input.cancel_gesture()
	_card_discard.merge(_card_held)
	_sync_menu_visibility()
	return true

func close_menu_overlay(overlay: Control) -> void:
	if _menu_overlay != overlay:
		return
	_menu_overlay = null
	run.ui_overlay_active = false
	run.input.cancel_gesture()
	_card_discard.merge(_card_held)
	_cards_accept_at = Time.get_ticks_usec() + roundi(card_input_delay * 1_000_000.0)
	_sync_menu_visibility()
	var focus := _overlay_focus.get_ref() as Control if _overlay_focus != null else null
	if focus != null and focus.is_visible_in_tree():
		focus.grab_focus()
	_overlay_focus = null

func _sync_menu_visibility() -> void:
	var covered := _menu_overlay != null
	var paused := run.state.phase == RunState.Phase.PAUSED
	_cards_box.visible = not covered and not paused and not _rewards.is_active() and run.state.phase == RunState.Phase.LEVELUP
	_cards_dim.visible = _cards_box.visible and _swap_box.visible
	_pause_box.visible = not covered and paused and _settings == null
	_rewards.visible = not covered and not paused and _rewards.is_active()
	_rewards.set_process(not covered and not paused)
	_draw_button.visible = _can_show_draw_button(DisplayServer.is_touchscreen_available())

func _on_events(events: Array[Dictionary]) -> void:
	for ev in events:
		match ev.type:
			&"enemy_laser_charge", &"enemy_laser_cancel", &"enemy_laser_fire":
				_laser_audio.handle(ev)
			&"full_burst_ready":
				_ring_flash_t = 0.1
				_ring_flash_max = 0.1
				_ring_pulse_t = 0.3
			&"level_bonus":
				if run.state.phase not in [RunState.Phase.FINISHING, RunState.Phase.ENDED]:
					_rewards.enqueue_bonus(ev)
			&"hero_freed":
				if run.state.phase not in [RunState.Phase.FINISHING, RunState.Phase.ENDED]:
					_rewards.enqueue_ult(ev)
			&"hero_discovered":
				_hero_notice_t = 1.8
			&"boss_spawn":
				if not run.state.lab_mode: AudioManager.play_music(&"boss", 1.0, self)
				_warning_t = 3.0
			&"clear_banner":
				AudioManager.end_dash()
				_banner = tr("hud.clear")
				_banner_color = Color("#ffe46b")
				_banner_t = 99.0
			&"game_over":
				AudioManager.end_dash()
				if not run.state.lab_mode:
					AudioManager.play_music(&"game_over", 1.0, AudioManager)
				_banner = tr("hud.game_over")
				_banner_color = Color("#ff6b5a")
				_banner_t = 99.0
			&"levelup":
				AudioManager.play(&"levelup_notice", -6.0)
			&"kill":
				if not ev.get("silent", false):
					AudioManager.play(&"kill", -10.0, randf_range(0.9, 1.2))
			&"hurt":
				AudioManager.play(&"hurt", -4.0)
			&"weapon_fire":
				if ev.id in [&"W01", &"W23"]:
					AudioManager.play(&"blaster", -12.0)
			&"launch":
				AudioManager.play(&"dash", -6.0)
			&"trace_end":
				AudioManager.end_dash()
			&"block_impact":
				AudioManager.play(&"bounce", -8.0)
			&"shield_reflect":
				AudioManager.play(&"block", -10.0, 1.8)
			&"shield_stolen":
				AudioManager.play(&"pickup", -5.0, 0.7)
			&"shield_block":
				AudioManager.play(&"block", -10.0, 1.3)
			&"boss_explode":
				AudioManager.play(&"boom")
			&"bomber_explode":
				AudioManager.play(&"bomber_explode", -12.0)

## GUI が押下を記憶する前に止める。期限後の release やキーリピートにも持ち越さない。
func _input(event: InputEvent) -> void:
	if bridge!=null:
		_input_cpp(event)
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and focus.is_in_group("stage_enemy_tuning_input"): return
	if run == null or run.state == null or run.state.lab_mode:
		return
	if run.state.phase == RunState.Phase.FINISHING:
		if run.sequence_t >= 0.35 and not event.is_echo() and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_accept")):
			run.command(&"skip_finish")
			get_viewport().set_input_as_handled()
		return
	# カードの入力ガードや GUI より先にメニューキーを扱う。
	if _settings == null and _menu_overlay == null and event.is_action(&"pause") and run.state.phase in [RunState.Phase.PLAY, RunState.Phase.LEVELUP, RunState.Phase.PAUSED]:
		get_viewport().set_input_as_handled()
		if event.is_action_pressed(&"pause"):
			run.command(&"resume" if run.state.phase == RunState.Phase.PAUSED else &"pause")
		return
	var id := _card_input_id(event)
	if id == "":
		return
	# 表示を発生させた押下や、タッチ由来の擬似マウスを次送りに使わない。
	var in_menu := _menu_overlay != null or run.state.phase == RunState.Phase.PAUSED
	var reward_press: bool = not in_menu and _rewards.is_bonus_active() and not _card_held.has(id) and not _card_discard.has(id) and not event.is_echo() and (
		(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1 and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
		or event.is_action_pressed(&"ui_accept"))
	var choosing := not in_menu and run.state.phase == RunState.Phase.LEVELUP
	var blocked: bool = _card_discard.has(id) or (not in_menu and (_rewards.is_active() or (choosing and Time.get_ticks_usec() < _cards_accept_at)))
	# 擬似イベントと元の入力の間で期限を越えても、同じ押下として破棄する。
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		if event.device == -1 and blocked:
			_card_blocked_pointer_frame = Engine.get_process_frames()
			_card_blocked_pointer_pos = event.position
		elif event.device != -1 and _card_blocked_pointer_frame == Engine.get_process_frames() and event.position == _card_blocked_pointer_pos:
			blocked = true
	if not event is InputEventScreenDrag:
		if event.is_pressed():
			_card_held[id] = true
			if blocked:
				_card_discard[id] = true
		else:
			_card_held.erase(id)
			_card_discard.erase(id)
	# タッチの選択は既存のマウス擬似イベントに任せ、元のタッチをゲームへ漏らさない。
	if blocked or (choosing and (event is InputEventScreenTouch or event is InputEventScreenDrag)):
		get_viewport().set_input_as_handled()
	if reward_press and _reward_advanced_frame != Engine.get_process_frames():
		_reward_advanced_frame = Engine.get_process_frames()
		_rewards.advance_bonus()

func _card_input_id(event: InputEvent) -> String:
	if event is InputEventMouseButton:
		return "mouse:%d:%d" % [event.device, event.button_index]
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch:%d:%d" % [event.device, event.index]
	var id := ""
	if event is InputEventKey:
		id = "key:%d:%d" % [event.device, event.physical_keycode if event.physical_keycode != 0 else event.keycode]
	elif event is InputEventJoypadButton:
		id = "joy:%d:%d" % [event.device, event.button_index]
	elif event is InputEventAction:
		id = "action:%s" % event.action
	if id != "":
		if (_rewards!=null and _rewards.is_active()) or _card_held.has(id) or _card_discard.has(id):
			return id
		for action in [&"card_1", &"card_2", &"card_3", &"reroll", &"ui_accept", &"hero", &"draw_alt", &"pause"]:
			if event.is_action(action):
				return id
	return ""

func _card_command(command: StringName, args := {}) -> void:
	if bridge!=null:
		if _cpp_ui.is_empty() or int(_cpp_ui.phase)!=RunState.Phase.LEVELUP or Time.get_ticks_usec()<_cards_accept_at: return
		var cards: Dictionary = _cpp_ui.get("cards",{})
		var payload := {"offer_id":cards.get("offer_id",0)}
		if command==&"choose_card":
			var index := int(args.get("index",-1))
			if index<0 or index>=cards.get("candidates",[]).size(): return
			payload.candidate_id = cards.candidates[index].candidate_id
		_card_discard.merge(_card_held)
		bridge.command(String(command),payload)
		return
	if _menu_overlay != null or _rewards.is_active() or run.state.phase != RunState.Phase.LEVELUP or Time.get_ticks_usec() < _cards_accept_at:
		return
	_card_discard.merge(_card_held)
	run.command(command, args)

func _unhandled_input(event: InputEvent) -> void:
	if bridge!=null:
		if event.is_action_pressed(&"pause") and not event.is_echo() and not _cpp_ui.is_empty():
			bridge.command("pause",{"paused":int(_cpp_ui.phase)!=2})
			get_viewport().set_input_as_handled()
		return
	# 実験場では HUD は表示だけ。操作は実験場が扱う。
	if run.state.lab_mode:
		return
	if run.state.phase in [RunState.Phase.FINISHING, RunState.Phase.ENDED]:
		get_viewport().set_input_as_handled()
		return
	if _menu_overlay != null or run.state.phase == RunState.Phase.PAUSED or _rewards.is_active():
		get_viewport().set_input_as_handled()
		return
	if _settings != null:
		return
	var s := run.state
	if s.phase == RunState.Phase.LEVELUP:
		for i in 3:
			if event.is_action_pressed(StringName("card_%d" % (i + 1))):
				get_viewport().set_input_as_handled()
				_card_command(&"choose_card", {"index": i})
		if event.is_action_pressed(&"reroll"):
			get_viewport().set_input_as_handled()
			_card_command(&"reroll")
		# カードの外を押しても、再開後の描画入力として残さない。
		if _card_input_id(event) != "":
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and run != null and run.state != null and not run.state.lab_mode:
		if _rewards.is_active():
			_pause_after_reward = true
		else:
			run.command(&"pause")

func _process(delta: float) -> void:
	if bridge!=null:
		_update_speed_indicator(delta)
		if not _cpp_ui.is_empty() and not _cpp_ui.get("presentation_frozen",true):
			_ring_pulse_t = maxf(0.0,_ring_pulse_t-delta)
			_ring_flash_t = maxf(0.0,_ring_flash_t-delta)
		queue_redraw()
		return
	_update_speed_indicator(delta)
	_laser_audio.sync(run)
	var slow := run.state.phase == RunState.Phase.PLAY and run.draw.world_scale() < 0.999
	if run.state.phase == RunState.Phase.FINISHING:
		slow = run.sequence_t < run.cfg.boss_finish_slow_time
	AudioManager.set_slow_motion(slow and _menu_overlay == null and not _rewards.is_active())
	_update_finish_presentation()
	_update_cinematic_visibility()
	_hero_notice_t = maxf(0.0, _hero_notice_t - delta)
	_warning_t = maxf(0.0, _warning_t - delta)
	_ring_pulse_t = maxf(0.0, _ring_pulse_t - delta)
	_ring_flash_t = maxf(0.0, _ring_flash_t - delta)
	_layout_art()
	_refresh_loadout_icons()
	queue_redraw()

func _update_cinematic_visibility() -> void:
	_sync_combat_art_visibility()
	var boss := run.bosses.actor
	var entrance: RefCounted = boss.get("entrance") if boss != null else null
	_entrance_skip.visible = run.state.phase == RunState.Phase.PLAY and entrance != null and entrance.active and entrance.time >= 0.4
	_draw_button.visible = _can_show_draw_button(DisplayServer.is_touchscreen_available())

func _can_show_draw_button(touchscreen: bool) -> bool:
	return touchscreen and run.state.cinematic_bars <= 0.0 and _menu_overlay == null and not _rewards.is_active() and run.state.phase == RunState.Phase.PLAY

func _sync_combat_art_visibility() -> void:
	var state := run.state
	var cinematic := state != null and state.cinematic_bars > 0.0
	var combat_visible := show_status and state != null and state.phase not in [RunState.Phase.DYING, RunState.Phase.FINISHING] and not cinematic
	_loadout_icons.visible = combat_visible or (cinematic and not state.final_modules.is_empty())
	_speed_indicator.visible = combat_visible

func _update_finish_presentation() -> void:
	if run.state.phase != RunState.Phase.FINISHING:
		return
	var start := run.finish_reveal_start()
	var duration := run.finish_reveal_duration()
	_finish_skip.visible = run.sequence_t >= 0.35 and run.sequence_t < start + duration
	if _legendary_reveal == null:
		return
	_legendary_reveal.visible = duration > 0.0 and run.sequence_t >= start and run.sequence_t < start + duration
	if not _legendary_reveal.visible:
		return
	if _legendary_reveal.has_method("set_endpoints"):
		var s := run.state
		_legendary_reveal.set_endpoints((run.finish_origin - s.view_center) * s.camera_zoom + size / 2.0,
			(s.ship_pos - s.view_center) * s.camera_zoom + size / 2.0)
	_legendary_reveal.set_progress(clampf((run.sequence_t - start) / maxf(0.001, duration), 0.0, 1.0))

func _layout_art() -> void:
	var factor := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	var origin := (size - ART_SIZE * factor) * 0.5
	_speed_indicator.position = (size - (SPEED_INDICATOR.METER.get_size() + Vector2.ONE * 8.0) * factor).round()
	_speed_indicator.scale = Vector2.ONE * factor
	_loadout_icons.position = origin
	_loadout_icons.scale = Vector2.ONE * factor
	_cards_box.position = origin
	_cards_box.scale = Vector2.ONE * factor
	_cards_box.size = ART_SIZE
	_sync_combat_art_visibility()

func _make_bar_fill(frame: Texture2D) -> AtlasTexture:
	var source := frame.get_image()
	var image := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	var bounds := source.get_used_rect()
	# 素材の左右の縁の間だけ埋め、欠けた角もピクセル単位で合わせる。
	for y in range(bounds.position.y, bounds.end.y):
		var left := bounds.end.x
		var right := bounds.position.x
		for x in range(bounds.position.x, bounds.end.x):
			if source.get_pixel(x, y).a > 0.0:
				left = mini(left, x)
				right = maxi(right, x)
		for x in range(left + 1, right):
			if source.get_pixel(x, y).a == 0.0:
				image.set_pixel(x, y, Color.WHITE)
	var fill := AtlasTexture.new()
	fill.atlas = ImageTexture.create_from_image(image)
	fill.region = image.get_used_rect()
	return fill

func _draw_bar(frame: Texture2D, fill: AtlasTexture, fraction: float, color: Color) -> void:
	var area := fill.region
	area.size.x = roundf(area.size.x * clampf(fraction, 0.0, 1.0))
	if area.size.x > 0:
		draw_texture_rect_region(fill.atlas, area, area, color)
	draw_texture(frame, Vector2.ZERO)

func _add_icon(parent: Control, definition: Resource, area: Rect2) -> void:
	CARD_VIEW.add_icon(parent, definition, area)

func _refresh_loadout_icons() -> void:
	if run.state == null:
		return
	var key := str(run.state.weapons) + str(run.state.traits) + str(run.state.final_modules) + str(run.state.cinematic_bars > 0.0)
	if key == _loadout_key:
		return
	_loadout_key = key
	for child in _loadout_icons.get_children():
		child.queue_free()
	var row := 0
	for owned in [run.state.weapons, run.state.traits]:
		if run.state.cinematic_bars > 0.0:
			row += 1
			continue
		if row==0 and not run.state.final_modules.is_empty():
			row+=1
			continue
		var index := 0
		for id in owned:
			var at := (LOADOUT_WEAPON if row == 0 else LOADOUT_TRAIT) + Vector2(index * LOADOUT_STEP, 0)
			var area := Rect2(at + Vector2(2, 2), Vector2(12, 10))
			var definition: Resource = ContentManager.catalog.find(&"weapons" if row == 0 else &"traits", id)
			if row == 0 and definition != null and definition.comet_only:
				_add_comet_slot_frame(Rect2(at, Vector2(LOADOUT_SLOT, 17)))
			_add_icon(_loadout_icons, definition, area)
			index += 1
		row += 1
	for j in run.state.final_modules.size():
		var preview=preload("res://scripts/ui/legendary_module_icon.gd").new()
		preview.position=LOADOUT_WEAPON+Vector2(j*LOADOUT_STEP+2,2)
		preview.size=Vector2(12,10)
		preview.module_id=run.state.final_modules[j]
		_loadout_icons.add_child(preview)

func _add_comet_slot_frame(area: Rect2) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = SLOTS
	texture.region = area
	var material := ShaderMaterial.new()
	material.shader = COMET_SLOT_FRAME
	material.set_shader_parameter("frame_color", COMET_ONLY_COLOR)
	var frame := TextureRect.new()
	frame.texture = texture
	frame.material = material
	frame.position = area.position
	frame.size = area.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loadout_icons.add_child(frame)

# ── 3択 ──────────────────────────────────────────────────────────

func _build_cards() -> void:
	_cards_dim = ColorRect.new()
	_cards_dim.color = Color(0, 0, 0, 0.28)
	_cards_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_dim.hide()
	add_child(_cards_dim)
	_cards_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cards_box = Control.new()
	_cards_box.size = ART_SIZE
	_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_box.visible = false
	_cards_title = Label.new()
	_cards_title.position = Vector2(89, 61)
	_cards_title.size = Vector2(464, 20)
	_cards_title.add_theme_font_size_override("font_size", 10)
	_cards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_box.add_child(_cards_title)
	_cards_row = Control.new()
	_cards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_box.add_child(_cards_row)
	_reroll_button = Button.new()
	_reroll_button.position = Vector2(265, 288)
	_reroll_button.size = Vector2(112, 29)
	_reroll_button.add_theme_font_size_override("font_size", 9)
	_card_art(_reroll_button, Rect2(265, 288, 112, 29))
	_reroll_button.pressed.connect(func(): _card_command(&"reroll"))
	_cards_box.add_child(_reroll_button)
	add_child(_cards_box)
	_build_swap_cards()

func _card_art(button: Button, region: Rect2) -> void:
	CARD_VIEW.apply_art(button, region)

func _build_swap_cards() -> void:
	_swap_box = Control.new()
	_swap_box.size = ART_SIZE
	_swap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swap_box.hide()
	_cards_box.add_child(_swap_box)
	var arrow := Line2D.new()
	arrow.points = PackedVector2Array([Vector2(320, 225), Vector2(320, 235), Vector2(316, 231), Vector2(320, 235), Vector2(324, 231)])
	arrow.width = 1.0
	arrow.default_color = COMET_ONLY_COLOR
	_swap_box.add_child(arrow)
	_swap_grid = GridContainer.new()
	_swap_grid.position = Vector2(136, 240)
	_swap_grid.size = Vector2(368, 80)
	_swap_grid.columns = 4
	_swap_grid.add_theme_constant_override("h_separation", 16)
	_swap_box.add_child(_swap_grid)
	_swap_keep = Button.new()
	_swap_keep.position = Vector2(264, 327)
	_swap_keep.size = Vector2(112, 29)
	_swap_keep.add_theme_font_size_override("font_size", 9)
	_card_art(_swap_keep, Rect2(265, 288, 112, 29))
	_swap_keep.pressed.connect(func(): _card_command(&"choose_card", {"index": _swap_keep_index}))
	_swap_keep.hide()
	_swap_box.add_child(_swap_keep)

func _show_cards() -> void:
	_cards_accept_at = Time.get_ticks_usec() + roundi(card_input_delay * 1_000_000.0)
	_card_discard.merge(_card_held)
	run.input.cancel_gesture()
	# 古いカードを外してから、通常カードか交換候補を作る。
	for row in [_cards_row, _swap_grid]:
		for c in row.get_children():
			row.remove_child(c)
			c.queue_free()
	var cards := run.state.cards
	var start: bool = run.state.start_pick
	var swap: StringName = run.state.swap_pick
	_cards_title.visible = swap == &""
	_cards_row.visible = swap == &""
	_swap_box.visible = swap != &""
	_swap_keep.visible = swap != &""
	_swap_keep_index = -1
	if swap != &"":
		var got: ContentEntry = ContentManager.catalog.find(&"weapons", swap)
		if _swap_new_card != null:
			_swap_box.remove_child(_swap_new_card)
			_swap_new_card.queue_free()
		# 通常カードと同じ生成経路を使い、新武器の情報表示だけを行う。
		_swap_new_card = CARD_VIEW.create({"tag": tr("card.new_weapon"), "name": got.get_display_name(), "desc": got.get_description()}, -1, 144, 10, got)
		_swap_new_card.position = Vector2(248, 28)
		_swap_new_card.focus_mode = Control.FOCUS_NONE
		_swap_new_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		CARD_VIEW.set_palette(_swap_new_card, COMET_ONLY_COLOR, Color("#371b23"))
		_swap_box.add_child(_swap_new_card)
		_swap_new_name = _swap_new_card.get_node("Name")
		_swap_new_desc = _swap_new_card.get_node("Description")
		for i in cards.size():
			if cards[i].kind == &"keep":
				_swap_keep_index = i
				var info := card_info(cards[i], run.cfg.trait_max_stacks)
				_swap_keep.text = info.name
			else:
				var definition: Resource = ContentManager.catalog.find(&"weapons", cards[i].id)
				var b := CARD_VIEW.create_weapon_slot(definition)
				var info := card_info(cards[i], run.cfg.trait_max_stacks)
				b.tooltip_text = "%s\n%s" % [info.name, info.desc]
				b.pressed.connect(func(): _card_command(&"choose_card", {"index": i}))
				_swap_grid.add_child(b)
		_link_swap_focus()
	else:
		_cards_title.text = tr("hud.start_title") if start else tr("hud.levelup_title")
		var width := minf(144.0, (464.0 - 16.0 * (cards.size() - 1)) / maxi(1, cards.size()))
		var left := 89.0 + (464.0 - (cards.size() * width + maxi(0, cards.size() - 1) * 16.0)) / 2.0
		for i in cards.size():
			var info := card_info(cards[i], run.cfg.trait_max_stacks)
			var card: Dictionary = cards[i]
			var definition: Resource = ContentManager.catalog.find(&"traits" if card.kind == &"trait" else &"weapons", card.id)
			var b := CARD_VIEW.create(info, i, width, 10 if cards.size() <= 3 else 8, definition, card.kind == &"post_max")
			b.position = Vector2(left + i * (width + 16), 83)
			b.pressed.connect(func(): _card_command(&"choose_card", {"index": i}))
			_cards_row.add_child(b)
	var left := run.state.rerolls_left
	_reroll_button.text = tr("hud.reroll").format({n = left, key = OS.get_keycode_string(InputActions.key_of(&"reroll"))})
	_reroll_button.disabled = left <= 0
	_reroll_button.visible = swap == &""
	_layout_art()
	_sync_menu_visibility()
	var row: Control = _swap_grid if swap != &"" else _cards_row
	if row.get_child_count() > 0:
		_focus_card.call_deferred(weakref(row.get_child(0)))

func _focus_card(reference: WeakRef) -> void:
	var button: Control = reference.get_ref()
	if button != null and button.is_visible_in_tree():
		button.grab_focus()

func _link_swap_focus() -> void:
	var buttons: Array[Control] = []
	for button: Control in _swap_grid.get_children():
		buttons.append(button)
	buttons.append(_swap_keep)
	for i in buttons.size():
		var button := buttons[i]
		button.focus_next = button.get_path_to(buttons[(i + 1) % buttons.size()])
		button.focus_previous = button.get_path_to(buttons[posmod(i - 1, buttons.size())])
		if button != _swap_keep:
			button.focus_neighbor_left = button.get_path_to(buttons[posmod(i - 1, buttons.size() - 1)])
			button.focus_neighbor_right = button.get_path_to(buttons[(i + 1) % (buttons.size() - 1)])
			button.focus_neighbor_bottom = button.get_path_to(_swap_keep)
	_swap_keep.focus_neighbor_top = _swap_keep.get_path_to(buttons[0])

## カードの表示内容（仕様書 9.2）。色は取得後の段階（仕様書 8）。
static func card_info(c: Dictionary, trait_max_stacks := -1) -> Dictionary:
	if c.kind == &"post_max": return c.info
	if c.kind == &"swap" or c.kind == &"keep":
		if c.kind == &"keep":
			var new_def: ContentEntry = ContentManager.catalog.find(&"weapons", c.new)
			return {"tag": "", "name": TranslationServer.translate("card.discard_weapon").format({name = new_def.get_display_name()}),
				"desc": "", "color": Color("#6b7690")}
		var old_def: ContentEntry = ContentManager.catalog.find(&"weapons", c.id)
		var old_name := old_def.get_display_name() if old_def.comet_only else "%s Lv%d" % [old_def.get_display_name(), c.level]
		return {"tag": TranslationServer.translate("card.swap_tag"), "name": old_name,
			"desc": old_def.get_description(),
			"color": COMET_ONLY_COLOR if old_def.comet_only else RANK_COLORS[clampi(c.level - 1, 0, 4)]}
	if c.kind == &"heal":
		return {"tag": TranslationServer.translate("card.heal_tag"), "name": TranslationServer.translate("card.heal_name"),
			"desc": TranslationServer.translate("card.heal_desc"), "color": Color("#6dffb0")}
	var weapon: bool = c.kind == &"weapon"
	var def = ContentManager.catalog.find(&"weapons" if weapon else &"traits", c.id)
	var lv: int = c.level
	var tag := ("card.new_weapon" if weapon else "card.new_trait") if lv == 1 else ("card.weapon_up" if weapon else "card.trait_up")
	if c.get("start", false):
		tag = "card.first_weapon"
	var max_stacks: int = ContentManager.cfg.trait_max_stacks if trait_max_stacks < 0 else trait_max_stacks
	var suffix := "Lv%d" % lv if weapon else "%d/%d" % [lv, max_stacks]
	return {"tag": TranslationServer.translate(tag), "name": "%s %s" % [def.get_display_name(), suffix], "desc": def.get_description(),
		"color": RANK_COLORS[clampi(lv - 1, 0, 4)]}

# ── ポーズ ───────────────────────────────────────────────────────

func _build_pause() -> void:
	_pause_box = VBoxContainer.new()
	_pause_box.set_anchors_preset(Control.PRESET_CENTER)
	_pause_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_pause_box.add_theme_constant_override("separation", 14)
	_pause_box.visible = false
	var title := Label.new()
	title.text = "hud.pause"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_box.add_child(title)
	var resume := Button.new()
	resume.text = "hud.resume"
	resume.custom_minimum_size = Vector2(320, 52)
	resume.pressed.connect(func(): run.command(&"resume"))
	_pause_box.add_child(resume)
	var settings := Button.new()
	settings.text = "menu.settings"
	settings.custom_minimum_size = Vector2(320, 52)
	settings.pressed.connect(_open_settings.bind(settings))
	_pause_box.add_child(settings)
	var quit := Button.new()
	quit.text = "hud.quit_run"
	quit.custom_minimum_size = Vector2(320, 52)
	quit.pressed.connect(_confirm_abort)
	_pause_box.add_child(quit)
	add_child(_pause_box)

func _confirm_abort() -> void:
	if run.state.phase != RunState.Phase.PAUSED or not can_show_menu_overlay(): return
	var dialog := preload("res://scripts/ui/run_exit_confirmation.gd").new()
	dialog.input_id = _card_input_id
	dialog.held_inputs = _card_held
	dialog.discarded_inputs = _card_discard
	dialog.input_delay = card_input_delay
	add_child(dialog)
	show_menu_overlay(dialog)
	dialog.finished.connect(func(confirmed: bool):
		if confirmed:
			# 遷移が完了するまで確認画面が入力を受け止める。
			run.command(&"abort")
		else:
			close_menu_overlay(dialog)
			dialog.queue_free())

## ポーズ中に設定を重ねて開く。戻ると閉じてポーズに戻る。
func _open_settings(from: Button) -> void:
	AudioManager.play(&"ui")
	_settings = SETTINGS_SCENE.instantiate() as UiScreen
	_settings.close_fn = func():
		_settings.set_process_unhandled_input(false)
		_settings.queue_free()
		_settings = null
		_pause_box.visible = true
		from.grab_focus()
	_pause_box.visible = false
	add_child(_settings)

# ── 描画（HUD） ─────────────────────────────────────────────────

func _draw() -> void:
	if bridge!=null:
		_draw_cpp()
		return
	var s := run.state
	if s == null:
		return
	if s.cinematic_bars > 0.0:
		return
	var W := size.x
	_pause_box.position = (size - _pause_box.size) / 2.0
	if s.phase == RunState.Phase.DYING or s.phase == RunState.Phase.FINISHING:
		_draw_banner()
		return
	var factor := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	draw_set_transform((size - ART_SIZE * factor) * 0.5, 0.0, Vector2.ONE * factor)
	# 画面の端の矢印をミニマップから避けるため、画面上の位置と枠を含む半径を覚える（0 ならミニマップなし）
	_minimap_at = (size - ART_SIZE * factor) * 0.5 + MINIMAP_CENTER * factor
	_minimap_r = (MINIMAP_R + 12.0) * factor if show_minimap else 0.0
	if show_minimap:
		_draw_minimap()
	if show_status:
		# 素材の体力枠の内側に、現在のHPの割合を描く。
		var hp := clampf(s.ship_hp / maxf(1.0, s.stats.max_hp), 0.0, 1.0)
		var health_color := Color("#ff526e") if hp <= 0.1 else Color("#ffe46b") if hp < 0.5 else Color("#67e8b1")
		_draw_bar(HEALTH, _health_fill, hp, health_color)
		draw_string(_font, Vector2(7, 40), "%d/%d" % [ceili(maxf(0.0, s.ship_hp)), roundi(s.stats.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CYAN)
		draw_string(_font, Vector2(7, 52), "ATK %.1f  %s  Lv %d  %s" % [run.combat.attack_power(), tr("hud.kills").format({n = s.kills}), s.level, tr("common.parts").format({n = s.coins})], HORIZONTAL_ALIGNMENT_LEFT, 260, 8, CYAN)
		_draw_bar(EXPERIENCE, _experience_fill, s.xp / run.loadout.xp_needed(), Color("#b8a0ff"))
		draw_string(_font, Vector2(280, 23), "%d:%02d" % [int(s.time) / 60, int(s.time) % 60], HORIZONTAL_ALIGNMENT_CENTER, 80, 15, CYAN)
		if s.bonus_t > 0.0:
			draw_string(_font, Vector2(240, 37), tr("hud.bonus").format({n = ceili(s.bonus_t)}), HORIZONTAL_ALIGNMENT_CENTER, 160, 10, CYAN)
		_draw_loadout()
	draw_set_transform(Vector2.ZERO)
	if show_status:
		_draw_boss(W)
		if _hero_notice_t > 0.0 and run.heroes.guidance_visible() and not _rewards.is_active():
			var text := tr("hud.hero_discovered")
			var font_size := mini(24, int((W - 24.0) / maxf(1.0, _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x) * 24.0))
			draw_string(_font, Vector2(12.0, MINIMAP_R * 2.0 + 42.0 if W < 600.0 else 110.0), text, HORIZONTAL_ALIGNMENT_CENTER, W - 24.0,
				font_size, Color(1.0, 0.91, 0.63, minf(1.0, _hero_notice_t / 0.4)))
		if run.heroes.guidance_visible() and run.heroes.revealed() and run.heroes.is_captive():
			_draw_edge_arrow(run.heroes.center, Color("#ffd24a"))
		for p in run.field.rare_comet_positions():
			_draw_edge_arrow(p, Color("#ffd24a"))
		_draw_gauge_ring()

var _dense := PackedVector2Array()
var _minimap_at := Vector2.ZERO
var _minimap_r := 0.0

func _speed_indicator_mode() -> int:
	if bridge!=null:
		if _cpp_ui.get("tracing",false) or float(_cpp_ui.get("ship_boost_t",0.0))>0.0: return SPEED_INDICATOR.BOOST
		if _cpp_ui.get("glide",false) or Vector2(_cpp_ui.get("ship_vel",Vector2.ZERO)).length()>float(_cpp_ui.get("max_speed",0.0))*float(_cpp_ui.get("steer_cruise",0.0))+1.0: return SPEED_INDICATOR.FAST
		return SPEED_INDICATOR.NORMAL
	var s := run.state
	if s.tracing or s.ship_boost_t > 0.0: return 2
	if s.glide or s.ship_vel.length() > s.stats.max_speed * run.cfg.steer_cruise + 1.0: return 1
	return 0

func _update_speed_indicator(delta: float) -> void:
	if bridge!=null:
		if _cpp_ui.get("phase",-1)==0 and _cpp_ui.get("input_enabled",false): _speed_indicator.advance(_speed_indicator_mode(),delta)
		return
	if run.state.phase != RunState.Phase.PLAY or run.ui_overlay_active or run.ui_reward_active:
		return
	_speed_indicator.advance(_speed_indicator_mode(), delta)

## ミニマップ（右上）。自機を中心に、世界の方角と縮尺を保って出す（仕様書 17）。
## 自機・ボス・カプセル・敵の多い所・目印の星の線・英雄の星座。
func _draw_minimap() -> void:
	var s := run.state
	var cfg := run.cfg
	var R := MINIMAP_R
	var c := MINIMAP_CENTER
	var k := R / cfg.field_radius
	draw_texture(RADAR, Vector2.ZERO)
	# 世界の外縁と惑星も自機からの相対位置へ移し、円内だけ描く。
	var world_center := _minimap_offset(Vector2.ZERO)
	for n in 96:
		var a := world_center + Vector2.from_angle(n * TAU / 96.0) * R
		var b := world_center + Vector2.from_angle((n + 1) * TAU / 96.0) * R
		var segment := _minimap_segment(a, b)
		if segment.size() == 2:
			draw_line(c + segment[0], c + segment[1], Color(0.7, 0.8, 1.0, 0.35), 1.0)
	if run.field.bodies.has(run.field.planet):
		var planet_shape := _minimap_disk(_minimap_offset(run.field.planet.pos), run.field.planet.r * k)
		for polygon: PackedVector2Array in planet_shape:
			draw_colored_polygon(Transform2D(0.0, c) * polygon, Color(0.45, 0.5, 0.65, 0.6))
	# 敵の多い所（数フレームに1回数え直す）
	if Engine.get_process_frames() % 15 == 0:
		_dense = _dense_cells()
	for p in _dense:
		var offset := _minimap_offset(p)
		if offset.length() <= R - 3.5:
			draw_circle(c + offset, 3.5, Color(1.0, 0.35, 0.35, 0.35))
	for cap: Pickup in run.pickups.capsules:
		draw_circle(c + _minimap_marker(cap.pos, 2.0), 2.0, _minimap_pickup_color(cap.kind))
	# 目印の星の線：取り戻した位置から英雄の星座を通る直線。2体そろうと線を消す。
	var h := run.heroes
	var gold := Color("#ffe8a0")
	if h.guidance_visible() and h.hero != null and h.is_captive():
		for q in s.landmarks:
			var a := _minimap_offset(q)
			var u := (h.center - q).normalized()
			var b := a.dot(u)
			var disc := b * b - a.length_squared() + R * R
			if disc > 0.0 and s.landmarks.size() < 2:
				var r0 := sqrt(disc)
				draw_line(c + a + u * (-b - r0), c + a + u * (-b + r0), Color(gold, 0.7), 1.5)
			draw_circle(c + _minimap_marker(q, 3.0), 3.0, gold)
	if h.guidance_visible() and h.revealed():
		var at := c + _minimap_marker(h.center, 6.0)
		var tw := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
		draw_circle(at, 6.0 * tw, Color(gold, 0.35))
		draw_circle(at, 3.0, gold if h.is_captive() else Color(gold, 0.45))
	if run.bosses.boss_alive():
		draw_circle(c + _minimap_marker(run.bosses.boss_pos(Vector2.ZERO), 4.0), 4.0, Color("#ff526e"))
	var head := s.ship_heading if s.ship_heading != Vector2.ZERO else Vector2.UP
	var sp := c
	var side := Vector2(-head.y, head.x)
	draw_colored_polygon(PackedVector2Array([sp + head * 6.0, sp - head * 4.0 + side * 4.0, sp - head * 4.0 - side * 4.0]),
		Color.WHITE)

## カプセル類の印の色。ゲーム内の見た目に合わせ、英雄の星座の金色と分ける。
func _minimap_pickup_color(kind: Pickup.Kind) -> Color:
	match kind:
		Pickup.Kind.HEAL:
			return Color("#67e8b1")
		Pickup.Kind.MAGNET:
			return Color("#b8a0ff")
		_:
			return Color("#5fd8ff")

## 地図は自機を原点にする。方角と距離の縮尺は世界と共通。
func _minimap_offset(world_pos: Vector2) -> Vector2:
	return (world_pos - run.state.ship_pos) * MINIMAP_R / run.cfg.field_radius

## 円外の目標は方向を保って内縁へ寄せ、印全体を円内に収める。
func _minimap_marker(world_pos: Vector2, radius: float) -> Vector2:
	return _minimap_offset(world_pos).limit_length(MINIMAP_R - radius)

## 円形マスクで線分を切る。世界外縁が円の外へ続く部分を描かない。
static func _minimap_segment(a: Vector2, b: Vector2) -> PackedVector2Array:
	var length := a.distance_to(b)
	if length <= 0.0001:
		return PackedVector2Array()
	var u := (b - a) / length
	var along := a.dot(u)
	var disc := along * along - a.length_squared() + MINIMAP_R * MINIMAP_R
	if disc <= 0.0:
		return PackedVector2Array()
	var root := sqrt(disc)
	var first := maxf(0.0, -along - root)
	var last := minf(length, -along + root)
	return PackedVector2Array([a + u * first, a + u * last]) if last > first else PackedVector2Array()

static func _minimap_disk(at: Vector2, radius: float) -> Array[PackedVector2Array]:
	if at.length() >= MINIMAP_R + radius:
		return []
	var disk := PackedVector2Array()
	var mask := PackedVector2Array()
	for n in 64:
		var u := Vector2.from_angle(n * TAU / 64.0)
		disk.append(at + u * radius)
		mask.append(u * MINIMAP_R)
	return Geometry2D.intersect_polygons(disk, mask)

## 敵の多い所：フィールドを升目に分け、敵が一定より多い升目の中心（世界座標）。
func _dense_cells() -> PackedVector2Array:
	var t := run.enemies.table
	var fr := run.cfg.field_radius
	var n := 16
	var cell := fr * 2.0 / n
	var counts := PackedInt32Array()
	counts.resize(n * n)
	for i in t.alive.size():
		if t.alive[i] == 0 or t.dead[i] != 0 or t.meteor_index[i] >= 0:
			continue
		var gx := clampi(int((t.pos[i].x + fr) / cell), 0, n - 1)
		var gy := clampi(int((t.pos[i].y + fr) / cell), 0, n - 1)
		counts[gy * n + gx] += 1
	var out := PackedVector2Array()
	for g in counts.size():
		if counts[g] >= 12:
			out.append(Vector2((g % n + 0.5) * cell - fr, (g / n + 0.5) * cell - fr))
	return out

## 装備一覧（左下）。武器と特性を別の段の枠に並べ、空き枠も薄く描いて持てる数を見せる（仕様書 17）。
## 下の目盛りは強化の段階（仕様書 8）。
## 枠の中は能力IDに対応する専用アイコンを表示する。
func _draw_loadout() -> void:
	draw_texture_rect_region(SLOTS, LOADOUT_REGION, LOADOUT_REGION)
	_draw_slot_row(LOADOUT_WEAPON, true, run.cfg.weapon_slots, run.cfg.weapon_max_level, run.state.weapons, ContentManager.catalog.table(&"weapons"))
	_draw_slot_row(LOADOUT_TRAIT, false, run.cfg.trait_slots, run.cfg.trait_max_stacks, run.state.traits, ContentManager.catalog.table(&"traits"))
	_draw_hero_slot(LOADOUT_HERO)

func _draw_hero_slot(at: Vector2) -> void:
	var s := run.state
	if s.hero_power == &"":
		return
	var rect := Rect2(at + Vector2(3, 3), Vector2(29, 29))
	var definition: HeroDef = ContentManager.heroes.get(s.hero_power)
	var gold := Color("#ffe8a0")
	if definition != null and not definition.stars.is_empty():
		var bounds := Rect2(definition.stars[0], Vector2.ZERO)
		for point in definition.stars:
			bounds = bounds.expand(point)
		var factor := 24.0 / maxf(1.0, maxf(bounds.size.x, bounds.size.y))
		var center := rect.get_center()
		for i in range(0, definition.links.size(), 2):
			var a := center + (definition.stars[definition.links[i]] - bounds.get_center()) * factor
			var b := center + (definition.stars[definition.links[i + 1]] - bounds.get_center()) * factor
			draw_line(a, b, gold, 1)
		for point in definition.stars:
			draw_circle(center + (point - bounds.get_center()) * factor, 1, gold)
	if s.hero_active_t > 0.0:
		draw_rect(rect, Color(gold, 0.2 + 0.1 * sin(Time.get_ticks_msec() / 120.0)))
	if s.hero_cd > 0.0 and definition != null and definition.cooldown > 0.0:
		var k := clampf(s.hero_cd / definition.cooldown, 0, 1)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * (1 - k)), Vector2(rect.size.x, rect.size.y * k)), Color(0, 0, 0, 0.65))
	draw_string(_font, at + Vector2(24, 31), OS.get_keycode_string(InputActions.key_of(&"hero")), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, gold)
	if s.hero_active_t > 0.0:
		draw_string(_font, at + Vector2(35, 15), "%ds" % ceili(s.hero_active_t), HORIZONTAL_ALIGNMENT_LEFT, 32, 9, gold)

func _draw_slot_row(origin: Vector2, weapon: bool, slots: int, max_level: int, owned: Dictionary, defs: Dictionary) -> void:
	var ids := owned.keys()
	for k in mini(slots, ids.size()):
		var rect := Rect2(origin + Vector2(k * LOADOUT_STEP, 0), Vector2(LOADOUT_SLOT, 17))
		var lv: int = owned[ids[k]]
		var col: Color = RANK_COLORS[clampi(lv - 1, 0, 4)]
		var definition = defs[ids[k]]
		if weapon and definition.comet_only:
			continue
		var pip_w := (LOADOUT_SLOT - 4.0) / max_level
		for j in max_level:
			draw_rect(Rect2(rect.position.x + 2 + j * pip_w, rect.end.y - 3, maxf(1, pip_w - 1), 1), col if j < lv else Color(1, 1, 1, 0.15))

func _draw_boss(W: float) -> void:
	var bosses := run.bosses
	var owner := bosses.actor
	if run.state.lab_mode:
		for candidate in bosses.actors:
			if candidate.body_alive():
				owner = candidate
				break
	if _warning_t > 0.0 and fmod(_warning_t, 0.5) < 0.3:
		draw_string(_font, Vector2(W / 2.0 - 160, 120), tr("hud.warning"), HORIZONTAL_ALIGNMENT_CENTER, 320, 48, Color("#ff526e"))
	if owner == null or not owner.body_alive():
		return
	var t := run.enemies.table
	var b: int = owner.health_row()
	if b<0 or b>=t.hp.size() or t.dead[b]:return
	var bw := minf(520.0, W * 0.6)
	var bx := W / 2.0 - bw / 2.0
	draw_rect(Rect2(bx, 60, bw, 10), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bx, 60, bw * clampf(t.hp[b] / t.max_hp[b], 0.0, 1.0), 10), Color("#ff526e"))
	_draw_edge_arrow(t.pos[b], Color("#ff526e"))

## 世界の位置 p が画面の外なら、画面の端にその向きの矢印を描く（ボス・英雄・レアな彗星）。
func _draw_edge_arrow(p: Vector2, col: Color) -> void:
	var s := run.state
	var rel := p - s.view_center
	if absf(rel.x) <= s.view_half.x and absf(rel.y) <= s.view_half.y:
		return
	var center := size / 2.0
	var dir := rel.normalized()
	var to_side := (size.x / 2.0 - 40.0) / maxf(absf(dir.x), 0.001)
	var to_top := (size.y / 2.0 - 40.0) / maxf(absf(dir.y), 0.001)
	var tip := center + dir * minf(to_side, to_top)
	# 右上のミニマップに重なるときは、画面の端に沿ってミニマップの外へずらす
	if _minimap_r > 0.0 and tip.distance_to(_minimap_at) < _minimap_r + 24.0:
		if to_side <= to_top:
			tip.y = _minimap_at.y + _minimap_r + 24.0
		else:
			tip.x = _minimap_at.x - _minimap_r - 24.0
	var side := Vector2(-dir.y, dir.x) * 12.0
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 24.0 + side, tip - dir * 24.0 - side]), col)

## カーソル付近のリング：描画前は溜まっている量、描画中は残りの長さ（仕様書 6.2）。
## 内側の1周が容量1、大容量チャージで増えた容量は外側の弧。内側から順に埋まる。
## 描けるまでは専用の不足色を使い、描ける量に目盛りを置く。描けるようになった瞬間に広がる輪、1周溜まりきった瞬間に白い光を出す。
func _draw_gauge_ring() -> void:
	var s := run.state
	var displayed := s.draw_gauge*(1.0-s.draw_length/maxf(1.0,s.draw_limit)) if s.drawing else s.gauge_amount()
	_draw_gauge_values(run.cfg.draw_min_charge,s.stats.capacity,s.gauge_amount(),s.drawing,not s.drawing and not s.tracing,displayed,s.traits.has(&"T36"))

func _draw_cpp_gauge_ring() -> void:
	var draw: Dictionary = _cpp_ui.draw
	var capacity := float(_cpp_ui.capacity)
	var amount := float(draw.gauge)*capacity
	var displayed := float(draw.draw_gauge)*(1.0-float(draw.draw_length)/maxf(1.0,float(draw.draw_limit))) if draw.drawing else amount
	_draw_gauge_values(float(_cpp_ui.min_charge),capacity,amount,draw.drawing,not draw.drawing and not draw.tracing,displayed,_cpp_ui.full_burst)

func _draw_gauge_values(min_charge: float,capacity: float,amount: float,drawing: bool,charging: bool,displayed: float,full_burst: bool) -> void:
	var c := get_viewport().get_mouse_position()+Vector2(26,26)
	var usable := amount >= min_charge
	if usable and not _ring_usable and charging:
		_ring_pulse_t = RING_PULSE_TIME
	_ring_usable = usable
	if charging and _lap_filled(_ring_amount, amount, capacity):
		_ring_flash_t = 0.1 if full_burst else RING_FLASH_TIME
		_ring_flash_max = 0.1 if full_burst else RING_FLASH_TIME
	_ring_amount = amount
	amount = displayed
	var flash := _ring_flash_t / _ring_flash_max if _ring_flash_t > 0.0 else 0.0
	var pulse := 1.0 - _ring_pulse_t / RING_PULSE_TIME if _ring_pulse_t > 0.0 else -1.0
	BOOST_GAUGE.draw(self, c, amount, capacity, min_charge, drawing, usable, flash, pulse, BOOST_STYLE, RING_GAP)

## 内側・外側のどれかのリングが、before から after の間に溜まりきったか
func _lap_filled(before: float, after: float, capacity: float) -> bool:
	for lap in ceili(capacity - 1e-6):
		var end := minf(lap + 1.0, capacity) - 1e-6
		if before < end and after >= end:
			return true
	return false

func _draw_banner() -> void:
	if _banner == "":
		return
	draw_string(_font, Vector2(0, size.y / 2.0), _banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 72, _banner_color)

func _exit_tree() -> void:
	if bridge!=null: bridge.unsubscribe("hud")
	AudioManager.set_slow_motion(false)
	if run != null and run.state != null and not run.state.lab_mode:
		AudioManager.stop_music(self)
	AudioManager.end_dash()

## C++の値のスナップショットだけを保持する。表示時計と乱数はHUDが所有する。
func apply_snapshot(ui: Dictionary) -> void:
	var previous: Dictionary = _cpp_ui.get("cards",{})
	var rerolls := int(_cpp_ui.get("rerolls_left",0))
	var phase := int(_cpp_ui.get("phase",-1))
	_cpp_ui = ui
	if _cards_box==null: return
	var cards: Dictionary = ui.get("cards",{})
	if previous!=cards or rerolls!=int(ui.get("rerolls_left",0)):
		if previous.get("offer_id",0)!=cards.get("offer_id",0):
			_cards_accept_at = Time.get_ticks_usec()+roundi(card_input_delay*1_000_000.0)
			_card_discard.merge(_card_held)
		_show_cpp_cards()
	elif phase!=int(ui.phase): _cpp_card_visibility()


func _ready_cpp() -> void:
	bridge.subscribe("hud",_receive_cpp_frame)
	_font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_indicator = SPEED_INDICATOR.new()
	add_child(_speed_indicator)
	_health_fill = _make_bar_fill(HEALTH)
	_experience_fill = _make_bar_fill(EXPERIENCE)
	_build_cards()
	_cpp_retry = Button.new()
	_cpp_retry.text = "もう一度準備する"
	_cpp_retry.position = Vector2(160,320)
	_cpp_retry.size = Vector2(150,26)
	_cpp_retry.pressed.connect(func():
		if int(_cpp_ui.phase)==RunState.Phase.LEVELUP:
			bridge.command("retry_resources",{"request_id":_cpp_ui.cards.request_id}))
	_cards_box.add_child(_cpp_retry)
	_cpp_cancel = Button.new()
	_cpp_cancel.text = "選び直す"
	_cpp_cancel.position = Vector2(330,320)
	_cpp_cancel.size = Vector2(150,26)
	_cpp_cancel.pressed.connect(func(): _card_command(&"cancel_choice"))
	_cards_box.add_child(_cpp_cancel)
	resized.connect(_layout_cpp_art)
	_layout_cpp_art()

func _layout_cpp_art() -> void:
	var factor := minf(size.x/ART_SIZE.x,size.y/ART_SIZE.y)
	_speed_indicator.position = (size-(SPEED_INDICATOR.METER.get_size()+Vector2.ONE*8.0)*factor).round()
	_speed_indicator.scale = Vector2.ONE*factor
	_cards_box.position = ((size-ART_SIZE*factor)*0.5).round()
	_cards_box.scale = Vector2.ONE*factor

func _draw_cpp() -> void:
	if _cpp_ui.is_empty() or not show_status: return
	var factor := minf(size.x/ART_SIZE.x,size.y/ART_SIZE.y)
	draw_set_transform((size-ART_SIZE*factor)*0.5,0.0,Vector2.ONE*factor)
	var hp := clampf(float(_cpp_ui.hp)/maxf(1.0,float(_cpp_ui.max_hp)),0.0,1.0)
	_draw_bar(HEALTH,_health_fill,hp,Color("#ff526e") if hp<=0.1 else Color("#ffe46b") if hp<0.5 else Color("#67e8b1"))
	draw_string(_font,Vector2(7,40),"%d/%d" % [ceili(maxf(0.0,float(_cpp_ui.hp))),roundi(float(_cpp_ui.max_hp))],HORIZONTAL_ALIGNMENT_LEFT,-1,14,CYAN)
	_draw_bar(EXPERIENCE,_experience_fill,float(_cpp_ui.get("xp",0.0))/maxf(1.0,float(_cpp_ui.get("next_xp",1.0))),Color("#b8a0ff"))
	var seconds := int(_cpp_ui.run_time)
	draw_string(_font,Vector2(280,23),"%d:%02d" % [seconds/60,seconds%60],HORIZONTAL_ALIGNMENT_CENTER,80,15,CYAN)
	if float(_cpp_ui.get("bonus_remaining",0.0))>0.0:
		draw_string(_font,Vector2(240,37),tr("hud.bonus").format({n=ceili(float(_cpp_ui.bonus_remaining))}),HORIZONTAL_ALIGNMENT_CENTER,160,10,CYAN)
	draw_set_transform(Vector2.ZERO)
	_draw_cpp_gauge_ring()
	_draw_banner()

func _cpp_card_visibility() -> void:
	_cards_box.visible = not _cpp_ui.is_empty() and int(_cpp_ui.phase)==RunState.Phase.LEVELUP and int(_cpp_ui.get("cards",{}).get("offer_id",0))!=0
	_cards_dim.visible = _cards_box.visible

func _show_cpp_cards() -> void:
	var state: Dictionary = _cpp_ui.get("cards",{})
	var cards: Array = state.get("candidates",[])
	for child in _cards_row.get_children():
		_cards_row.remove_child(child)
		child.queue_free()
	_swap_box.hide()
	var width := minf(144.0,(464.0-16.0*(cards.size()-1))/maxi(1,cards.size()))
	var left := 89.0+(464.0-(cards.size()*width+maxi(0,cards.size()-1)*16.0))*0.5
	for i in cards.size():
		var card: Dictionary = cards[i]
		var entry: ContentEntry = ContentManager.catalog.find(&"traits" if card.kind=="trait" else &"weapons",StringName(card.id))
		var button := CARD_VIEW.create(card_info(card),i,width,10,entry)
		button.position = Vector2(left+i*(width+16),83)
		button.pressed.connect(func(): _card_command(&"choose_card",{"index":i}))
		_cards_row.add_child(button)
	_cards_title.text = "準備に失敗しました。もう一度準備するか、選び直してください。" if int(state.get("error_code",0))<0 else "準備しています…" if state.get("preparing",false) else tr("hud.start_title") if state.get("initial",false) else tr("hud.levelup_title")
	var remaining := int(_cpp_ui.get("rerolls_left",0))
	_reroll_button.text = tr("hud.reroll").format({n=remaining,key=OS.get_keycode_string(InputActions.key_of(&"reroll"))})
	_reroll_button.disabled = remaining<=0
	_cpp_retry.visible = int(state.get("error_code",0))==-1
	_cpp_cancel.visible = int(state.get("selected_id",0))!=0
	_cpp_card_visibility()

func _input_cpp(event: InputEvent) -> void:
	if _cpp_ui.is_empty(): return
	if event.is_action_pressed(&"pause") and not event.is_echo():
		bridge.command("pause",{"paused":int(_cpp_ui.phase)!=RunState.Phase.PAUSED})
		_card_discard.merge(_card_held)
		get_viewport().set_input_as_handled()
		return
	var id := _card_input_id(event)
	if id=="": return
	var choosing := int(_cpp_ui.phase)==RunState.Phase.LEVELUP
	var blocked := _card_discard.has(id) or (choosing and Time.get_ticks_usec()<_cards_accept_at)
	if not event is InputEventScreenDrag:
		if event.is_pressed():
			_card_held[id] = true
			if blocked: _card_discard[id] = true
		else:
			_card_held.erase(id)
			_card_discard.erase(id)
	if blocked:
		get_viewport().set_input_as_handled()
		return
	if not choosing or event.is_echo(): return
	for i in 3:
		if event.is_action_pressed(StringName("card_%d" % (i+1))):
			_card_command(&"choose_card",{"index":i})
			get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"reroll"):
		_card_command(&"reroll")
		get_viewport().set_input_as_handled()

func _receive_cpp_frame(frame: Dictionary) -> bool:
	apply_snapshot(frame.ui)
	for event: Dictionary in frame.events:
		if event.type=="game_over":
			_banner = tr("hud.game_over")
			_banner_color = Color("#ff6b5a")
		elif event.type=="clear_banner":
			_banner = tr("hud.clear")
			_banner_color = Color("#ffe46b")
	return true
