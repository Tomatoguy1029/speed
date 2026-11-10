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
	var cpp_hud = preload("res://scripts/ui/hud.gd").new()
	cpp_hud.bridge = RefCounted.new()
	cpp_hud._ready_cpp()
	var snapshot := {"phase":0,"input_enabled":true,"tracing":false,"ship_boost_t":0.0,"glide":false,"ship_vel":Vector2(30,0),"max_speed":100.0,"steer_cruise":0.3}
	cpp_hud.apply_snapshot(snapshot)
	check(cpp_hud._speed_indicator_mode()==INDICATOR.NORMAL,"C++の巡航速度を読み取り専用で表示する")
	snapshot.ship_vel = Vector2(60,0)
	check(cpp_hud._speed_indicator_mode()==INDICATOR.FAST,"C++の巡航超過を表示する")
	snapshot.glide = true
	snapshot.tracing = true
	check(cpp_hud._speed_indicator_mode()==INDICATOR.BOOST,"C++でも突進を勢いより優先する")
	cpp_hud._update_speed_indicator(0.1)
	var paused: float = cpp_hud._speed_indicator.value
	snapshot.input_enabled = false
	cpp_hud._update_speed_indicator(1.0)
	check(cpp_hud._speed_indicator.value==paused,"C++のUI停止中も針と表示時計を止める")
	for extent in [Vector2(640,480),Vector2(1280,720)]:
		cpp_hud.size = extent
		cpp_hud._layout_cpp_art()
		check(cpp_hud._speed_indicator.position.x<extent.x and cpp_hud._speed_indicator.position.y<extent.y,"C++の速度計もサイズ変更後の右下へ配置する")
	cpp_hud.free()
	var hud = preload("res://scripts/ui/hud.gd").new()
	hud.bridge = RefCounted.new()
	hud._ready_cpp()
	var state := {"phase":RunIds.Phase.Play,"input_enabled":true,"tracing":false,"ship_boost_t":0.0,"glide":false,"ship_vel":Vector2(30,0),"max_speed":100.0,"steer_cruise":0.3}
	hud.apply_snapshot(state)
	check(hud._speed_indicator_mode() == INDICATOR.NORMAL, "巡航速度では通常表示")
	state.ship_vel = Vector2(60, 0)
	check(hud._speed_indicator_mode() == INDICATOR.FAST, "巡航速度を超えたら高速表示")
	state.ship_vel = Vector2(30, 0)
	state.glide = true
	check(hud._speed_indicator_mode() == INDICATOR.FAST, "勢いが残る間は速度が巡航と等しくても高速表示")
	state.ship_boost_t = 0.1
	check(hud._speed_indicator_mode() == INDICATOR.BOOST, "ブースト保持を高速状態より優先")
	state.ship_boost_t = 0.0
	state.tracing = true
	check(hud._speed_indicator_mode() == INDICATOR.BOOST, "突進中はブースト表示")
	state.tracing = false
	state.glide = false
	check(hud._speed_indicator_mode() == INDICATOR.NORMAL, "実際の突進と高速移動が終わると通常表示")

	var indicator = hud._speed_indicator
	indicator.rng.seed = 12
	var low := 8.0
	var high := 0.0
	for i in 600:
		var before: float = indicator.value
		indicator.advance(INDICATOR.NORMAL, 1.0 / 60.0)
		low = minf(low, indicator.value)
		high = maxf(high, indicator.value)
		check(absf(indicator.value - before) < 0.06, "通常の揺れは高速でプルプル動かない")
	check(low >= 1.0 and high <= 2.0 and high - low > 0.2, "通常は1〜2の中で小さく不規則に動く")

	var before_boost: float = indicator.value
	var before_color: Color = indicator.fill_color
	state.tracing = true
	hud._update_speed_indicator(1.0 / 60.0)
	check(indicator.value > before_boost and indicator.value < 3.0, "ブースト開始で針は瞬間移動しない")
	check(absf(indicator.fill_color.r - before_color.r) < 0.08, "内部色も開始フレームで瞬間切替しない")
	advance(indicator, INDICATOR.BOOST, 1.5)
	check(indicator.value >= 7.0 and indicator.value <= 8.0, "ブースト中は7〜8へ上がる")
	check(indicator.fill_color.r > 0.84 and indicator.fill_color.g < 0.38,
			"ブースト内部は採用した赤へ到達する")
	check(INDICATOR.BOOST_COLOR == Color("#da5c60"), "採用したブースト赤を使う")

	var boost_value: float = indicator.value
	indicator.advance(INDICATOR.FAST, 1.0 / 60.0)
	check(indicator.value > 7.0 and indicator.value <= boost_value + 0.02, "高速へ移る境界でも針の慣性を保つ")
	check(indicator.fill_color.g < 0.4, "高速への状態境界で内部を黄色へ瞬間切替しない")
	advance(indicator, INDICATOR.FAST, 3.5)
	low = 8.0
	high = 0.0
	for i in 360:
		indicator.advance(INDICATOR.FAST, 1.0 / 60.0)
		low = minf(low, indicator.value)
		high = maxf(high, indicator.value)
	check(low >= 4.0 and high <= 6.0 and high - low > 0.1, "高速中も4〜6の中で微かに不規則に動く")
	check(indicator.fill_color.is_equal_approx(INDICATOR.FAST_COLOR), "高速中は既存の黄色へ落ち着く")

	indicator.advance(INDICATOR.NORMAL, 1.0 / 60.0)
	check(indicator.value > 4.0, "高速終了で針を瞬間的に通常範囲へ戻さない")
	advance(indicator, INDICATOR.NORMAL, 3.5)
	check(indicator.value >= 1.0 and indicator.value <= 2.0, "高速終了後は通常範囲へ戻る")
	check(indicator.fill_color.g > 0.79 and indicator.fill_color.b > 0.88, "通常の水色へ連続的に戻る")

	var value_before_pause: float = indicator.value
	before_color = indicator.fill_color
	state.phase = RunIds.Phase.Paused
	hud._update_speed_indicator(1.0)
	check(indicator.value == value_before_pause and indicator.fill_color == before_color, "ポーズ中は針と内部色を保つ")
	state.phase = RunIds.Phase.Play
	state.input_enabled = false
	hud._update_speed_indicator(1.0)
	check(indicator.value == value_before_pause, "メニュー中は揺れの時計も止める")
	state.input_enabled = true
	state.input_enabled = false
	hud._update_speed_indicator(1.0)
	check(indicator.value == value_before_pause, "報酬画面中も表示時計を止める")

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
	indicator.free()
	hud.free()
	print("[speed-indicator] failures=", failed)
	get_tree().quit(1 if failed else 0)
