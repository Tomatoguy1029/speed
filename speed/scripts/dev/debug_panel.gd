## 調整パネル（仕様書 20）。開発版だけで P キーで開く。
##
## ランの状態は明示命令で変える。C++ではSession専用の調整値を正規生成して適用する。
## 「既定値に戻す」で .tres の値に戻る。.tres そのものは書き換えない（設計書 8.3）。
extends PanelContainer
const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase


## 調整できる値：項目名、表示名、最小、最大、刻み
const SLIDERS := [
	["draw_time_scale", "描画中の世界の速さ", 0.0, 1.0, 0.05],
	["dash_charge_time", "ゲージ1単位の充填（秒）", 1.0, 20.0, 0.5],
	["draw_min_charge", "描き始められる量", 0.05, 1.0, 0.05],
	["density_mult", "敵の密度の倍率", 0.0, 10.0, 0.5],
	["boss_time", "ボスの出現時刻（秒）", 0.0, 900.0, 10.0],
	["boss_hp", "ボスの HP", 100.0, 10000.0, 100.0],
	["boss_armor", "ボスの装甲", 0.0, 60.0, 1.0],
	["meteor_count", "隕石の密度（次のランから）", 0.0, 60.0, 1.0],
	["meteor_heal_chance", "修理キットの確率", 0.0, 1.0, 0.01],
	["meteor_heal_frac", "修理キットの回復量", 0.0, 1.0, 0.05],
	["meteor_magnet_chance", "回収ビーコンの確率", 0.0, 1.0, 0.01],
	["steer_cruise", "巡航の速さ（最高速度に対する割合）", 0.1, 1.0, 0.01],
	["glide_speed_ratio", "勢いの速さ（突進に対する割合）", 0.2, 1.5, 0.05],
	["glide_hold", "勢いが続く秒数", 0.0, 15.0, 0.5],
	["glide_fade", "勢いを落とす秒数", 0.0, 10.0, 0.5],
	["xp_base", "必要経験値（基礎）", 10.0, 300.0, 5.0],
	["weapon_slots", "武器の枠", 1.0, 8.0, 1.0],
	["trait_slots", "特性の枠", 1.0, 12.0, 1.0],
]

## RunSession が木に入れる前に入れる
var cpp_session: RunSession
var _commands: RefCounted
var _content_edit: RefCounted
var _hud: Control
var _module: OptionButton
var _ult: OptionButton
var _levels: SpinBox
var _enemy_count: SpinBox
var _sliders: Dictionary = {}
## 機体の強化の ID → 段の入力欄
var _meta_boxes: Dictionary = {}
var _status: Label
var _hitstop_tab: VBoxContainer
var _hud_visibility: Node

