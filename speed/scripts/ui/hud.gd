## ラン中の HUD（仕様書 17）。状態を読んで表示するだけで、選んだ結果は RunManager に命令として渡す。
##
## 時間・経験値バー・状態の文字・装備一覧・ゲージのリング・3択・ボスの表示・ポーズ・
## 「描く」ボタン（タッチ）・CLEAR! と GAME OVER。
extends Control

## 描けるようになったときに広がる輪の時間（実秒）
const RING_PULSE_TIME := 0.35
const SETTINGS_SCENE := preload("res://scenes/app/settings.tscn")
## 装備一覧の枠の大きさ（画面px）
const LOADOUT_WEAPON := 50.0
const LOADOUT_TRAIT := 40.0
## 彗星限定の武器の枠の色（段階の色と重ならない赤）
const COMET_ONLY_COLOR := Color("#ff3b4e")
const RANK_COLORS := [Color("#d5dbea"), Color("#8ed7a3"), Color("#3989ff"), Color("#bf91ef"), Color("#efcb70")]

@export var run_path: NodePath

var run: RunManager
var _font: Font
var _cards_box: VBoxContainer
var _reroll_button: Button
var _cards_title: Label
var _cards_row: HBoxContainer
var _pause_box: VBoxContainer
var _draw_button: Button
var _banner := ""
var _banner_color := Color.WHITE
var _banner_t := 0.0
var _warning_t := 0.0
var _ring_usable := true
## ポーズ中に開いている設定（なければ null）
var _settings: UiScreen
var _ring_pulse_t := 0.0

func _ready() -> void:
	run = get_node(run_path) as RunManager
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_cards()
	_build_pause()
	_draw_button = Button.new()
	_draw_button.text = "hud.draw"
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
				_banner = tr("hud.clear")
				_banner_color = Color("#ffe46b")
				_banner_t = 99.0
			&"game_over":
				_banner = tr("hud.game_over")
				_banner_color = Color("#ff6b5a")
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
	if _settings != null:
		return
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
	_ring_pulse_t = maxf(0.0, _ring_pulse_t - delta)
	queue_redraw()

# ── 3択 ──────────────────────────────────────────────────────────

func _build_cards() -> void:
	_cards_box = VBoxContainer.new()
	_cards_box.set_anchors_preset(Control.PRESET_CENTER)
	_cards_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cards_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cards_box.visible = false
	var title := Label.new()
	_cards_title = title
	title.text = tr("hud.levelup_title")
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
		b.custom_minimum_size = Vector2(280 if cards.size() <= 3 else 210, 220)
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
	var start: bool = run.state.start_pick
	var swap: StringName = run.state.swap_pick
	if swap != &"":
		var got: WeaponDef = ConfigManager.weapons[swap]
		_cards_title.text = tr("hud.swap_title").format({name = got.get_display_name()}) + "\n" + got.get_description()
	else:
		_cards_title.text = tr("hud.start_title") if start else tr("hud.levelup_title")
	var left := run.state.rerolls_left
	_reroll_button.text = tr("hud.reroll").format({n = left, key = OS.get_keycode_string(InputActions.key_of(&"reroll"))})
	_reroll_button.disabled = left <= 0
	_reroll_button.visible = swap == &""
	_cards_box.reset_size()
	_cards_box.position = (size - _cards_box.size) / 2.0
	if _cards_row.get_child_count() > 0:
		_cards_row.get_child(0).grab_focus.call_deferred()

## カードの表示内容（仕様書 9.2）。色は取得後の段階（仕様書 8）。
static func card_info(c: Dictionary) -> Dictionary:
	if c.kind == &"swap" or c.kind == &"keep":
		var new_def: WeaponDef = ConfigManager.weapons[c.new]
		if c.kind == &"keep":
			return {"tag": TranslationServer.translate("card.keep_tag"), "name": TranslationServer.translate("card.keep_name"),
				"desc": TranslationServer.translate("card.keep_desc").format({name = new_def.get_display_name()}), "color": Color("#6b7690")}
		var old_def: WeaponDef = ConfigManager.weapons[c.id]
		var old_name := old_def.get_display_name() if old_def.comet_only else "%s Lv%d" % [old_def.get_display_name(), c.level]
		return {"tag": TranslationServer.translate("card.swap_tag"), "name": old_name,
			"desc": TranslationServer.translate("card.swap_desc").format({name = new_def.get_display_name()}),
			"color": Color("#efcb70")}
	if c.kind == &"heal":
		return {"tag": TranslationServer.translate("card.heal_tag"), "name": TranslationServer.translate("card.heal_name"),
			"desc": TranslationServer.translate("card.heal_desc"), "color": Color("#6dffb0")}
	var weapon: bool = c.kind == &"weapon"
	var def = (ConfigManager.weapons if weapon else ConfigManager.traits).get(c.id)
	var lv: int = c.level
	var tag := ("card.new_weapon" if weapon else "card.new_trait") if lv == 1 else ("card.weapon_up" if weapon else "card.trait_up")
	if c.get("start", false):
		tag = "card.first_weapon"
	var suffix := "Lv%d" % lv if weapon else "%d/5" % lv
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
	quit.pressed.connect(func(): run.command(&"abort"))
	_pause_box.add_child(quit)
	add_child(_pause_box)

