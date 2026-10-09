## セーブと設定の読み書き。Autoload（設計書 4.3・11）。
##
## セーブ（user://save.json）には、部品・強化の段階・ステージの解放・伝説のモジュール・
## 図鑑・記録・エンドレスのハイスコアを持つ。版番号を持たせ、版が変わったら変換する。
## 設定（user://settings.cfg）には、音量・画面モード・キー設定を持つ。
extends Node

signal save_changed
signal settings_changed

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_VERSION := 1

var data: Dictionary = {}
var settings: Dictionary = {}
## 起動してからウィンドウの大きさを画面に合わせたか
var _window_sized := false

func _ready() -> void:
	InputActions.register_defaults()
	data = _load_save()
	settings = _load_settings()
	apply_settings()

# ── セーブ ──────────────────────────────────────────────────────────────

func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": 0,
		"meta": {},
		"cleared_stage": 0,
		"legendary": [],
		"encyclopedia": [],
		"best": {"runs": 0, "clears": 0, "fastest_clear": -1.0, "top_speed": 0.0},
		"endless_high_score": 0,
	}

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: セーブを書けない")
		return
	f.store_string(JSON.stringify(data, "\t"))
	save_changed.emit()

func coins() -> int:
	return int(data.coins)

func meta_level(id: StringName) -> int:
	return int(data.meta.get(String(id), 0))

## 強化を1段階買う。部品が足りないか最大なら false。
func buy_upgrade(def: MetaUpgradeDef) -> bool:
	var lv := meta_level(def.id)
	if lv >= def.costs.size():
		return false
	var cost := def.costs[lv]
	if coins() < cost:
		return false
	data.coins = coins() - cost
	data.meta[String(def.id)] = lv + 1
	save()
	return true

## 強化をすべて 0 に戻し、使った部品を返す（調整パネル用）。
func reset_upgrades() -> int:
	var refund := 0
	for def in ConfigManager.meta_upgrades.values():
		var lv := meta_level(def.id)
		for i in lv:
			refund += def.costs[i]
	data.meta = {}
	data.coins = coins() + refund
	save()
	return refund

func add_coins(amount: int) -> void:
	data.coins = coins() + amount
	save()

## ステージが選べるか。前のステージをクリアしていれば選べる。
func is_stage_unlocked(index: int) -> bool:
	return index <= int(data.cleared_stage) + 1

func mark_stage_cleared(index: int) -> void:
	data.cleared_stage = maxi(int(data.cleared_stage), index)

func has_legendary(id: StringName) -> bool:
	return data.legendary.has(String(id))

func add_legendary(id: StringName) -> void:
	if id != &"" and not has_legendary(id):
		data.legendary.append(String(id))
	if id != &"":
		unlock_module(id)

## 図鑑：獲得済みにする（武器・特性・伝説のモジュール）。
func unlock_module(id: StringName) -> void:
	if not data.encyclopedia.has(String(id)):
		data.encyclopedia.append(String(id))

func is_module_known(id: StringName) -> bool:
	return data.encyclopedia.has(String(id))

## ランの結果を記録する。途中でやめたランは呼ばない（仕様書 3）。
func record_run(result: Dictionary) -> void:
	var best: Dictionary = data.best
	best.runs = int(best.runs) + 1
	best.top_speed = maxf(float(best.top_speed), float(result.get("peak_speed", 0.0)))
	if result.get("cleared", false):
		best.clears = int(best.clears) + 1
		var t := float(result.get("time", 0.0))
		if float(best.fastest_clear) < 0.0 or t < float(best.fastest_clear):
			best.fastest_clear = t
		mark_stage_cleared(int(result.get("stage", 0)))
		add_legendary(StringName(result.get("legendary", "")))
	if result.get("endless", false):
		data.endless_high_score = maxi(int(data.endless_high_score), int(result.get("score", 0)))
	for id in result.get("modules", []):
		unlock_module(StringName(id))
	data.coins = coins() + int(result.get("coins", 0))
	save()

func _load_save() -> Dictionary:
	var d := default_data()
	if not FileAccess.file_exists(SAVE_PATH):
		return d
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return d
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: セーブが読めないので初期値で始める")
		return d
	return _migrate(parsed, d)

## 古い版のセーブを今の形にそろえる。足りない項目は初期値で埋める。
func _migrate(loaded: Dictionary, d: Dictionary) -> Dictionary:
	for k in d:
		if loaded.has(k) and typeof(loaded[k]) == typeof(d[k]):
			if d[k] is Dictionary:
				for kk in d[k]:
					if not loaded[k].has(kk):
						loaded[k][kk] = d[k][kk]
			d[k] = loaded[k]
	d.version = SAVE_VERSION
	return d

# ── 設定 ────────────────────────────────────────────────────────────────

func default_settings() -> Dictionary:
	return {
		"master_volume": 0.8,
		"sfx_volume": 0.8,
		"engine_volume": 0.6,
		"muted": true,
		"window_mode": "windowed",
		"bindings": {},
	}

func set_setting(key: String, value) -> void:
	settings[key] = value
	_save_settings()
	apply_settings()

func set_binding(action: StringName, keycode: int) -> void:
	settings.bindings[String(action)] = keycode
	_save_settings()
	apply_settings()

func apply_settings() -> void:
	InputActions.register_defaults()
	InputActions.apply_bindings(settings.bindings)
	_apply_window_mode()
	settings_changed.emit()

func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	match settings.window_mode:
		"fullscreen":
			mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		"exclusive":
			mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	var was := DisplayServer.window_get_mode()
	if was != mode:
		DisplayServer.window_set_mode(mode)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED and (not _window_sized or was != mode):
		_fit_window_to_screen()

## ウィンドウを、いま映っている画面の大きさに合わせる（仕様書 17）。
## 使える領域の 85% に収まる、いちばん大きい 16:9 にして中央に置く。
## エディタの中に埋め込んで動かしているときは、大きさはエディタが決めるので触らない。
func _fit_window_to_screen() -> void:
	_window_sized = true
	var args := OS.get_cmdline_args()
	if args.has("--embedded") or args.has("--wid"):
		return
	var screen := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(screen)
	var size := Vector2(area.size) * 0.85
	size = Vector2(minf(size.x, size.y * 16.0 / 9.0), minf(size.y, size.x * 9.0 / 16.0))
	var win := Vector2i(size)
	DisplayServer.window_set_size(win)
	DisplayServer.window_set_position(area.position + (area.size - win) / 2)

func _load_settings() -> Dictionary:
	var s := default_settings()
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return s
	for k in s:
		s[k] = cf.get_value("settings", k, s[k])
	return s

func _save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("settings", k, settings[k])
	cf.save(SETTINGS_PATH)
