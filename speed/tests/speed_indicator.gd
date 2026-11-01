extends Node

var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	var hud = preload("res://scripts/ui/hud.gd").new()
	hud.run = RunSimulation.new()
	hud.run.state = RunState.new()
	hud.run.cfg = GameConfig.new()
	hud.run.cfg.steer_cruise = 0.3
	var state := hud.run.state as RunState
	state.stats = ShipStats.new()
	state.stats.max_speed = 100.0
	state.ship_vel = Vector2(30, 0)
	check(hud._speed_indicator_mode() == 0, "巡航速度では通常色")
	state.ship_vel = Vector2(60, 0)
	check(hud._speed_indicator_mode() == 1, "巡航速度を超えたら高速色")
	state.ship_vel = Vector2(30, 0)
	state.glide = true
	check(hud._speed_indicator_mode() == 1, "突進後の勢いが残る間は高速色")
	state.ship_boost_t = 0.1
	check(hud._speed_indicator_mode() == 2, "ブースト保持を高速状態より優先")
	state.ship_boost_t = 0.0
	state.tracing = true
	check(hud._speed_indicator_mode() == 2, "突進中はブースト色")
	state.tracing = false
	state.glide = false
	check(hud._speed_indicator_mode() == 0, "突進と勢いが終わると通常色へ戻る")
	state.ship_vel = Vector2.ZERO
	var left: float = hud._speed_indicator_angle()
	check(left > -PI / 2.0 and left < deg_to_rad(-85.0), "停止時は左端のすぐ手前")
	state.ship_vel = Vector2(30, 0)
	check(is_equal_approx(hud._speed_indicator_angle(), left), "通常の巡航速度でも左端近くへ戻す")
	state.ship_vel = Vector2(-50, 0)
	var middle: float = hud._speed_indicator_angle()
	state.ship_vel = Vector2(50, 0)
	check(is_equal_approx(hud._speed_indicator_angle(), middle) and middle > left, "移動方向によらず速度で針を動かす")
	state.ship_vel = Vector2(100, 0)
	var right: float = hud._speed_indicator_angle()
	check(is_equal_approx(right, deg_to_rad(-10.0)), "最高速度でも右端の1目盛り手前")
	state.ship_vel = Vector2(200, 0)
	check(is_equal_approx(hud._speed_indicator_angle(), right), "最高速度を超えても針を振り切らせない")
	hud._speed_needle_angle = left
	hud._update_speed_indicator(1.0 / 60.0)
	check(hud._speed_needle_angle > left and hud._speed_needle_angle < right, "速度が跳ねても針は瞬間移動しない")
	hud._speed_needle_angle = left
	hud._update_speed_indicator(0.1)
	var after_tenth: float = hud._speed_needle_angle
	check(after_tenth > lerpf(left, right, 0.85) and after_tenth < right, "0.1秒で目標の近くまで素早く跳ね上がる")
	hud._speed_needle_angle = left
	for i in 6: hud._update_speed_indicator(1.0 / 60.0)
	check(is_equal_approx(hud._speed_needle_angle, after_tenth), "追従の速さはフレーム間隔によらない")
	state.phase = RunState.Phase.PAUSED
	hud._update_speed_indicator(1.0)
	check(is_equal_approx(hud._speed_needle_angle, after_tenth), "ポーズ中は針も止める")
	state.phase = RunState.Phase.PLAY
	state.ship_vel = Vector2(30, 0)
	for i in 60: hud._update_speed_indicator(1.0 / 60.0)
	check(is_equal_approx(hud._speed_needle_angle, left), "巡航に戻ると針が左端近くまで下がる")
	hud.free()
	print("[speed-indicator] failures=", failed)
	get_tree().quit(1 if failed else 0)