func _ready() -> void:
	visible = false
	if not OS.is_debug_build() or SaveManager.is_review_build():
		queue_free()
		return
	_hud = get_parent().get_node("HudRoot")
	_hud_visibility = preload("res://scripts/dev/hud_visibility.gd").new()
	_hud_visibility.hud = _hud
	add_child(_hud_visibility)
	if cpp_session!=null:
		_commands = preload("res://scripts/dev/run_commands.gd").new()
		_commands.setup_cpp(cpp_session)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.05, 0.08, 0.97)
	background.content_margin_left = 6
	background.content_margin_right = 6
	add_theme_stylebox_override("panel", background)
	var tabs := TabContainer.new()
	tabs.name = "DebugTabs"
	tabs.get_tab_bar().add_theme_font_size_override("font_size", 16)
	add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.name = "通常"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var hitstop_scroll := ScrollContainer.new()
	hitstop_scroll.name = "ヒットストップ"
	hitstop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(hitstop_scroll)
	_hitstop_tab = preload("res://scripts/dev/debug_hitstop_tab.gd").new()
	_hitstop_tab.cpp_session = cpp_session
	_hitstop_tab.resume_requested.connect(_close)
	hitstop_scroll.add_child(_hitstop_tab)
	tabs.tab_changed.connect(func(index: int):
		if index == 1: _hitstop_tab.refresh())
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var hide_ui := CheckButton.new()
	hide_ui.name = "HidePlayUi"
	hide_ui.text = "プレイ中のUIを非表示（武器獲得は表示）"
	hide_ui.tooltip_text = "このランだけ。Pで開き直して解除できます。ポーズ・獲得操作は残します。"
	hide_ui.toggled.connect(_hud_visibility.set_hidden)
	box.add_child(hide_ui)
	_status = Label.new()
	box.add_child(_status)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for b in [["+30秒", &"debug_time", {"seconds": 30.0}], ["+60秒", &"debug_time", {"seconds": 60.0}],
			["ボス出現へ", &"debug_boss_time", {}], ["ボスを倒す", &"debug_kill_boss", {}],
			["無敵の切り替え", &"debug_invincible", {}], ["HP 全快", &"debug_heal", {}],
			["レベルアップ", &"debug_level_up", {}], ["ゲージ満タン", &"debug_gauge_full", {}],
			["敵を消す", &"debug_clear_enemies", {}], ["部品 +100", &"debug_coins", {"amount": 100}],
			["被弾を確認", &"debug_hurt", {}], ["致命傷を確認", &"debug_die", {}],
			["彗星を出す", &"debug_comet", {"rare": false}], ["レアな彗星を出す", &"debug_comet", {"rare": true}],
			["重力を出す", &"debug_gravity", {}], ["ワープホールを出す", &"debug_warp", {}], ["攻撃の形を試す", &"debug_hazards", {}]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_command.bind(b[1], b[2]))
		grid.add_child(btn)
	box.add_child(_heading("負荷計測用の敵生成（種類ランダム）"))
	var spawn_row := HBoxContainer.new()
	var count_label := Label.new()
	count_label.text = "追加数"
	spawn_row.add_child(count_label)
	_enemy_count = SpinBox.new()
	_enemy_count.min_value = 1
	_enemy_count.max_value = 10000
	_enemy_count.step = 1
	_enemy_count.value = 100
	spawn_row.add_child(_enemy_count)
	var spawn_button := Button.new()
	spawn_button.text = "敵を生成"
	spawn_button.tooltip_text = "画面内にランダムな通常敵を追加。通常の出現上限を超えて生成できます。"
	spawn_button.pressed.connect(_spawn_enemies)
	spawn_row.add_child(spawn_button)
	box.add_child(spawn_row)
	box.add_child(_heading("入手するモジュール"))
	var row := HBoxContainer.new()
	_module = OptionButton.new()
	_module.add_theme_font_size_override("font_size", 15)
	for table in [ContentManager.catalog.table(&"weapons"), ContentManager.catalog.table(&"traits")]:
		for def in ContentManager.sorted(table):
			_module.add_item("%s %s" % [def.id, def.get_display_name()])
			_module.set_item_metadata(_module.item_count - 1, def.id)
	row.add_child(_module)
	_levels = SpinBox.new()
	_levels.min_value = 1
	_levels.max_value = 5
	_levels.value = 1
	row.add_child(_levels)
	var grant := Button.new()
	grant.text = "入手"
	grant.pressed.connect(_grant)
	row.add_child(grant)
	box.add_child(row)
	var reset_loadout := Button.new()
	reset_loadout.text = "装備をリセット"
	reset_loadout.pressed.connect(_command.bind(&"debug_reset_loadout", {}))
	box.add_child(reset_loadout)
	box.add_child(_heading("獲得するULT（英雄の力）"))
	var ult_row := HBoxContainer.new()
	_ult = OptionButton.new()
	_ult.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: ContentEntry in ContentManager.sorted(ContentManager.catalog.table(&"heroes")):
		_ult.add_item(entry.get_display_name())
		_ult.set_item_metadata(_ult.item_count - 1, String(entry.id))
	ult_row.add_child(_ult)
	var grant_ult := Button.new()
	grant_ult.text = "ULTを獲得"
	grant_ult.disabled = _ult.item_count == 0
	grant_ult.tooltip_text = "このランの英雄の力を選んだULTに切り替えます。クールダウンは引き継ぎます。"
	grant_ult.pressed.connect(_grant_ult)
	ult_row.add_child(grant_ult)
	box.add_child(ult_row)
	box.add_child(_heading("調整値（このランの間だけ。.tres は変えない）"))
	for sdef in SLIDERS:
		var r := HBoxContainer.new()
		var l := Label.new()
		l.custom_minimum_size = Vector2(210, 0)
		l.add_theme_font_size_override("font_size", 14)
		r.add_child(l)
		var sl := HSlider.new()
		sl.custom_minimum_size = Vector2(180, 24)
		sl.min_value = sdef[2]
		sl.max_value = sdef[3]
		sl.step = sdef[4]
		sl.value_changed.connect(_on_slider.bind(sdef[0]))
		r.add_child(sl)
		box.add_child(r)
		_sliders[sdef[0]] = [sl, l, sdef[1]]
	var defaults := Button.new()
	defaults.text = "既定値に戻す"
	defaults.pressed.connect(_reset_defaults)
	box.add_child(defaults)
	var meta_reset := Button.new()
	meta_reset.text = "機体の強化をリセット（部品を返す。次のランから反映）"
	meta_reset.pressed.connect(func(): SaveManager.reset_upgrades())
	box.add_child(meta_reset)
	_add_meta_levels(box)
	_refresh_sliders()

