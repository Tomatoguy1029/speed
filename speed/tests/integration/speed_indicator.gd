extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS

const INDICATOR := preload("res://scripts/ui/speed_indicator.gd")
var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func advance(indicator: INDICATOR, mode: int, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		indicator.advance(mode, 1.0 / 60.0)

func _ready() -> void:
	var hud = preload("res://scripts/ui/hud.gd").new()
	hud.bridge = RefCounted.new()
	hud._ready_cpp()
	hud._cpp_ui = {"fuel":50.0,"fuel_max":150.0,"boost_min_cost":4.0}
	hud._update_fuel_meter()
	check(hud._fuel_meter.fuel==50.0 and hud._fuel_meter.maximum==150.0,"HUDは燃料と最大量をそのまま表示する")
	for extent in [Vector2(640,480),Vector2(1280,720)]:
		hud.size = extent
		hud._layout_cpp_art()
		check(hud._fuel_meter.position.x<extent.x and hud._fuel_meter.position.y<extent.y,"燃料メーターを画面の右下へ配置する")
	var a = INDICATOR.new()
	var b = INDICATOR.new()
	a.rng.seed = 42
	b.rng.seed = 42
	for mode in [INDICATOR.NORMAL, INDICATOR.BOOST, INDICATOR.FAST, INDICATOR.NORMAL]:
		for i in 240: a.advance(mode, 1.0 / 60.0)
		for i in 120: b.advance(mode, 1.0 / 30.0)
		check(is_equal_approx(a.value, b.value) and a.fill_color.is_equal_approx(b.fill_color),
				"フレーム間隔が変わっても揺れ・慣性・色の進みが一致する")
	a.free()
	b.free()
	hud.free()
	print("[speed-indicator] failures=", failed)
	get_tree().quit(1 if failed else 0)
