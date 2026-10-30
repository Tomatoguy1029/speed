## 現行の機体更新へ同じ入力を与え、C++が所有する位置・速度を照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const CONFIG_KEYS := ["start_radius", "base_max_speed", "stick_dead_zone", "mouse_dead_zone", "steer_cruise", "glide_hold", "glide_fade", "cruise_floor", "energy_cut", "cruise_drag", "overcap_decay", "field_radius", "boundary_push", "ship_radius", "crash_restitution", "ship_hurt_time"]
const STAT_KEYS := ["max_hp", "max_speed", "turn_rate", "acceleration", "glide_duration_mult", "invulnerability"]
const STATE_KEYS := ["ship_pos", "ship_vel", "ship_heading", "ship_hp", "ship_hurt", "ship_invuln", "ship_shield_flash", "ship_shield_t", "ship_shield_max", "ship_boost_t", "ship_fade_t", "glide", "glide_t", "glide_speed", "peak_speed"]
const DRAW_CONFIG := ["draw_min_charge", "draw_length", "draw_step", "draw_confirm_delay", "draw_run_time", "draw_time_scale", "draw_run_slow_ref", "draw_run_scale_min", "boost_duration", "carry", "launch_ratio", "glide_speed_ratio"]
const DRAW_STATS := ["capacity", "charge_time", "length_mult"]
const DRAW_STATE := ["gauge", "drawing", "draw_started", "draw_blocked", "trace_full_charge", "draw_start_charge", "draw_gauge", "draw_limit", "draw_length", "draw_points", "tracing", "dash_id", "trace_path", "trace_lengths", "trace_total", "trace_progress"]
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func values(object: Object, keys: Array) -> Dictionary:
	var out := {}
	for key in keys: out[key] = object.get(key)
	return out