## 機体の強化の段を項目ごとに決める（セーブは変えない。次のランから反映）。
func _add_meta_levels(box: VBoxContainer) -> void:
	box.add_child(_heading("機体の強化の段（セーブは変えない。次のランから反映）"))
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for def: ContentEntry in ContentManager.sorted(ContentManager.catalog.table(&"meta_upgrades")):
		var l := Label.new()
		l.text = "%s（最大 %d）" % [def.get_display_name(), def.costs.size()]
		l.add_theme_font_size_override("font_size", 14)
		grid.add_child(l)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = def.costs.size()
		spin.step = 1
		spin.value_changed.connect(func(v: float): SaveManager.dev_meta_override[String(def.id)] = int(v))
		grid.add_child(spin)
		_meta_boxes[def.id] = spin
	# ステージ1〜5で想定する育ち具合（仕様書 14.1）
	var presets := HBoxContainer.new()
	for tenths in [0, 2, 5, 7, 9]:
		var preset := Button.new()
		preset.text = "%d割" % tenths
		preset.tooltip_text = "段の合計を、最大の段の合計の%d割にする" % tenths
		preset.pressed.connect(_set_meta_ratio.bind(tenths / 10.0))
		presets.add_child(preset)
	box.add_child(presets)
	var row := HBoxContainer.new()
	var back := Button.new()
	back.text = "セーブの段に戻す"
	back.pressed.connect(func():
		SaveManager.dev_meta_override.clear()
		_refresh_meta_levels())
	row.add_child(back)
	box.add_child(row)
	_refresh_meta_levels()

## 全項目の段の合計を、最大の段の合計の ratio 倍（四捨五入）にする。各項目へ最大の段に比べて均等に振り分け、
## 端数の段は小数部の大きい項目から、同じなら強化画面の並び順で前の項目から1段ずつ足す。
func _set_meta_ratio(ratio: float) -> void:
	var defs: Array = ContentManager.sorted(ContentManager.catalog.table(&"meta_upgrades"))
	var total := 0
	for def: ContentEntry in defs:
		total += def.costs.size()
	var left := roundi(total * ratio)
	var levels := {}
	var order := []
	for k in defs.size():
		var share: float = defs[k].costs.size() * ratio
		levels[defs[k].id] = floori(share)
		left -= floori(share)
		order.append([share - floori(share), k])
	order.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	for o in order:
		if left <= 0:
			break
		var def: ContentEntry = defs[o[1]]
		if levels[def.id] < def.costs.size():
			levels[def.id] += 1
			left -= 1
	for id in levels:
		SaveManager.dev_meta_override[String(id)] = levels[id]
	_refresh_meta_levels()

func _refresh_meta_levels() -> void:
	for id in _meta_boxes:
		_meta_boxes[id].set_value_no_signal(SaveManager.run_meta_level(id))

func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	return l

