## ラン中の HUD（仕様書 17）。状態を読んで表示するだけで、選んだ結果は RunSimulation に命令として渡す。
##
## 時間・経験値バー・状態の文字・装備一覧・ゲージのリング・3択・ボスの表示・ポーズ・
## 「描く」ボタン（タッチ）・CLEAR! と GAME OVER。
extends Control

## 描けるようになったときに広がる輪の時間（実秒）
const RING_PULSE_TIME := 0.35
## リングが1周溜まりきったときに白く光る時間（実秒）
const RING_FLASH_TIME := 0.3
## 内側のリングの半径と、外側のリングまでの間隔
const RING_RADIUS := 14.0
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
const CARDS := preload(ART + "combat_ui_boxes.png")
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

## 通常 ULT のカットインと独立した仮演出。setup / set_progress の契約はシーンのスクリプトを参照。
@export_group("伝説獲得の仮演出")
@export var legendary_reveal_scene: PackedScene
@export_file("*.tscn") var legendary_reveal_path := "res://scenes/run/legendary_reveal.tscn"
var _legendary_reveal: Control
var _finish_skip: Button
var _entrance_skip: Button
var _rewards: Control
## RunSession が木に入れる前に入れる
var run: RunSimulation
var _laser_audio: Node
var _font: Font
var _cards_box: Control
var _reroll_button: Button
var _cards_title: Label
var _cards_row: Control
var _swap_box: VBoxContainer
var _swap_scroll: ScrollContainer
var _swap_grid: GridContainer
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

func _ready() -> void:
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
	resized.connect(_layout_cards)
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
		if _rewards.is_active() or _card_held.has(id) or _card_discard.has(id):
			return id
		for action in [&"card_1", &"card_2", &"card_3", &"reroll", &"ui_accept", &"hero", &"draw_alt", &"pause"]:
			if event.is_action(action):
				return id
	return ""

func _card_command(command: StringName, args := {}) -> void:
	if _menu_overlay != null or _rewards.is_active() or run.state.phase != RunState.Phase.LEVELUP or Time.get_ticks_usec() < _cards_accept_at:
		return
	_card_discard.merge(_card_held)
	run.command(command, args)

func _unhandled_input(event: InputEvent) -> void:
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
	_loadout_icons.position = origin
	_loadout_icons.scale = Vector2.ONE * factor
	if _swap_box.visible:
		_layout_cards()
	else:
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
	if definition == null or definition is HeroDef:
		return
	var texture: Texture2D = preload("res://scripts/ui/module_icons.gd").texture_for(definition)
	if texture == null: return
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = area.position
	icon.size = area.size
	parent.add_child(icon)

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
			_add_icon(_loadout_icons, ContentManager.catalog.find(&"weapons" if row == 0 else &"traits", id), area)
			index += 1
		row += 1
	for j in run.state.final_modules.size():
		var preview=preload("res://scripts/ui/legendary_module_icon.gd").new()
		preview.position=LOADOUT_WEAPON+Vector2(j*LOADOUT_STEP+2,2)
		preview.size=Vector2(12,10)
		preview.module_id=run.state.final_modules[j]
		_loadout_icons.add_child(preview)

# ── 3択 ──────────────────────────────────────────────────────────

func _build_cards() -> void:
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
	var texture := AtlasTexture.new()
	texture.atlas = CARDS
	texture.region = region
	var style := StyleBoxTexture.new()
	style.texture = texture
	button.add_theme_stylebox_override("normal", style)
	for state in ["hover", "pressed", "focus", "disabled"]:
		var variant := style.duplicate() as StyleBoxTexture
		variant.modulate_color = Color(0.5, 0.5, 0.5) if state == "disabled" else Color(1.3, 1.3, 1.3)
		button.add_theme_stylebox_override(state, variant)
	button.add_theme_color_override("font_color", CYAN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)

