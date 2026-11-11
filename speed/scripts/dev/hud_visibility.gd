## 開発ラン専用。描画だけを抑え、報酬の選択・獲得とメニューの入力を維持する。
## scripts/dev は通常版・審査版とも export 対象外。
extends Node
const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase
const COMBAT_ITEMS := ["_loadout_icons", "_stage_progress", "_speed_indicator", "_draw_button", "_entrance_skip"]
var hud: Control
var hidden := false
var _suppressed := false
var _colors: Dictionary = {}
var _hud_color := Color.WHITE
var _control_input: Dictionary = {}

func _ready() -> void:
	# HUD側が各フレームの表示状態を更新した後に適用する。
	process_priority = hud.process_priority + 1
	_hud_color = hud.self_modulate
	for field: String in COMBAT_ITEMS:
		var item: CanvasItem = hud.get(field)
		if item != null: _colors[field] = item.modulate
		if item is Control: _control_input[field] = [item.mouse_filter, item.focus_mode]

func set_hidden(value: bool) -> void:
	hidden = value and OS.is_debug_build() and not SaveManager.is_review_build()
	_apply()

func _process(_delta: float) -> void:
	_apply()

func _apply() -> void:
	if not is_instance_valid(hud): return
	var phase := int(hud._cpp_ui.get("phase", -1))
	# 終了表示と、伝説の武器を獲得するフィナーレは通常どおり表示する。
	var acquisition: bool = bool(hud._cpp_ui.get("boss_finish", {}).get("active", false)) \
		or (float(hud._cpp_ui.get("cinematic_bars", 0.0)) > 0.0 and not hud._cpp_ui.get("final_modules", []).is_empty())
	var suppress: bool = hidden and phase not in [Phase.Finishing, Phase.Ended] and not acquisition
	if suppress == _suppressed: return
	_suppressed = suppress
	hud.self_modulate = Color(_hud_color, 0.0) if suppress else _hud_color
	for field: String in _colors:
		var item: CanvasItem = hud.get(field)
		if is_instance_valid(item):
			item.modulate = Color(_colors[field], 0.0) if suppress else _colors[field]
	# 透明な操作ボタンがポインターやTabの入力を奪わない。
	for field: String in _control_input:
		var control: Control = hud.get(field)
		if not is_instance_valid(control): continue
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE if suppress else _control_input[field][0]
		control.focus_mode = Control.FOCUS_NONE if suppress else _control_input[field][1]
		if suppress and control.has_focus(): control.release_focus()

func _exit_tree() -> void:
	hidden = false
	_apply()
