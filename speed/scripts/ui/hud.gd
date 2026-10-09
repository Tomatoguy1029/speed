## ラン中の HUD（仕様書 17）。状態を読んで表示するだけで、選んだ結果は RunManager に命令として渡す。
##
## 時間・経験値バー・状態の文字・速度メーター・装備一覧・ゲージのリング・3択・ボスの表示・ポーズ・
## 「描く」ボタン（タッチ）・CLEAR! と GAME OVER。
extends Control

const RANK_COLORS := [Color("#d5dbea"), Color("#8ed7a3"), Color("#3989ff"), Color("#bf91ef"), Color("#efcb70")]

@export var run_path: NodePath

var run: RunManager
var _font: Font
var _cards_box: VBoxContainer
var _reroll_button: Button
var _cards_row: HBoxContainer
var _pause_box: VBoxContainer
var _draw_button: Button
var _banner := ""
var _banner_t := 0.0
var _warning_t := 0.0

func _ready() -> void:
	run = get_node(run_path) as RunManager
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_cards()
	_build_pause()
	_draw_button = Button.new()
	_draw_button.text = "描く"
	_draw_button.custom_minimum_size = Vector2(120, 120)
	_draw_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_draw_button.position = Vector2(-150, -170)
	_draw_button.visible = DisplayServer.is_touchscreen_available()
	_draw_button.pressed.connect(func(): run.command(&"draw_button"))
	add_child(_draw_button)
	run.phase_changed.connect(_on_phase)
	run.cards_changed.connect(_show_cards)
	run.frame_events.connect(_on_events)

func _on_phase(phase: RunState.Phase) -> void:
	_cards_box.visible = phase == RunState.Phase.LEVELUP
	_pause_box.visible = phase == RunState.Phase.PAUSED
	if _pause_box.visible:
		_pause_box.get_child(1).grab_focus()

func _on_events(events: Array[Dictionary]) -> void:
	for ev in events:
		match ev.type:
			&"boss_spawn":
				_warning_t = 3.0
			&"clear_banner":
				_banner = "CLEAR!"
				_banner_t = 99.0
			&"game_over":
				_banner = "GAME OVER"
				_banner_t = 99.0
			&"levelup":
				AudioManager.play(&"levelup", -6.0)
			&"kill":
				if not ev.get("silent", false):
					AudioManager.play(&"kill", -10.0, randf_range(0.9, 1.2))
			&"hurt":
				AudioManager.play(&"hurt", -4.0)
			&"launch":
				AudioManager.play(&"dash", -6.0)
			&"bounce", &"block_impact":
				AudioManager.play(&"block", -8.0)
			&"boss_explode":
				AudioManager.play(&"boom")

func _unhandled_input(event: InputEvent) -> void:
	var s := run.state
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		run.command(&"pause" if s.phase == RunState.Phase.PLAY else &"resume")
	elif s.phase == RunState.Phase.LEVELUP:
		for i in 3:
			if event.is_action_pressed(StringName("card_%d" % (i + 1))):
				get_viewport().set_input_as_handled()
				run.command(&"choose_card", {"index": i})
		if event.is_action_pressed(&"reroll"):
			get_viewport().set_input_as_handled()
			run.command(&"reroll")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and run != null and run.state != null:
		run.command(&"pause")

func _process(delta: float) -> void:
	_warning_t = maxf(0.0, _warning_t - delta)
	queue_redraw()

# ── 3択 ──────────────────────────────────────────────────────────

func _build_cards() -> void:
	_cards_box = VBoxContainer.new()
	_cards_box.set_anchors_preset(Control.PRESET_CENTER)
	_cards_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cards_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cards_box.visible = false
	var title := Label.new()
	title.text = "レベルアップ　1枚選ぶ（クリック／1〜3）"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cards_box.add_child(title)
	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 16)
	_cards_box.add_child(_cards_row)
	_reroll_button = Button.new()
	_reroll_button.custom_minimum_size = Vector2(320, 52)
	_reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_button.pressed.connect(func(): run.command(&"reroll"))
	_cards_box.add_child(_reroll_button)
	add_child(_cards_box)