func _build_swap_cards() -> void:
	_swap_box = VBoxContainer.new()
	_swap_box.hide()
	_cards_box.add_child(_swap_box)
	var heading := Label.new()
	heading.text = "card.new_weapon"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_swap_box.add_child(heading)
	_swap_scroll = ScrollContainer.new()
	_swap_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_swap_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_swap_scroll.follow_focus = true
	_swap_scroll.hide()
	_swap_box.add_child(_swap_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	_swap_scroll.add_child(content)
	# 新武器は情報だけを表示し、交換候補と同じボタンにはしない。
	var info := PanelContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := _card_style(COMET_ONLY_COLOR)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	info.add_theme_stylebox_override("panel", style)
	content.add_child(info)
	var labels := VBoxContainer.new()
	info.add_child(labels)
	_swap_new_name = Label.new()
	_swap_new_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(_swap_new_name)
	_swap_new_desc = Label.new()
	_swap_new_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(_swap_new_desc)
	var title := Label.new()
	title.text = "hud.swap_title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	_swap_grid = GridContainer.new()
	_swap_grid.add_theme_constant_override("h_separation", 16)
	_swap_grid.add_theme_constant_override("v_separation", 16)
	content.add_child(_swap_grid)
	_swap_keep = Button.new()
	_swap_keep.custom_minimum_size.y = 64
	_swap_keep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_swap_scroll.visible = swap != &""
	_swap_keep.visible = swap != &""
	if swap != &"":
		var got: ContentEntry = ContentManager.catalog.find(&"weapons", swap)
		_swap_new_name.text = got.get_display_name()
		_swap_new_desc.text = got.get_description()
		for i in cards.size():
			if cards[i].kind == &"keep":
				_swap_keep_index = i
				var info := card_info(cards[i], run.cfg.trait_max_stacks)
				_swap_keep.text = "%s\n%s" % [info.tag, info.desc]
			else:
				var b := _card_button(cards[i], i, Vector2(0, 220))
				b.mouse_filter = Control.MOUSE_FILTER_PASS
				_swap_grid.add_child(b)
	else:
		_cards_title.text = tr("hud.start_title") if start else tr("hud.levelup_title")
		var width := minf(144.0, (464.0 - 16.0 * (cards.size() - 1)) / maxi(1, cards.size()))
		var left := 89.0 + (464.0 - (cards.size() * width + maxi(0, cards.size() - 1) * 16.0)) / 2.0
		for i in cards.size():
			var info := card_info(cards[i], run.cfg.trait_max_stacks)
			var b := Button.new()
			b.position = Vector2(left + i * (width + 16), 83)
			b.size = Vector2(width, 193)
			if cards[i].kind == &"post_max":
				var style := _card_style(info.color)
				style.bg_color = Color("#233c49")
				style.set_corner_radius_all(0)
				style.set_border_width_all(2)
				b.add_theme_stylebox_override("normal", style)
				var focus_style := style.duplicate() as StyleBoxFlat
				focus_style.border_color = Color("#c0ffff")
				for visual_state in ["focus", "hover", "pressed"]:
					b.add_theme_stylebox_override(visual_state, focus_style)
			else:
				_card_art(b, Rect2(89, 83, 145, 193))
			b.pressed.connect(func(): _card_command(&"choose_card", {"index": i}))
			_cards_row.add_child(b)
			var font_size := 10 if cards.size() <= 3 else 8
			for entry in [[Vector2(7, 5), Vector2(width - 14, 23), "%d. %s" % [i + 1, info.tag]],
				[Vector2(7, 34), Vector2(width - 14, 28), info.name],
				[Vector2(7, 65), Vector2(width - 14, 122 if cards[i].kind == &"post_max" else 57), info.desc]]:
				var label := Label.new()
				label.position = entry[0]
				label.size = entry[1]
				label.text = entry[2]
				label.add_theme_font_size_override("font_size", (17 if entry[0].y == 65 else 13) if cards[i].kind == &"post_max" else font_size)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.clip_text = true
				label.max_lines_visible = (2 if cards[i].kind == &"post_max" else 4) if entry[0].y == 65 else 2
				label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(label)
			var card: Dictionary = cards[i]
			var definition: Resource = ContentManager.catalog.find(&"traits" if card.kind == &"trait" else &"weapons", card.id)
			_add_icon(b, definition, Rect2(48 * width / 145.0, 129, 48 * width / 145.0, 48))
	var left := run.state.rerolls_left
	_reroll_button.text = tr("hud.reroll").format({n = left, key = OS.get_keycode_string(InputActions.key_of(&"reroll"))})
	_reroll_button.disabled = left <= 0
	_reroll_button.visible = swap == &""
	_layout_art()
	_layout_cards()
	var row: Control = _swap_grid if swap != &"" else _cards_row
	if row.get_child_count() > 0:
		_focus_card.call_deferred(weakref(row.get_child(0)))
	_swap_scroll.set_deferred("scroll_vertical", 0)

func _focus_card(reference: WeakRef) -> void:
	var button: Control = reference.get_ref()
	if button != null and button.is_visible_in_tree():
		button.grab_focus()

func _layout_cards() -> void:
	if _swap_box == null or not _swap_box.visible:
		return
	var width := maxf(1.0, minf(1100.0, size.x - 32.0))
	_swap_grid.columns = clampi(int((width + 16.0) / 236.0), 1, maxi(1, _swap_grid.get_child_count()))
	_cards_box.scale = Vector2.ONE
	_cards_box.size = Vector2(width, maxf(1.0, minf(600.0, size.y - 32.0)))
	_cards_box.position = (size - _cards_box.size) / 2.0
	_swap_box.size = _cards_box.size

func _card_button(card: Dictionary, index: int, minimum_size: Vector2) -> Button:
	var info := card_info(card, run.cfg.trait_max_stacks)
	var b := Button.new()
	b.custom_minimum_size = minimum_size
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = "%d. %s\n%s\n\n%s" % [index + 1, info.tag, info.name, info.desc]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var style := _card_style(info.color)
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.15, 0.24, 0.95)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(func(): _card_command(&"choose_card", {"index": index}))
	return b

