## 調整パネル（仕様書 20）。開発版だけで P キーで開く。
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

var run: RunManager
var _module: OptionButton
var _levels: SpinBox
var _enemy_count: SpinBox
var _sliders: Dictionary = {}
## 機体の強化の ID → 段の入力欄
var _meta_boxes: Dictionary = {}
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
			["被弾を確認", &"debug_hurt", {}], ["致命傷を確認", &"debug_die", {}],
			["彗星を出す", &"debug_comet", {"rare": false}], ["レアな彗星を出す", &"debug_comet", {"rare": true}],
			["重力を出す", &"debug_gravity", {}], ["ワープホールを出す", &"debug_warp", {}], ["攻撃の形を試す", &"debug_hazards", {}]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(run.command.bind(b[1], b[2]))
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
	for table in [ConfigManager.weapons, ConfigManager.traits]:
		for def in ConfigManager.sorted(table):
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
	_add_meta_levels(box)
	_refresh_sliders()

## 機体の強化の段を項目ごとに決める（セーブは変えない。次のランから反映）。
func _add_meta_levels(box: VBoxContainer) -> void:
	box.add_child(_heading("機体の強化の段（セーブは変えない。次のランから反映）"))
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for def: MetaUpgradeDef in ConfigManager.sorted(ConfigManager.meta_upgrades):
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
	var row := HBoxContainer.new()
	var preset := Button.new()
	preset.text = "全部を7割にする"
	preset.pressed.connect(_set_meta_cost_ratio.bind(0.7))
	row.add_child(preset)
	var back := Button.new()
	back.text = "セーブの段に戻す"
	back.pressed.connect(func():
		SaveManager.dev_meta_override.clear()
		_refresh_meta_levels())
	row.add_child(back)
	box.add_child(row)
	_refresh_meta_levels()

## 各項目を、そこまでに使う部品の合計が全段の合計の ratio 倍にいちばん近い段にする（同じ近さなら低い段）。
func _set_meta_cost_ratio(ratio: float) -> void:
	for def: MetaUpgradeDef in ConfigManager.meta_upgrades.values():
		var total := 0
		for c in def.costs:
			total += c
		var target := total * ratio
		var best := 0
		var spent := 0
		for k in def.costs.size():
			spent += def.costs[k]
			var best_spent := 0
			for c in def.costs.slice(0, best):
				best_spent += c
			if absf(spent - target) < absf(best_spent - target):
				best = k + 1
		SaveManager.dev_meta_override[String(def.id)] = best
	_refresh_meta_levels()

func _refresh_meta_levels() -> void:
	for id in _meta_boxes:
		_meta_boxes[id].set_value_no_signal(SaveManager.run_meta_level(id))

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
			_refresh_meta_levels()

func _process(_delta: float) -> void:
	if visible and run.state != null:
		_status.text = "無敵 %s　敵 %d 体　経過 %.0f 秒" % ["ON" if run.ship.invincible else "OFF", run.enemies.count(), run.state.time]

func _grant() -> void:
	var id: StringName = _module.get_item_metadata(_module.selected)
	var kind := &"weapon" if String(id).begins_with("W") else &"trait"
	run.command(&"debug_grant", {"kind": kind, "id": id, "levels": int(_levels.value)})

func _spawn_enemies() -> void:
	_enemy_count.apply()
	run.command(&"debug_spawn_enemies", {"count": int(_enemy_count.value)})

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
