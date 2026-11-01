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
	check(is_equal_approx(hud._speed_indicator_angle(), -PI / 2.0), "停止時の針は左")
	state.ship_vel = Vector2(-50, 0)
	check(is_equal_approx(hud._speed_indicator_angle(), -PI / 4.0), "移動方向によらず速度で針を動かす")
	state.ship_vel = Vector2(200, 0)
	check(is_zero_approx(hud._speed_indicator_angle()), "最高速度を超えても目盛りの上端で止める")
	hud.free()
	print("[speed-indicator] failures=", failed)
	get_tree().quit(1 if failed else 0)