func _card_style(col: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.95)
	style.border_color = col
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	return style

## カードの表示内容（仕様書 9.2）。色は取得後の段階（仕様書 8）。
static func card_info(c: Dictionary, trait_max_stacks := -1) -> Dictionary:
	if c.kind == &"post_max": return c.info
	if c.kind == &"swap" or c.kind == &"keep":
		if c.kind == &"keep":
			var new_def: ContentEntry = ContentManager.catalog.find(&"weapons", c.new)
			return {"tag": TranslationServer.translate("card.keep_tag"), "name": TranslationServer.translate("card.keep_name"),
				"desc": TranslationServer.translate("card.keep_desc").format({name = new_def.get_display_name()}), "color": Color("#6b7690")}
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
	if _cards_box.visible and _swap_box.visible:
		draw_rect(_cards_box.get_rect(), Color(0.06, 0.08, 0.14, 0.95))

var _dense := PackedVector2Array()
var _minimap_at := Vector2.ZERO
var _minimap_r := 0.0

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
			draw_rect(rect.grow(1), COMET_ONLY_COLOR, false, 1)
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
## 描けるまでは同じ色を暗くし、描ける量に目盛りを置く。描けるようになった瞬間に広がる輪、1周溜まりきった瞬間に白い光を出す。
func _draw_gauge_ring() -> void:
	var s := run.state
	var c := get_viewport().get_mouse_position() + Vector2(26, 26)
	var min_charge := run.cfg.draw_min_charge
	var capacity := s.stats.capacity
	var amount := s.gauge_amount()
	var usable := amount >= min_charge
	var charging := not s.drawing and not s.tracing
	if usable and not _ring_usable and charging:
		_ring_pulse_t = RING_PULSE_TIME
	_ring_usable = usable
	if charging and _lap_filled(_ring_amount, amount, capacity):
		_ring_flash_t = 0.1 if s.traits.has(&"T36") else RING_FLASH_TIME
		_ring_flash_max = 0.1 if s.traits.has(&"T36") else RING_FLASH_TIME
	_ring_amount = amount
	if s.drawing:
		amount = s.draw_gauge * (1.0 - s.draw_length / maxf(1.0, s.draw_limit))
	var flash := _ring_flash_t / _ring_flash_max if _ring_flash_t > 0.0 else 0.0
	var pulse := 1.0 - _ring_pulse_t / RING_PULSE_TIME if _ring_pulse_t > 0.0 else -1.0
	BOOST_GAUGE.draw(self, c, amount, capacity, min_charge, s.drawing, usable, flash, pulse, RING_RADIUS, RING_GAP)

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
	AudioManager.set_slow_motion(false)
	if run != null and run.state != null and not run.state.lab_mode:
		AudioManager.stop_music(self)
	AudioManager.end_dash()
