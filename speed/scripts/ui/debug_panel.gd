## 調整パネル（仕様書 18）。開発版だけで P キーで開く。
##
## ランの状態は RunManager への命令で変え、調整値は ConfigManager の実行時の複製（cfg）だけを書き換える。
## 「既定値に戻す」で .tres の値に戻る。.tres そのものは書き換えない（設計書 8.3）。
extends PanelContainer

@export var run_path: NodePath

## 調整できる値：項目名、表示名、最小、最大、刻み
const SLIDERS := [
	["draw_time_scale", "描画中の世界の速さ", 0.0, 1.0, 0.05],
	["dash_charge_time", "ゲージ1単位の充填（秒）", 1.0, 20.0, 0.5],
	["draw_min_charge", "使える最低の充填率", 0.05, 1.0, 0.05],
	["density_mult", "敵の密度の倍率", 0.0, 10.0, 0.5],
	["enemy_pursuit_spread", "敵の広域移動の強さ", 0.0, 960.0, 40.0],
	["boss_time", "ボスの出現時刻（秒）", 0.0, 600.0, 10.0],
	["boss_hp", "ボスの HP", 100.0, 10000.0, 100.0],
	["boss_armor", "ボスの装甲", 0.0, 60.0, 1.0],
	["meteor_count", "隕石の密度（次のランから）", 0.0, 60.0, 1.0],
	["meteor_heal_chance", "修理キットの確率", 0.0, 1.0, 0.01],
	["meteor_heal_frac", "修理キットの回復量", 0.0, 1.0, 0.05],
	["meteor_magnet_chance", "回収ビーコンの確率", 0.0, 1.0, 0.01],
	["xp_base", "必要経験値（基礎）", 10.0, 300.0, 5.0],
	["weapon_slots", "武器の枠", 1.0, 8.0, 1.0],
	["trait_slots", "特性の枠", 1.0, 12.0, 1.0],
]

var run: RunManager
var _module: OptionButton
var _levels: SpinBox
var _sliders: Dictionary = {}
var _status: Label

func _ready() -> void:
	run = get_node(run_path) as RunManager
	visible = false
	if not OS.is_debug_build():
		queue_free()
		return
	custom_minimum_size = Vector2(420, 0)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
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
			["被弾を確認", &"debug_hurt", {}], ["致命傷を確認", &"debug_die", {}]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(run.command.bind(b[1], b[2]))
		grid.add_child(btn)
	box.add_child(_heading("入手するモジュール"))
	var row := HBoxContainer.new()
	_module = OptionButton.new()
	_module.add_theme_font_size_override("font_size", 15)
	for table in [ConfigManager.weapons, ConfigManager.traits]:
		for def in ConfigManager.sorted(table):
			_module.add_item("%s %s" % [def.id, def.display_name])
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
	reset_loadout.pressed.connect(run.command.bind(&"debug_reset_loadout", {}))
	box.add_child(reset_loadout)
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
	_refresh_sliders()

func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	return l

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_panel"):
		get_viewport().set_input_as_handled()
		visible = not visible
		if visible:
			_refresh_sliders()

func _process(_delta: float) -> void:
	if visible and run.state != null:
		_status.text = "無敵 %s　敵 %d 体　経過 %.0f 秒" % ["ON" if run.ship.invincible else "OFF", run.enemies.list.size(), run.state.time]

func _grant() -> void:
	var id: StringName = _module.get_item_metadata(_module.selected)
	var kind := &"weapon" if String(id).begins_with("W") else &"trait"
	run.command(&"debug_grant", {"kind": kind, "id": id, "levels": int(_levels.value)})

func _on_slider(value: float, key: String) -> void:
	var cfg := ConfigManager.cfg
	if typeof(cfg.get(key)) == TYPE_INT:
		cfg.set(key, int(value))
	else:
		cfg.set(key, value)
	_sliders[key][1].text = "%s %s" % [_sliders[key][2], str(snappedf(value, 0.01))]

func _refresh_sliders() -> void:
	for key in _sliders:
		var v = ConfigManager.cfg.get(key)
		_sliders[key][0].set_value_no_signal(float(v))
		_sliders[key][1].text = "%s %s" % [_sliders[key][2], str(snappedf(float(v), 0.01))]

func _reset_defaults() -> void:
	# 実行時の複製の中身を .tres の値に戻す（RunManager などが同じ複製を持っているため、中身を書き戻す）
	var base := ConfigManager.base
	for prop in base.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			ConfigManager.cfg.set(prop.name, base.get(prop.name))
	_refresh_sliders()
