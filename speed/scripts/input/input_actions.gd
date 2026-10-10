## 入力のアクションの一覧と既定のキー（仕様書 19、設計書 9）。
##
## アクションは起動時にここから InputMap に登録する。キー設定で変えた割り当ては
## SaveManager の設定ファイルに保存し、apply_bindings() で上書きする。
class_name InputActions
extends RefCounted

## キー設定の画面で変えられるアクション（表示順）と表示名。
const REBINDABLE := {
	&"draw_alt": "描画の補助",
	&"pause": "ポーズ",
	&"mute": "消音の切り替え",
	&"card_1": "3択の1枚目",
	&"card_2": "3択の2枚目",
	&"card_3": "3択の3枚目",
	&"reroll": "3択の引き直し",
	&"debug_panel": "調整パネル（開発版）",
	&"debug_perf": "性能の表示（開発版）",
}

## アクション → 既定のキー（物理キー）。
const DEFAULT_KEYS := {
	&"draw_alt": KEY_SPACE,
	&"pause": KEY_ESCAPE,
	&"mute": KEY_M,
	&"card_1": KEY_1,
	&"card_2": KEY_2,
	&"card_3": KEY_3,
	&"reroll": KEY_R,
	&"debug_panel": KEY_P,
	&"debug_perf": KEY_F3,
}

## 既定の割り当てを InputMap に登録する。何度呼んでもよい。
static func register_defaults() -> void:
	for action in DEFAULT_KEYS:
		_set_key(action, DEFAULT_KEYS[action])
	if not InputMap.has_action(&"draw"):
		InputMap.add_action(&"draw")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"draw", mb)

## 保存された割り当て（アクション名 → 物理キーのコード）を反映する。
static func apply_bindings(bindings: Dictionary) -> void:
	for action in bindings:
		var name := StringName(action)
		if DEFAULT_KEYS.has(name):
			_set_key(name, int(bindings[action]))

## アクションに今割り当てられている物理キーのコード。
static func key_of(action: StringName) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.physical_keycode
	return 0

static func _set_key(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var key := InputEventKey.new()
	key.physical_keycode = keycode as Key
	InputMap.action_add_event(action, key)