## ポーズ中に設定を重ねて開く。戻ると閉じてポーズに戻る。
func _open_settings(from: Button) -> void:
	AudioManager.play(&"ui")
	_settings = SETTINGS_SCENE.instantiate() as UiScreen
	_settings.close_fn = func():
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
	# 経過時間（上部中央）
	draw_string(_font, Vector2(W / 2.0 - 40, 44), "%d:%02d" % [int(s.time) / 60, int(s.time) % 60], HORIZONTAL_ALIGNMENT_CENTER, 80, 30, Color("#e8f0ff"))
	if s.bonus_t > 0.0:
		draw_string(_font, Vector2(W / 2.0 - 120, 76), tr("hud.bonus").format({n = ceili(s.bonus_t)}), HORIZONTAL_ALIGNMENT_CENTER, 240, 22, Color("#d9a8ff"))
	# 状態の文字（左上）
	var atk := run.combat.attack_power()
	var x := 16.0
	draw_string(_font, Vector2(x, 32), "HP %d / %d" % [ceili(maxf(0.0, s.ship_hp)), roundi(s.stats.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e8f0ff"))
	if W < 600.0:
		draw_string(_font, Vector2(x, 52), "ATK %.1f  Lv %d" % [atk, s.level], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e8f0ff"))
		draw_string(_font, Vector2(x, 72), tr("hud.kills").format({n = s.kills}), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e8f0ff"))
		draw_string(_font, Vector2(x, 92), tr("common.parts").format({n = s.coins}), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffd24a"))
	else:
		draw_string(_font, Vector2(x, 52), "ATK %.1f   %s   Lv %d" % [atk, tr("hud.kills").format({n = s.kills}), s.level], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e8f0ff"))
		draw_string(_font, Vector2(x, 72), tr("common.parts").format({n = s.coins}), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffd24a"))
	_draw_loadout(H)
	_draw_boss(W)
	_draw_gauge_ring()

## 装備一覧（左下）。武器と特性を別の段の枠に並べ、空き枠も薄く描いて持てる数を見せる（仕様書 17）。
## 武器は角の四角、特性は丸い四角。枠の色と下の目盛りは強化の段階（仕様書 8）。
## 枠の中は名前（アイコンができたら差し替える）。
func _draw_loadout(H: float) -> void:
	var s := run.state
	var cfg := run.cfg
	var trait_y := H - 8.0 - LOADOUT_TRAIT
	var weapon_y := trait_y - 5.0 - LOADOUT_WEAPON
	_draw_slot_row(weapon_y, LOADOUT_WEAPON, 2, cfg.weapon_slots, cfg.weapon_max_level, s.weapons, ConfigManager.weapons)
	_draw_slot_row(trait_y, LOADOUT_TRAIT, 12, cfg.trait_slots, cfg.trait_max_stacks, s.traits, ConfigManager.traits)

func _draw_slot_row(y: float, size_px: float, corner: int, slots: int, max_level: int, owned: Dictionary, defs: Dictionary) -> void:
	var ids := owned.keys()
	for k in slots:
		var rect := Rect2(8.0 + k * (size_px + 4.0), y, size_px, size_px)
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(corner)
		box.set_border_width_all(2)
		if k >= ids.size():
			box.bg_color = Color(1, 1, 1, 0.03)
			box.border_color = Color(1, 1, 1, 0.18)
			draw_style_box(box, rect)
			continue
		var lv: int = owned[ids[k]]
		var col: Color = RANK_COLORS[clampi(lv - 1, 0, 4)]
		var def = defs[ids[k]]
		box.bg_color = Color(0.04, 0.06, 0.11, 0.8)
		box.border_color = col
		var text_col := col
		# 彗星限定の武器は赤い枠で、ほかの武器と見分ける
		if def is WeaponDef and def.comet_only:
			var glow := box.duplicate() as StyleBoxFlat
			glow.bg_color = Color.TRANSPARENT
			glow.border_color = Color(COMET_ONLY_COLOR, 0.35 + 0.25 * sin(Time.get_ticks_msec() / 250.0))
			glow.set_border_width_all(3)
			glow.set_expand_margin_all(3)
			draw_style_box(glow, rect)
			box.bg_color = Color(0.25, 0.03, 0.06, 0.88)
			box.border_color = COMET_ONLY_COLOR
			text_col = Color("#ffd9d9")
		draw_style_box(box, rect)
		_draw_fit_text(def.get_display_name(), Rect2(rect.position + Vector2(3, 3), Vector2(size_px - 6.0, size_px - 12.0)), text_col)
		# 段階の目盛り（強化のない彗星限定の武器には出さない）
		if def is WeaponDef and def.comet_only:
			continue
		var pip_w := (size_px - 10.0 - (max_level - 1) * 2.0) / max_level
		for j in max_level:
			var pip := Rect2(rect.position.x + 5.0 + j * (pip_w + 2.0), rect.end.y - 7.0, pip_w, 3.0)
			draw_rect(pip, col if j < lv else Color(1, 1, 1, 0.15))

## 枠に収まる大きさまで文字を小さくして、上寄せ・中央揃えで描く。
func _draw_fit_text(text: String, area: Rect2, col: Color) -> void:
	# 単語の途中では折らない。どの大きさでも収まらなければ、いちばん小さい大きさで途中でも折る
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	var font_size := 12
	while true:
		var sz := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, area.size.x, font_size, -1, flags)
		if sz.x <= area.size.x + 0.5 and sz.y <= area.size.y:
			break
		if font_size <= 8:
			flags |= TextServer.BREAK_ADAPTIVE
			break
		font_size -= 1
	draw_multiline_string(_font, area.position + Vector2(0, _font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_CENTER,
		area.size.x, font_size, -1, col, flags)

func _draw_boss(W: float) -> void:
	var bosses := run.bosses
	if _warning_t > 0.0 and fmod(_warning_t, 0.5) < 0.3:
		draw_string(_font, Vector2(W / 2.0 - 160, 120), tr("hud.warning"), HORIZONTAL_ALIGNMENT_CENTER, 320, 48, Color("#ff526e"))
	if not bosses.boss_alive():
		return
	var t := run.enemies.table
	var b := bosses.boss_row
	var bw := minf(520.0, W * 0.6)
	var bx := W / 2.0 - bw / 2.0
	draw_rect(Rect2(bx, 60, bw, 10), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bx, 60, bw * clampf(t.hp[b] / t.max_hp[b], 0.0, 1.0), 10), Color("#ff526e"))
	# 画面外にいるときの方向の矢印
	var s := run.state
	var rel := t.pos[b] - s.view_center
	if absf(rel.x) > s.view_half.x or absf(rel.y) > s.view_half.y:
		var center := size / 2.0
		var dir := rel.normalized()
		var edge := minf((size.x / 2.0 - 40.0) / maxf(absf(dir.x), 0.001), (size.y / 2.0 - 40.0) / maxf(absf(dir.y), 0.001))
		var tip := center + dir * edge
		var side := Vector2(-dir.y, dir.x) * 12.0
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 24.0 + side, tip - dir * 24.0 - side]), Color("#ff526e"))

## カーソル付近のリング：描画前は充填率、描画中は残りの長さ（仕様書 6.2）。
## 描けるまでは同じ色を暗くして溜まり具合を見せ、描ける割合に目盛りを置く。描けるようになった瞬間に広がる輪を出す。
func _draw_gauge_ring() -> void:
	var s := run.state
	var c := get_viewport().get_mouse_position() + Vector2(26, 26)
	var min_charge := run.cfg.draw_min_charge
	var usable := s.gauge >= min_charge
	if usable and not _ring_usable and not s.drawing and not s.tracing:
		_ring_pulse_t = RING_PULSE_TIME
	_ring_usable = usable
	var frac := s.gauge
	var col := Color("#ffd24a") if s.gauge >= 1.0 - 1e-6 else Color("#5dffa0")
	if not usable:
		col.a = 0.4
	if s.drawing:
		frac = 1.0 - s.draw_length / maxf(1.0, s.draw_limit)
		col = Color("#c8f7ff")
	draw_arc(c, 14.0, 0, TAU, 32, Color(1, 1, 1, 0.15), 4.0)
	draw_arc(c, 14.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(frac, 0.0, 1.0), 32, col, 4.0)
	if not s.drawing:
		var tick := Vector2.from_angle(-PI / 2.0 + TAU * min_charge)
		draw_line(c + tick * 10.0, c + tick * 19.0, Color(1, 1, 1, 0.9 if usable else 0.5), 2.0)
	if _ring_pulse_t > 0.0:
		var k := 1.0 - _ring_pulse_t / RING_PULSE_TIME
		draw_arc(c, 14.0 + 12.0 * k, 0, TAU, 32, Color(0.36, 1.0, 0.63, 1.0 - k), 3.0)

func _draw_banner() -> void:
	if _banner == "":
		return
	draw_string(_font, Vector2(0, size.y / 2.0), _banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 72, _banner_color)