func _input(event: InputEvent) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and focus.is_in_group("stage_enemy_tuning_input"): return
	if _phase() in [Phase.Finishing, Phase.Ended]:
		if visible: _close()
		return
	if not visible and not _hud.can_show_menu_overlay(): return
	if event.is_action(&"debug_panel") or (visible and (event.is_action(&"pause") or event.is_action(&"ui_cancel"))):
		get_viewport().set_input_as_handled()
		if not event.is_pressed() or event.is_echo(): return
		if visible:
			_close()
		elif _hud.show_menu_overlay(self):
			show()
			# 編集用の写しは全ファイルの署名とステージの再変換を伴うので、スライダーを動かしたときに作る。
			_refresh_sliders()
			_refresh_meta_levels()
			_hitstop_tab.refresh()
			for button in find_children("*", "Button", true, false):
				if button.is_visible_in_tree():
					button.grab_focus()
					break

func _fit_viewport() -> void:
	var available := get_viewport_rect().size - position - Vector2(16, 16)
	size = Vector2(minf(460, available.x), minf(580, available.y))

func _close() -> void:
	hide()
	_hud.close_menu_overlay(self)

func _phase() -> int:
	if cpp_session!=null:
		var frame: Dictionary = cpp_session.bridge.read_frame() if cpp_session.bridge!=null else {"ok":false}
		return int(frame.value.ui.phase) if frame.ok else Phase.Ended
	return Phase.Ended

func _command(name: StringName, args: Dictionary) -> void:
	var result: Dictionary = await _commands.handle_cpp(name,args)
	if not result.ok: _status.text = result.message

func _process(_delta: float) -> void:
	if cpp_session!=null:
		if not visible or cpp_session.bridge==null: return
		var frame: Dictionary = cpp_session.bridge.read_frame()
		var metrics: Dictionary = cpp_session.bridge.read_metrics()
		if frame.ok and metrics.ok:
			_status.text = "無敵 %s　敵 %d 体　経過 %.0f 秒" % ["ON" if frame.value.ui.invincible else "OFF",metrics.value.get("enemies",0),frame.value.ui.run_time]
		return
func _grant() -> void:
	var id: StringName = _module.get_item_metadata(_module.selected)
	var kind := &"weapon" if String(id).begins_with("W") else &"trait"
	_command(&"debug_grant", {"kind": kind, "id": id, "levels": int(_levels.value)})

func _grant_ult() -> void:
	if _ult.selected < 0: return
	await _command(&"debug_ult", {"id": String(_ult.get_selected_metadata())})

func _spawn_enemies() -> void:
	_enemy_count.apply()
	_command(&"debug_spawn_enemies", {"count": int(_enemy_count.value)})

func _editor() -> RefCounted:
	if _content_edit==null: _content_edit = load("res://scripts/dev/run_content_edit.gd").for_session(cpp_session)
	return _content_edit

func _on_slider(value: float, key: String) -> void:
	if cpp_session!=null:
		var edit := _editor()
		if not edit.error.is_empty():
			_status.text = edit.error
			return
		var next: GameConfig = edit.config.duplicate(true)
		next.set(key,int(value) if typeof(next.get(key))==TYPE_INT else value)
		var applied: Dictionary = edit.apply_config(next)
		if not applied.ok: _status.text = applied.message
		_refresh_sliders()
		return
func _refresh_sliders() -> void:
	var config: GameConfig = ContentManager.base
	if _content_edit!=null and _content_edit.config!=null: config = _content_edit.config
	elif cpp_session!=null and cpp_session.cpp_edit_source.get("config") is GameConfig: config = cpp_session.cpp_edit_source.config
	for key in _sliders:
		var v = config.get(key)
		_sliders[key][0].set_value_no_signal(float(v))
		_sliders[key][1].text = "%s %s" % [_sliders[key][2], str(snappedf(float(v), 0.01))]

func _reset_defaults() -> void:
	if cpp_session!=null:
		var edit := _editor()
		if not edit.error.is_empty():
			_status.text = edit.error
			return
		var applied: Dictionary = edit.apply_config(ContentManager.base.duplicate(true))
		if not applied.ok: _status.text = applied.message
		_refresh_sliders()
		return
