## 敵調整画面の分類と表示。数値の規則はStageEnemyTuningを使う。
@tool
extends RefCounted

const GROUPS := {
	"耐久・弱点": ["耐久・装甲", "弱点"],
	"命中演出": ["ヒットストップ"],
	"移動": ["速度・旋回", "距離・隊列"],
	"攻撃": ["威力・効果", "予告・頻度", "照準・追尾", "範囲・形状", "弾速・軌道"],
	"固有行動": ["分裂・召喚", "捕捉・投擲", "その他の行動"],
}
const BASICS := {
	"hitstop_multiplier": ["ヒットストップ時間倍率", "一撃撃破・体当たりクリティカルの停止実時間に掛ける。1で共通時間、0で停止なし。共通の累積上限内で停止。", "倍"],
	"hp": ["標準HP", "星から計算したHPを上書き。サイズ・エリート補正の前の値。", "HP"],
	"armor": ["装甲", "これより低い攻撃力の体当たりを弾く。", "攻撃力"],
	"speed": ["移動速度", "追跡するときの標準の速さ。", "距離/秒"],
	"accel": ["加速", "狙った速さへ近づく強さ。", "毎秒の割合"],
	"turn": ["旋回速度", "機体の方へ向き直る速さ。", "ラジアン/秒"],
	"weak_arc": ["背面の弱点角度", "背面からクリティカルになる範囲の半角。0で弱点なし。", "ラジアン"],
}

static func docs(key: String) -> Array:
	if BASICS.has(key): return BASICS[key]
	var name := key.trim_prefix("params.")
	return EnemyDef.PARAMS_DOCS.get(name, [name, "敵固有の行動が参照する値。", "—"])

static func category(key: String) -> String:
	if key == "hitstop_multiplier": return "ヒットストップ"
	if key in ["hp", "armor"]: return "耐久・装甲"
	if key == "weak_arc" or key == "params.front_arc": return "弱点"
	if key in ["speed", "accel", "turn"]: return "速度・旋回"
	var name := key.trim_prefix("params.")
	if name in ["dash_speed", "rush", "deploy_speed", "retreat_speed"]: return "速度・旋回"
	if name.begins_with("throw_") or name.begins_with("capture_") or name in ["pull", "pull_spin", "pull_radius", "swallow_reach", "swallow_interval", "store_max", "grow", "align_angle", "ring"]: return "捕捉・投擲"
	if name.begins_with("bud_") or name.begins_with("split_") or name.begins_with("release_") or name in ["death_split", "max_buds", "reinforce_interval", "summon_time", "mutiny_time", "mutiny_shot"]: return "分裂・召喚"
	if name in ["keep", "approach", "stand_off", "align_tol", "orbit", "flock", "flock_gap", "spacing", "row_near", "row_far", "fan_radius", "fan_step", "follow_gap", "follow_reach", "exit_margin"] or name.begins_with("gather_"): return "距離・隊列"
	if "dmg" in name or "damage" in name or name in ["slow", "chain_power"]: return "威力・効果"
	if name.begins_with("search_") or name in ["aim_turn", "track_turn", "lock_fill", "lock_decay", "lock_time", "aim_time"]: return "照準・追尾"
	if name in ["telegraph", "windup", "recover", "rest", "cooldown", "laser_charge", "trail_step", "spray_step", "drop_step", "life"] or name.ends_with("_interval") or name.ends_with("_time") or name.ends_with("_delay") or name.ends_with("_rest") or name.ends_with("_telegraph"): return "予告・頻度"
	if "speed" in name or "turn" in name or name in ["spin", "search_sway", "aim_spread"]: return "弾速・軌道"
	if "radius" in name or "width" in name or "range" in name or "reach" in name or name.ends_with("_r") or name in ["volley", "spread", "beams", "layers", "spray", "span", "band_len", "band_narrow", "beam_len", "beam_spread", "wave_arc", "hand_long", "hand_short", "wheel_gap", "half_gap", "emit_back", "trigger", "fuse", "slash_size"]: return "範囲・形状"
	return "その他の行動"

static func belongs(key: String, selected: String) -> bool:
	var group := category(key)
	return selected == "すべて" or selected == "変更した項目" or group == selected or group in GROUPS.get(selected, [])

static func focus_control(control: Control) -> void:
	control.add_to_group("stage_enemy_tuning_input")
	control.accessibility_name = control.tooltip_text

static func text(parent: Node, value: String, stretch := false) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stretch:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

static func row(parent: Node, key: String, base: float, value: float, integer: bool, wide: bool, changed: Callable, reset: Callable, override: Callable, hint: Callable) -> Array:
	var info := docs(key)
	var name: Label
	var cells: Node = parent
	if not wide:
		cells = VBoxContainer.new()
		parent.add_child(cells)
	name = text(cells, info[0], true)
	name.mouse_filter = Control.MOUSE_FILTER_PASS
	name.tooltip_text = "%s\n%s\n単位: %s" % [key, info[1], info[2]]
	name.mouse_entered.connect(hint.bind("%s · %s\n%s" % [info[0], info[2], info[1]]))
	var common := text(cells, ("" if wide else "共通値（参照） ") + String.num(base, 3))
	common.tooltip_text = "全ステージの基準値。参照のみ。"
	common.modulate = Color("#b9c5d4")
	common.custom_minimum_size.x = 64 if wide else 0
	var settings := VBoxContainer.new()
	cells.add_child(settings)
	var enabled := CheckBox.new()
	enabled.text = "このステージで上書き"
	enabled.tooltip_text = "ONでこのステージだけの値を編集。OFFで共通値へ戻す。"
	focus_control(enabled)
	settings.add_child(enabled)
	enabled.toggled.connect(override)
	var tail: Node = cells
	if not wide:
		tail = HBoxContainer.new()
		cells.add_child(tail)
	var state := text(tail, "", not wide)
	state.custom_minimum_size.x = 108 if wide else 0
	state.add_theme_font_size_override("font_size", 13)
	var revert := Button.new()
	revert.text = "↶"
	revert.tooltip_text = "上書きを解除して共通値を使用（チェックOFFと同じ）"
	focus_control(revert)
	tail.add_child(revert)
	revert.pressed.connect(func(): reset.call(key, settings.get_node_or_null("Value"), base))
	# 編集欄は上書きONのときだけ作る。非表示のSpinBoxも先に生成しない。
	return [state, revert, null, enabled, settings, {"key": key, "base": base, "value": value, "integer": integer, "changed": changed}]

static func editor(controls: Array) -> SpinBox:
	if controls[2] != null: return controls[2]
	var data: Dictionary = controls[5]
	var spin := SpinBox.new()
	spin.name = "Value"
	spin.min_value = minf(data.base, StageEnemyTuning.minimum(data.key))
	spin.max_value = maxf(data.base, 100000.0)
	spin.step = 1.0 if data.integer else 0.01
	spin.value = data.value
	spin.custom_minimum_size.x = 100
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.tooltip_text = "このステージの上書き値 / %s" % docs(data.key)[2]
	focus_control(spin.get_line_edit())
	controls[4].add_child(spin)
	spin.value_changed.connect(data.changed)
	controls[2] = spin
	return spin