func _show_cards() -> void:
	# 古いカードはすぐ外す（消える前の札が並びの幅に残らないように）
	for c in _cards_row.get_children():
		_cards_row.remove_child(c)
		c.queue_free()
	var cards := run.state.cards
	for i in cards.size():
		var info := card_info(cards[i])
		var b := Button.new()
		b.custom_minimum_size = Vector2(280, 220)
		b.text = "%d. %s\n%s\n\n%s" % [i + 1, info.tag, info.name, info.desc]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.08, 0.14, 0.95)
		style.border_color = info.color
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.12, 0.15, 0.24, 0.95)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("focus", hover)
		b.pressed.connect(func(): run.command(&"choose_card", {"index": i}))
		_cards_row.add_child(b)
	var left := run.state.rerolls_left
	_reroll_button.text = "リロール（残り %d 回）　%s" % [left, OS.get_keycode_string(InputActions.key_of(&"reroll"))]
	_reroll_button.disabled = left <= 0
	_cards_box.reset_size()
	_cards_box.position = (size - _cards_box.size) / 2.0
	if _cards_row.get_child_count() > 0:
		_cards_row.get_child(0).grab_focus.call_deferred()

## カードの表示内容（仕様書 9.2）。色は取得後の段階（仕様書 8）。
static func card_info(c: Dictionary) -> Dictionary:
	if c.kind == &"heal":
		return {"tag": "回復", "name": "緊急修理", "desc": "HP を 30% 回復", "color": Color("#6dffb0")}
	var weapon: bool = c.kind == &"weapon"
	var def = (ConfigManager.weapons if weapon else ConfigManager.traits).get(c.id)
	var lv: int = c.level
	var tag := ("新しい武器" if weapon else "新しい特性") if lv == 1 else ("武器強化" if weapon else "特性強化")
	var suffix := "Lv%d" % lv if weapon else "%d/5" % lv
	return {"tag": tag, "name": "%s %s" % [def.display_name, suffix], "desc": def.description,
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
	title.text = "ポーズ"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_box.add_child(title)
	var resume := Button.new()
	resume.text = "続ける"
	resume.custom_minimum_size = Vector2(320, 52)
	resume.pressed.connect(func(): run.command(&"resume"))
	_pause_box.add_child(resume)
	var quit := Button.new()
	quit.text = "メインメニューに戻る（このランは残らない）"
	quit.custom_minimum_size = Vector2(320, 52)
	quit.pressed.connect(func(): run.command(&"abort"))
	_pause_box.add_child(quit)
	add_child(_pause_box)

# ── 描画（HUD） ─────────────────────────────────────────────────

func _draw() -> void:
	var s := run.state
	if s == null:
		return
	var cfg := run.cfg
	var W := size.x
	var H := size.y
	_pause_box.position = (size - _pause_box.size) / 2.0
	if s.phase == RunState.Phase.DYING or s.phase == RunState.Phase.FINISHING:
		_draw_banner()
		return
	# 経験値バー（画面の上端）
	draw_rect(Rect2(0, 0, W, 5), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(0, 0, W * clampf(s.xp / run.build.xp_needed(), 0.0, 1.0), 5), Color("#b8a0ff"))
	# 残り時間（上部中央。残り60秒を切ると橙）
	var left := maxf(0.0, cfg.run_time - s.time)
	var tcol := Color("#ff8a6b") if left < 60.0 else Color("#e8f0ff")
	draw_string(_font, Vector2(W / 2.0 - 40, 44), "%d:%02d" % [int(left) / 60, int(left) % 60], HORIZONTAL_ALIGNMENT_CENTER, 80, 30, tcol)
	# 状態の文字（左上）
	var atk := run.combat.attack_power()
	var x := 16.0
	draw_string(_font, Vector2(x, 32), "HP %d / %d" % [ceili(maxf(0.0, s.ship_hp)), roundi(s.stats.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e8f0ff"))
	if W < 600.0:
		draw_string(_font, Vector2(x, 52), "ATK %.1f  Lv %d" % [atk, s.level], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e8f0ff"))
		draw_string(_font, Vector2(x, 72), "撃破 %d" % s.kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e8f0ff"))
		draw_string(_font, Vector2(x, 92), "部品 %d" % s.coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffd24a"))
	else:
		draw_string(_font, Vector2(x, 52), "ATK %.1f   撃破 %d   Lv %d" % [atk, s.kills, s.level], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e8f0ff"))
		draw_string(_font, Vector2(x, 72), "部品 %d" % s.coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffd24a"))
	_draw_speed(W, H)
	_draw_loadout(H)
	_draw_boss(W)
	_draw_gauge_ring()

func _draw_speed(W: float, H: float) -> void:
	var s := run.state
	var k := run.cfg.speed_to_kms
	var sp := s.ship_vel.length()
	var bw := minf(420.0, W * 0.5)
	var bx := W / 2.0 - bw / 2.0
	var by := H - 34.0
	var cap := maxf(s.stats.max_speed * 1.6, s.peak_speed)
	draw_rect(Rect2(bx, by, bw, 10), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(bx, by, bw * clampf(sp / cap, 0.0, 1.0), 10), Color("#5fd8ff"))
	var mx := bx + bw * clampf(s.stats.max_speed / cap, 0.0, 1.0)
	draw_line(Vector2(mx, by - 4), Vector2(mx, by + 14), Color("#ffd24a"), 2.0)
	draw_string(_font, Vector2(bx, by - 8), "%.2f km/s　上限 %.2f　最高 %.2f" % [sp * k, s.stats.max_speed * k, s.peak_speed * k], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#e8f0ff"))

## 装備一覧（左下）。文字の色は強化の段階（仕様書 8）。
func _draw_loadout(H: float) -> void:
	var s := run.state
	var lines: Array = []
	for id in s.weapons:
		lines.append([ConfigManager.weapons[id].display_name + " Lv%d" % s.weapons[id], s.weapons[id]])
	for id in s.traits:
		lines.append([ConfigManager.traits[id].display_name + " %d/5" % s.traits[id], s.traits[id]])
	var y := H - 60.0 - lines.size() * 18.0
	for l in lines:
		draw_string(_font, Vector2(16, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, RANK_COLORS[clampi(l[1] - 1, 0, 4)])
		y += 18.0

func _draw_boss(W: float) -> void:
	var b := run.bosses.boss
	if _warning_t > 0.0 and fmod(_warning_t, 0.5) < 0.3:
		draw_string(_font, Vector2(W / 2.0 - 160, 120), "WARNING!!", HORIZONTAL_ALIGNMENT_CENTER, 320, 48, Color("#ff526e"))
	if b == null or b.dead:
		return
	var bw := minf(520.0, W * 0.6)
	var bx := W / 2.0 - bw / 2.0
	draw_rect(Rect2(bx, 60, bw, 10), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bx, 60, bw * clampf(b.hp / b.max_hp, 0.0, 1.0), 10), Color("#ff526e"))
	# 画面外にいるときの方向の矢印
	var s := run.state
	var rel := b.pos - s.view_center
	if absf(rel.x) > s.view_half.x or absf(rel.y) > s.view_half.y:
		var center := size / 2.0
		var dir := rel.normalized()
		var edge := minf((size.x / 2.0 - 40.0) / maxf(absf(dir.x), 0.001), (size.y / 2.0 - 40.0) / maxf(absf(dir.y), 0.001))
		var tip := center + dir * edge
		var side := Vector2(-dir.y, dir.x) * 12.0
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 24.0 + side, tip - dir * 24.0 - side]), Color("#ff526e"))

## カーソル付近のリング：描画前は充填率、描画中は残りの長さ（仕様書 6.2）。
func _draw_gauge_ring() -> void:
	var s := run.state
	var p := get_viewport().get_mouse_position()
	var frac := s.gauge
	if s.drawing:
		frac = 1.0 - s.draw_length / maxf(1.0, s.draw_limit)
	var col := Color("#ffd24a") if s.gauge >= 1.0 - 1e-6 else (Color("#5dffa0") if s.gauge >= run.cfg.draw_min_charge else Color("#6b7690"))
	if s.drawing:
		col = Color("#c8f7ff")
	draw_arc(p + Vector2(26, 26), 14.0, 0, TAU, 32, Color(1, 1, 1, 0.15), 4.0)
	draw_arc(p + Vector2(26, 26), 14.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(frac, 0.0, 1.0), 32, col, 4.0)

func _draw_banner() -> void:
	if _banner == "":
		return
	var col := Color("#ffe46b") if _banner == "CLEAR!" else Color("#ff6b5a")
	draw_string(_font, Vector2(0, size.y / 2.0), _banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 72, col)
