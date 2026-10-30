## 現行の機体更新へ同じ入力を与え、C++が所有する位置・速度を照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const CONFIG_KEYS := ["start_radius", "base_max_speed", "stick_dead_zone", "mouse_dead_zone", "steer_cruise", "glide_hold", "glide_fade", "cruise_floor", "energy_cut", "cruise_drag", "overcap_decay", "field_radius", "boundary_push", "ship_radius", "crash_restitution", "ship_hurt_time"]
const STAT_KEYS := ["max_hp", "max_speed", "turn_rate", "acceleration", "glide_duration_mult", "invulnerability"]
const STATE_KEYS := ["ship_pos", "ship_vel", "ship_heading", "ship_hp", "ship_hurt", "ship_invuln", "ship_shield_flash", "ship_shield_t", "ship_boost_t", "ship_fade_t", "glide", "glide_t", "glide_speed", "peak_speed"]
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
		check(not core.step_ship(0.01, 0.01, {}), "終了した機体を動かさない")
		lab.free()
	print("[native_ship] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
