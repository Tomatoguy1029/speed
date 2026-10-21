## ラン中の HUD（仕様書 17）。状態を読んで表示するだけで、選んだ結果は RunManager に命令として渡す。
##
## 時間・経験値バー・状態の文字・装備一覧・ゲージのリング・3択・ボスの表示・ポーズ・
## 「描く」ボタン（タッチ）・CLEAR! と GAME OVER。
extends Control

## 描けるようになったときに広がる輪の時間（実秒）
const RING_PULSE_TIME := 0.35
const SETTINGS_SCENE := preload("res://scenes/app/settings.tscn")
## 装備一覧の枠の大きさ（素材のpx）
const LOADOUT_WEAPON := 21.0
const LOADOUT_TRAIT := 13.0
## ミニマップの半径（素材のpx）
const MINIMAP_R := 43.0
const ART_SIZE := Vector2(640, 360)
const CYAN := Color("#5bc8db")
const ART := "res://assets/ui/combat/"
const FRAME := preload(ART + "combat_ui_main.png")
const RADAR := preload(ART + "combat_ui_radar.png")
const HEALTH := preload(ART + "combat_ui_health_bar.png")
const EXPERIENCE := preload(ART + "combat_ui_exp_bar.png")
const SLOTS := preload(ART + "combat_ui_upgrades_boxes.png")
const CARDS := preload(ART + "combat_ui_boxes.png")
const ICONS := preload(ART + "icons.png")
const ICON_IDS := [
	"W01", "W02", "W03", "W04", "W05", "W06", "W07", "W08", "W17", "W21", "W22", "W23",
	"T01", "T03", "T04", "T05", "T06", "T07", "T08", "T09", "T10", "T11", "T12", "T13", "T14",
]

## ミニマップと、ミニマップ以外の表示（経験値バー・時間・状態の文字・装備一覧・ボス・ゲージのリング）を描くか
## （実験場では初めは消す）
var show_minimap := true
var show_status := true
## 彗星限定の武器の枠の色（段階の色と重ならない赤）
const COMET_ONLY_COLOR := Color("#ff3b4e")
const RANK_COLORS := [Color("#d5dbea"), Color("#8ed7a3"), Color("#3989ff"), Color("#bf91ef"), Color("#efcb70")]

@export var run_path: NodePath
## カードを表示してから選択を受け付けるまでの実秒。
@export_range(0.0, 1.0, 0.05) var card_input_delay := 0.3

var _cards_accept_at := 0
var _card_blocked_pointer_frame := -1
var _card_blocked_pointer_pos := Vector2.ZERO
## 表示切替前からの押下と、離すまで破棄する押下（マウス・タッチ・選択キー）。
var _card_held: Dictionary = {}
var _card_discard: Dictionary = {}

var run: RunManager
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
var _frame: TextureRect
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

func _ready() -> void:
	run = get_node(run_path) as RunManager
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_health_fill = _make_bar_fill(HEALTH)
	_experience_fill = _make_bar_fill(EXPERIENCE)
	_frame = TextureRect.new()
	_frame.texture = FRAME
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_material := ShaderMaterial.new()
	frame_material.shader = preload(ART + "main_frame.gdshader")
	_frame.material = frame_material
	add_child(_frame)
	_loadout_icons = Control.new()
	_loadout_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loadout_icons)
	_build_cards()
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
			&"hero_discovered":
				_hero_notice_t = 1.8
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
			&"shield_reflect":
				AudioManager.play(&"block", -10.0, 1.8)
			&"shield_stolen":
				AudioManager.play(&"pickup", -5.0, 0.7)
			&"shield_block":
				AudioManager.play(&"block", -10.0, 1.3)
			&"boss_explode":
				AudioManager.play(&"boom")

## GUI が押下を記憶する前に止める。期限後の release やキーリピートにも持ち越さない。
func _input(event: InputEvent) -> void:
	if run == null or run.state == null or run.state.lab_mode:
		return
	var id := _card_input_id(event)
	if id == "":
		return
	var choosing := run.state.phase == RunState.Phase.LEVELUP
	var blocked := _card_discard.has(id) or (choosing and Time.get_ticks_usec() < _cards_accept_at)
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

func _card_input_id(event: InputEvent) -> String:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return "mouse:%d" % event.device
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
		if _card_held.has(id) or _card_discard.has(id):
			return id
		for action in [&"card_1", &"card_2", &"card_3", &"reroll", &"ui_accept"]:
			if event.is_action(action):
				return id
	return ""

