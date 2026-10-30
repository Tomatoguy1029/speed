## 敵弾の移動、誘導、被弾、無敵時間、画面外と寿命の終了を現行処理へ照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const SHIP := preload("res://tests/native_ship.gd")
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
	var probe = comparison.create_native()
	if not probe.has_method("spawn_hostile"):
		check(false, "敵弾と被弾をネイティブランが所有する")
	else:
		await compare_bullets(comparison)
	probe.close()
	print("[native_hostiles] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
func add_shot(run: RunSimulation, core, fields: Dictionary) -> void:
	var row := run.projectiles._add_hostile(fields.pos, fields.vel, fields.speed, fields.r, fields.life, fields.dmg, fields.slow, fields.turn, fields.kind)
	run.projectiles.hostile_wait[row] = fields.get("wait", 0.0)
	run.projectiles.hostile_stone[row] = fields.get("stone", 0.0)
	check(core.spawn_hostile(fields) == row, "敵弾の行を同じ順で生成・再利用する")
func compare_bullets(comparison) -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed": 348, "empty": true, "invincible": false})
	var run: RunSimulation = lab.run
	run.field.bodies.clear()
	run.field.battle_arenas.clear()
	run.ship.setup(run.ship.ctx)
	run.state.stats.invulnerability = 0.25
	var core = comparison.create_native()
	core.configure_ship(values(run.cfg, SHIP.CONFIG_KEYS), values(run.state.stats, SHIP.STAT_KEYS))
	core.start(348)
	var origin := run.state.ship_pos
	var base := {"kind": 0, "pos": origin + Vector2(100,0), "vel": Vector2(-1200,0), "speed": 1200.0, "r": 7.0, "life": 0.5, "dmg": 7.0, "slow": 0.3, "turn": 0.0}
	add_shot(run, core, base.merged({"pos": origin + Vector2(1000,0), "vel": Vector2(-120000,0), "speed": 120000.0}, true))
	add_shot(run, core, base.merged({"kind": 1, "pos": origin + Vector2(2000,0), "vel": Vector2(550,0), "speed": 550.0, "life": 3.0, "turn": 2.4}, true))
	for kind in [0, 0, 2]: add_shot(run, core, base.merged({"kind": kind}, true))
	add_shot(run, core, base.merged({"kind": 1, "pos": origin + Vector2(250,100), "vel": Vector2(0, 550), "speed": 550.0, "life": 3.0, "turn": 2.4}, true))
	add_shot(run, core, base.merged({"pos": origin + Vector2(2000,0), "vel": Vector2(1200,0)}, true))
	add_shot(run, core, base.merged({"pos": origin + Vector2(100,0), "wait": 0.1}, true))
	add_shot(run, core, base.merged({"pos": origin + Vector2(200,0), "stone": 0.08}, true))
	check(core.spawn_hostile(base.merged({"kind": 3}, true)) == -1, "未移行の圧縮弾を通常弾として受けない")
	var hits := 0
	for tick in 150:
		if tick == 60:
			# 寿命を使い切る更新でも、その線分で機体に当たる。
			add_shot(run, core, base.merged({"pos": run.state.ship_pos, "life": 0.001}, true))
		var real_dt := 1.0/60.0
		run.ship.intent.touch = true
		run.ship.tick(real_dt, real_dt)
		core.step_ship(real_dt, real_dt, {"touch": true})
		run.state.enemy_aim = run.state.ship_pos
		run.state.view_center = run.state.ship_pos
		run.state.view_half = Vector2(640,360)
		core.set_motion_context(run.state.enemy_aim, run.state.view_center, run.state.view_half)
		run.state.events.clear()
		run.projectiles._update_hostile(real_dt)
		check(core.step_hostiles(real_dt), "敵弾を世界時間で進める")
		var difference: String = comparison.difference(comparison.plain(snapshot(run.projectiles)), comparison.plain(core.hostiles_snapshot()))
		check(difference.is_empty(), "敵弾の誘導・待機・石化・終了が一致する: %d %s" % [tick, difference])
		difference = comparison.difference(comparison.plain(values(run.state, SHIP.STATE_KEYS)), comparison.plain(core.ship_snapshot()))
		check(difference.is_empty(), "被弾・減速・無敵時間が一致する: %d %s" % [tick, difference])
		difference = comparison.difference(comparison.plain(run.state.events), comparison.plain(core.drain_events()))
		check(difference.is_empty(), "被弾通知が一致する: %d %s" % [tick, difference])
		var frame_hits := 0
		for event in run.state.events:
			if event.type == &"hurt":
				hits += 1
				frame_hits += 1
		if tick in [0, 60]: check(frame_hits == 1, "高速な通過と寿命切れの接触を実際に通る")
	check(hits >= 2, "無敵の終了後の再被弾が実際に通る")
	core.close()
	check(core.spawn_hostile(base) == -1 and not core.step_hostiles(0.1), "終了したランで敵弾を動かさない")
	lab.free()
func snapshot(ps: ProjectileSystem) -> Array:
	var out: Array = []
	for i in ps.hostile_alive.size():
		if ps.hostile_alive[i] == 0: continue
		out.append({"row": i, "kind": ps.hostile_kind[i], "pos": ps.hostile_pos[i], "vel": ps.hostile_vel[i], "life": ps.hostile_life[i], "gap": ps.hostile_gap[i], "stone": ps.hostile_stone[i], "wait": ps.hostile_wait[i]})
	return out