func _ready() -> void:
	var comparison = COMPARE.new()
	var core = comparison.create_native()
	if core == null or not core.has_method("configure_ship"):
		check(false, "機体の状態をC++のランで所有する")
	else:
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed": 12, "empty": true})
		var run: RunSimulation = lab.run
		run.field.bodies.clear()
		run.field.battle_arenas.clear()
		run.ship.setup(run.ship.ctx)
		var config := values(run.cfg, CONFIG_KEYS)
		var stats := values(run.state.stats, STAT_KEYS)
		var invalid := config.duplicate()
		invalid.energy_cut = NAN
		check(not core.configure_ship(invalid, stats), "不正な機体定義を拒否する")
		check(core.configure_ship(config, stats) and core.start(12), "機体を編集値から準備する")
		check(core.ship_snapshot() == values(run.state, STATE_KEYS), "機体の初期状態が一致する")
		for tick in 240:
			var command := {"touch": tick >= 120, "has_cursor": tick < 100, "cursor": Vector2(200, -180), "stick_active": tick >= 140, "stick": Vector2(-0.7, 0.3) if tick < 200 else Vector2(0.001, 0)}
			for key in command: run.ship.intent.set(key, command[key])
			var dt := 1.0 / 60.0
			var world_dt := 0.0 if tick in [45, 46, 150] else dt
			run.ship.tick(dt, world_dt)
			check(core.step_ship(dt, world_dt, command), "機体の固定更新を実行する")
			var difference: String = comparison.difference(comparison.plain(values(run.state, STATE_KEYS)), comparison.plain(core.ship_snapshot()))
			check(difference.is_empty(), "マウス・スティック・無入力・時間停止が一致する tick=%d: %s" % [tick, difference])
			if not difference.is_empty(): break
		var before: Dictionary = core.ship_snapshot()
		check(not core.step_ship(0.01, -0.01, {}) and core.ship_snapshot() == before, "不正な時間で機体を変えない")
		check(not core.configure_ship(config, stats), "開始後に機体を再初期化しない")
		core.close()
		await check_draw(comparison, lab)
		await check_mouse_draw(comparison, lab)
		check(not core.step_ship(0.01, 0.01, {}), "終了した機体を動かさない")
		lab.free()
	print("[native_ship] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func check_draw(comparison, lab) -> void:
	var core = comparison.create_native()
	if not core.has_method("configure_draw"):
		check(false, "描線と発進をネイティブランが所有する")
		return
	await lab.reset({"seed": 12, "empty": true})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.ship.setup(run.ship.ctx)
	check(core.configure_ship(values(run.cfg, CONFIG_KEYS), values(run.state.stats, STAT_KEYS)), "描線用の機体を準備する")
	check(core.configure_draw(values(run.cfg, DRAW_CONFIG), values(run.state.stats, DRAW_STATS)) and core.start(12), "描線の編集値を準備する")
	var initial := run.state.ship_pos
	var saw_trace := false
	var saw_glide := false
	for tick in 540:
		# 空の線を取消し、短い曲線を発進。発進後の勢いが切れるまで比較する。
		var command := {"touch": true, "has_cursor": tick != 1, "press": tick in [0, 5], "pen_release": tick in [1, 12], "pen": initial + Vector2((tick-5)*30, -10 if tick == 8 else 0), "cursor": initial + Vector2(800, 0)}
		for key in command: run.draw.intent.set(key, command[key])
		run.state.sim_time = tick / 60.0
		run.draw.handle_input()
		check(core.handle_draw(command, roundi(run.state.sim_time * 1000.0), run.state.camera_zoom), "同じ入力で描線を更新する")
		run.draw.tick(1.0/60.0, 1.0/60.0)
		check(core.step_draw(1.0/60.0), "同じ実時間でなぞりを更新する")
		saw_trace = saw_trace or run.state.tracing
		saw_glide = saw_glide or run.state.glide
		if tick == 1: check(not run.state.drawing and not run.state.tracing and run.state.gauge == 1.0, "短すぎる線は充填を消費せず取り消す")
		var world_dt := run.draw.world_scale()/60.0
		check(run.draw.world_scale() == core.world_scale(), "世界時間の倍率が一致する")
		run.ship.tick(1.0/60.0, world_dt)
		core.step_ship(1.0/60.0, world_dt, {})
		var difference: String = comparison.difference(comparison.plain(values(run.state, DRAW_STATE)), comparison.plain(core.draw_snapshot()))
		check(difference.is_empty(), "描線・取消・発進・充填が一致する tick=%d: %s" % [tick, difference])
		var ship_difference: String = comparison.difference(comparison.plain(values(run.state, STATE_KEYS)), comparison.plain(core.ship_snapshot()))
		check(ship_difference.is_empty(), "なぞりと勢いの機体更新が一致する tick=%d: %s" % [tick, ship_difference])
		if not difference.is_empty() or not ship_difference.is_empty(): break
	check(saw_trace and saw_glide and not run.state.glide, "なぞり・勢い・通常移動への復帰を通る")
	core.close()

func check_mouse_draw(comparison, lab) -> void:
	await lab.reset({"seed": 12, "empty": true})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.ship.setup(run.ship.ctx)
	var core = comparison.create_native()
	core.configure_ship(values(run.cfg, CONFIG_KEYS), values(run.state.stats, STAT_KEYS))
	core.configure_draw(values(run.cfg, DRAW_CONFIG), values(run.state.stats, DRAW_STATS))
	core.start(12)
	var first := 17
	var confirm := first + ceili(run.cfg.draw_confirm_delay * 1000.0)
	var times := [0, first, first + 1, confirm - 1, confirm]
	for i in times.size():
		var command := {"touch": false, "alt_press": i == 0, "press": i in [1, 3, 4], "has_cursor": true, "pen": run.state.ship_pos + Vector2(100, 0) if i >= 2 else run.state.ship_pos}
		for key in command: run.draw.intent.set(key, command[key])
		run.state.sim_time = times[i] / 1000.0
		run.draw.handle_input()
		core.handle_draw(command, times[i], run.state.camera_zoom)
		var difference: String = comparison.difference(comparison.plain(values(run.state, DRAW_STATE)), comparison.plain(core.draw_snapshot()))
		check(difference.is_empty(), "補助キーとクリック確定の時間境界が一致する: " + difference)
		if i == 0: check(run.state.drawing and not run.state.draw_started, "補助キーは始点の入力を待つ")
		if i == 3: check(run.state.drawing and not run.state.tracing, "待ち時間の直前には確定しない")
		if i == 4: check(run.state.tracing, "待ち時間に到達したクリックで発進する")
	core.close()