func _card_command(command: StringName, args := {}) -> void:
	if run.state.phase != RunState.Phase.LEVELUP or Time.get_ticks_usec() < _cards_accept_at:
		return
	_card_discard.merge(_card_held)
	run.command(command, args)

func _unhandled_input(event: InputEvent) -> void:
	# 実験場では HUD は表示だけ（ポーズ・3択は実験場が扱い、操作の記録に入らない入力を受けない）
	if _settings != null or run.state.lab_mode:
		return
	var s := run.state
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		run.command(&"pause" if s.phase == RunState.Phase.PLAY else &"resume")
	elif s.phase == RunState.Phase.LEVELUP:
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
		run.command(&"pause")

func _process(delta: float) -> void:
	_hero_notice_t = maxf(0.0, _hero_notice_t - delta)
	_warning_t = maxf(0.0, _warning_t - delta)
	_ring_pulse_t = maxf(0.0, _ring_pulse_t - delta)
	_layout_art()
	_refresh_loadout_icons()
	queue_redraw()

func _layout_art() -> void:
	var factor := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	var origin := (size - ART_SIZE * factor) * 0.5
	for item in [_frame, _loadout_icons]:
		item.position = origin
		item.scale = Vector2.ONE * factor
	if _swap_box.visible:
		_layout_cards()
	else:
		_cards_box.position = origin
		_cards_box.scale = Vector2.ONE * factor
		_cards_box.size = ART_SIZE
	_frame.size = ART_SIZE
	_frame.visible = show_status and run.state != null and run.state.phase not in [RunState.Phase.DYING, RunState.Phase.FINISHING]
	_loadout_icons.visible = _frame.visible

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
	var index := ICON_IDS.find(String(definition.id))
	if index < 0:
		return
	var texture := AtlasTexture.new()
	texture.atlas = ICONS
	texture.region = Rect2(index * 47, 0, 47, 47)
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
	var key := str(run.state.weapons) + str(run.state.traits)
	if key == _loadout_key:
		return
	_loadout_key = key
	for child in _loadout_icons.get_children():
		child.queue_free()
	var row := 0
	for owned in [run.state.weapons, run.state.traits]:
		var index := 0
		for id in owned:
			var area := Rect2(9 + index * 23, 317, 17, 17) if row == 0 else Rect2(10 + index * 15, 340, 11, 9)
			_add_icon(_loadout_icons, (ConfigManager.weapons if row == 0 else ConfigManager.traits).get(id), area)
			index += 1
		row += 1

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
		var got: WeaponDef = ConfigManager.weapons[swap]
		_swap_new_name.text = got.get_display_name()
		_swap_new_desc.text = got.get_description()
		for i in cards.size():
			if cards[i].kind == &"keep":
				_swap_keep_index = i
				var info := card_info(cards[i])
				_swap_keep.text = "%s\n%s" % [info.tag, info.desc]
			else:
				var b := _card_button(cards[i], i, Vector2(0, 220))
				b.mouse_filter = Control.MOUSE_FILTER_PASS
				_swap_grid.add_child(b)
	else:
		_cards_title.text = tr("hud.start_title") if start else tr("hud.levelup_title")
		var width := (464.0 - 16.0 * (cards.size() - 1)) / maxi(1, cards.size())
		for i in cards.size():
			var info := card_info(cards[i])
			var b := Button.new()
			b.position = Vector2(89 + i * (width + 16), 83)
			b.size = Vector2(width, 193)
			b.tooltip_text = "%s: %s" % [info.name, info.desc]
			_card_art(b, Rect2(89, 83, 145, 193))
			b.pressed.connect(func(): _card_command(&"choose_card", {"index": i}))
			_cards_row.add_child(b)
			var font_size := 10 if cards.size() <= 3 else 8
			for entry in [[Vector2(7, 5), Vector2(width - 14, 23), "%d. %s" % [i + 1, info.tag]],
				[Vector2(7, 34), Vector2(width - 14, 28), info.name],
				[Vector2(7, 65), Vector2(width - 14, 57), info.desc]]:
				var label := Label.new()
				label.position = entry[0]
				label.size = entry[1]
				label.text = entry[2]
				label.add_theme_font_size_override("font_size", font_size)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.clip_text = true
				label.max_lines_visible = 4 if entry[0].y == 65 else 2
				label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(label)
			var card: Dictionary = cards[i]
			var definition: Resource = (ConfigManager.traits if card.kind == &"trait" else ConfigManager.weapons).get(card.id)
			_add_icon(b, definition, Rect2(48 * width / 145.0, 129, 48 * width / 145.0, 48))
	var left := run.state.rerolls_left
	_reroll_button.text = tr("hud.reroll").format({n = left, key = OS.get_keycode_string(InputActions.key_of(&"reroll"))})
	_reroll_button.disabled = left <= 0
	_reroll_button.visible = swap == &""
	_layout_art()
	_layout_cards()
	var row: Control = _swap_grid if swap != &"" else _cards_row
	if row.get_child_count() > 0:
		row.get_child(0).grab_focus.call_deferred()
	_swap_scroll.set_deferred("scroll_vertical", 0)

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
	var info := card_info(card)
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
static func card_info(c: Dictionary) -> Dictionary:
	if c.kind == &"swap" or c.kind == &"keep":
		if c.kind == &"keep":
			var new_def: WeaponDef = ConfigManager.weapons[c.new]
			return {"tag": TranslationServer.translate("card.keep_tag"), "name": TranslationServer.translate("card.keep_name"),
				"desc": TranslationServer.translate("card.keep_desc").format({name = new_def.get_display_name()}), "color": Color("#6b7690")}
		var old_def: WeaponDef = ConfigManager.weapons[c.id]
		var old_name := old_def.get_display_name() if old_def.comet_only else "%s Lv%d" % [old_def.get_display_name(), c.level]
		return {"tag": TranslationServer.translate("card.swap_tag"), "name": old_name,
			"desc": old_def.get_description(),
			"color": COMET_ONLY_COLOR if old_def.comet_only else RANK_COLORS[clampi(c.level - 1, 0, 4)]}
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
	var W := size.x
	_pause_box.position = (size - _pause_box.size) / 2.0
	if s.phase == RunState.Phase.DYING or s.phase == RunState.Phase.FINISHING:
		_draw_banner()
		return
	var factor := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	draw_set_transform((size - ART_SIZE * factor) * 0.5, 0.0, Vector2.ONE * factor)
	if show_minimap:
		_draw_minimap()
	if show_status:
		# 素材の体力枠の内側に、現在のHPの割合を描く。
		var hp := clampf(s.ship_hp / maxf(1.0, s.stats.max_hp), 0.0, 1.0)
		var health_color := Color("#ff526e") if hp < 0.3 else CYAN
		_draw_bar(HEALTH, _health_fill, hp, health_color)
		draw_string(_font, Vector2(7, 40), "%d/%d" % [ceili(maxf(0.0, s.ship_hp)), roundi(s.stats.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CYAN)
		draw_string(_font, Vector2(7, 52), "ATK %.1f  %s  Lv %d  %s" % [run.combat.attack_power(), tr("hud.kills").format({n = s.kills}), s.level, tr("common.parts").format({n = s.coins})], HORIZONTAL_ALIGNMENT_LEFT, 260, 8, CYAN)
		_draw_bar(EXPERIENCE, _experience_fill, s.xp / run.build.xp_needed(), Color("#b8a0ff"))
		draw_string(_font, Vector2(280, 23), "%d:%02d" % [int(s.time) / 60, int(s.time) % 60], HORIZONTAL_ALIGNMENT_CENTER, 80, 15, CYAN)
		if s.bonus_t > 0.0:
			draw_string(_font, Vector2(240, 37), tr("hud.bonus").format({n = ceili(s.bonus_t)}), HORIZONTAL_ALIGNMENT_CENTER, 160, 10, CYAN)
		_draw_loadout()
	draw_set_transform(Vector2.ZERO)
	if show_status:
		_draw_boss(W)
		if _hero_notice_t > 0.0:
			var text := tr("hud.hero_discovered")
			var font_size := mini(24, int((W - 24.0) / maxf(1.0, _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x) * 24.0))
			draw_string(_font, Vector2(12.0, MINIMAP_R * 2.0 + 42.0 if W < 600.0 else 110.0), text, HORIZONTAL_ALIGNMENT_CENTER, W - 24.0,
				font_size, Color(1.0, 0.91, 0.63, minf(1.0, _hero_notice_t / 0.4)))
		if run.heroes.revealed() and run.heroes.is_captive():
			_draw_edge_arrow(run.heroes.center, Color("#ffd24a"))
		for p in run.field.rare_comet_positions():
			_draw_edge_arrow(p, Color("#ffd24a"))
		_draw_gauge_ring()
	if _cards_box.visible and _swap_box.visible:
		draw_rect(_cards_box.get_rect(), Color(0.06, 0.08, 0.14, 0.95))

var _dense := PackedVector2Array()

## ミニマップ（右上）。自機を中心に、世界の方角と縮尺を保って出す（仕様書 17）。
## 自機・ボス・カプセル・敵の多い所・目印の星の線・英雄の星座。
func _draw_minimap() -> void:
	var s := run.state
	var cfg := run.cfg
	var R := MINIMAP_R
	var c := Vector2(584, 55)
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
	var planet_shape := _minimap_disk(_minimap_offset(run.field.planet.pos), cfg.planet_radius * k)
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
		draw_circle(c + _minimap_marker(cap.pos, 2.0), 2.0, Color("#ffd24a"))
	# 目印の星の線：取り戻した位置から英雄の星座を通る直線。2体そろうと線を消す。
	var h := run.heroes
	var gold := Color("#ffe8a0")
	if h.hero != null and h.is_captive():
		for q in s.landmarks:
			var a := _minimap_offset(q)
			var u := (h.center - q).normalized()
			var b := a.dot(u)
			var disc := b * b - a.length_squared() + R * R
			if disc > 0.0 and s.landmarks.size() < 2:
				var r0 := sqrt(disc)
				draw_line(c + a + u * (-b - r0), c + a + u * (-b + r0), Color(gold, 0.7), 1.5)
			draw_circle(c + _minimap_marker(q, 3.0), 3.0, gold)
	if h.revealed():
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
	draw_texture(SLOTS, Vector2.ZERO)
	_draw_slot_row(315, LOADOUT_WEAPON, run.cfg.weapon_slots, run.cfg.weapon_max_level, run.state.weapons, ConfigManager.weapons)
	_draw_slot_row(338, LOADOUT_TRAIT, run.cfg.trait_slots, run.cfg.trait_max_stacks, run.state.traits, ConfigManager.traits)
	_draw_hero_slot(Vector2(99, 315))

func _draw_hero_slot(at: Vector2) -> void:
	var s := run.state
	if s.hero_power == &"":
		return
	var rect := Rect2(at + Vector2(3, 3), Vector2(32, 31))
	var definition: HeroDef = ConfigManager.heroes.get(s.hero_power)
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
	draw_string(_font, at + Vector2(26, 32), OS.get_keycode_string(InputActions.key_of(&"hero")), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, gold)

func _draw_slot_row(y: float, size_px: float, slots: int, max_level: int, owned: Dictionary, defs: Dictionary) -> void:
	var ids := owned.keys()
	for k in mini(slots, ids.size()):
		var weapon := size_px == LOADOUT_WEAPON
		var step := 23.0 if weapon else 15.0
		var rect := Rect2((7.0 if weapon else 9.0) + k * step, y, size_px, size_px)
		var lv: int = owned[ids[k]]
		var col: Color = RANK_COLORS[clampi(lv - 1, 0, 4)]
		var definition = defs[ids[k]]
		if definition is WeaponDef and definition.comet_only:
			draw_rect(rect.grow(1), COMET_ONLY_COLOR, false, 1)
			continue
		var pip_w := (size_px - 4.0) / max_level
		for j in max_level:
			draw_rect(Rect2(rect.position.x + 2 + j * pip_w, rect.end.y - 3, maxf(1, pip_w - 1), 1), col if j < lv else Color(1, 1, 1, 0.15))

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
	_draw_edge_arrow(t.pos[b], Color("#ff526e"))

## 世界の位置 p が画面の外なら、画面の端にその向きの矢印を描く（ボス・英雄・レアな彗星）。
func _draw_edge_arrow(p: Vector2, col: Color) -> void:
	var s := run.state
	var rel := p - s.view_center
	if absf(rel.x) <= s.view_half.x and absf(rel.y) <= s.view_half.y:
		return
	var center := size / 2.0
	var dir := rel.normalized()
	var edge := minf((size.x / 2.0 - 40.0) / maxf(absf(dir.x), 0.001), (size.y / 2.0 - 40.0) / maxf(absf(dir.y), 0.001))
	var tip := center + dir * edge
	var side := Vector2(-dir.y, dir.x) * 12.0
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 24.0 + side, tip - dir * 24.0 - side]), col)

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
