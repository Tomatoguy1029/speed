## ほうおう座の予告・着地・隙と、中断時の安全を確認する。
extends Node

var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	var stage := load("res://tools/content/build_runtime_stage.gd").compile(ContentManager.stage(3)) as RuntimeStage
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(stage)
		return
	var session := RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 3, "seed": 42}, false)
	session.auto_step = false
	var sim := session.sim
	sim.field.bodies.clear()
	var enemies := sim.enemies
	var t := enemies.table
	var def := enemies.def_of(&"phoenix")
	check(def.params.has("retreat_time"), "離脱と飛び込みの調整値を持つ")
	if not def.params.has("retreat_time"):
		session.free()
		get_tree().quit(1)
		return
	var p := def.params
	sim.state.enemy_aim = Vector2.ZERO
	var row := enemies.spawn(def, Vector2(200, 0))
	var b := enemies.behavior(&"phoenix")
	var render := RunPresentation.new()
	render.run = sim
	render.state = sim.state
	render.cfg = sim.cfg
	check(render._visual_for_type(&"phoenix").get_script().resource_path.ends_with("/phoenix.gd"), "専用の影と火の粉の表示を取得できる")
	render.free()
	var initial := t.pos[row]
	b.step(row, 0.01)
	check(t.pos[row].distance_to(Vector2.ZERO) > initial.length(), "最初に機体から離脱する")
	b.step(row, float(p.retreat_time))
	check(t.mode[row] == EnemyTable.Mode.WINDUP, "離脱後に着地点の予告へ進む")
	var landing := t.anchor[row]
	var away := t.pos[row]
	sim.state.enemy_aim = Vector2(900, 300)
	b.step(row, float(p.telegraph) * 0.5)
	check(t.anchor[row] == landing and t.pos[row] == away, "予告中は着地点と本体位置を固定する")
	check(_hazards(sim.projectiles) == 0, "予告はまだ攻撃判定を持たない")
	b.step(row, float(p.telegraph))
	check(t.mode[row] == EnemyTable.Mode.DASH, "予告を終えて飛び込む")
	b.step(row, float(p.dive_time) * 0.5)
	check(t.pos[row].distance_to(landing) < away.distance_to(landing), "予告した着地点へ向かう")
	b.step(row, float(p.dive_time))
	check(t.pos[row].is_equal_approx(landing) and t.mode[row] == EnemyTable.Mode.RECOVER, "着地後は停止して隙を作る")
	check(_hazards(sim.projectiles) == 1, "着地で広域炎を1回だけ出す")
	var pr := sim.projectiles
	for h in pr.hazard_alive.size():
		if pr.hazard_alive[h]:
			check(pr.hazard_pos[h] == landing and pr.hazard_len[h] > t.r[row], "炎は予告した位置で体より広い範囲を持つ")
			check(pr.hazard_dmg[h] == float(p.impact_dmg) and pr.hazard_delay[h] == 0.0, "着地時に設定した威力で発動する")
			check(pr.hazard_style[h] == ProjectileSystem.HazardStyle.PHOENIX and is_equal_approx(pr.hazard_active[h], float(p.impact_time)), "専用shaderの炎を設定した表示時間で出す")
	b.step(row, float(p.recover_time) * 0.5)
	check(t.pos[row] == landing and t.vel[row] == Vector2.ZERO and _hazards(pr) == 1, "停止中は追跡と追加攻撃を行わない")
	sim.state.ship_pos = landing
	sim.state.ship_invuln = 0.0
	sim.state.ship_shield_t = 0.0
	var hp := sim.state.ship_hp
	pr.tick(0.01, 0.01)
	check(sim.state.ship_hp < hp, "着地の炎は機体へダメージを与える")
	hp = sim.state.ship_hp
	sim.state.ship_invuln = 0.0
	pr.tick(0.01, 0.01)
	check(sim.state.ship_hp == hp, "同じ炎は機体へ重ねて当たらない")
	check(not def.params.has("chain_power"), "仕様外の撃破時誘爆を持たない")

	# 離脱・予告・飛び込みの各段階で倒しても、遅れた着地攻撃を残さない。
	for phase in [EnemyTable.Mode.MOVE, EnemyTable.Mode.WINDUP, EnemyTable.Mode.DASH]:
		pr.clear_hostile()
		enemies.clear_all()
		row = enemies.spawn(def, Vector2(200, 0))
		b.step(row, 0.01)
		if phase != EnemyTable.Mode.MOVE:
			b.step(row, float(p.retreat_time))
		if phase == EnemyTable.Mode.DASH:
			b.step(row, float(p.telegraph))
		enemies.on_enemy_death(row, 100.0)
		enemies.mark_dead(row)
		enemies.cleanup()
		enemies.tick(1.0, 1.0)
		check(_hazards(pr) == 0, "攻撃中撃破で着地攻撃を残さない: %d" % phase)
		var reused := enemies.spawn(def, Vector2(200, 0))
		check(t.mode[reused] == EnemyTable.Mode.MOVE and t.timer[reused] == 0.0 and t.charge[reused] == 0.0, "解放した行を初期状態で再利用する")

	pr.clear_hostile()
	enemies.clear_all()
	row = enemies.spawn(def, Vector2(200, 0))
	pr.director.configure({"enabled": true, "budget": 0.0, "jitter": 0.0})
	b.step(row, 0.1)
	check(t.timer[row] == 0.0 and _hazards(pr) == 0, "攻撃予算がなければ離脱と予告を始めない")
	pr.director.configure({"enabled": false})
	# 遠方のまとめ更新と位置の更新を含む、実際の敵ループで1周期を進める。
	var saw_warning := false
	var saw_dive := false
	var saw_recovery := false
	var fixed := Vector2.ZERO
	for frame in 300:
		sim.state.world_time += 1.0 / 60.0
		pr.director.advance(sim.state.world_time, enemies)
		enemies.tick(1.0 / 60.0, 1.0 / 60.0)
		if t.mode[row] == EnemyTable.Mode.WINDUP:
			saw_warning = true
			fixed = t.anchor[row]
		if t.mode[row] == EnemyTable.Mode.DASH:
			saw_dive = true
		if t.mode[row] == EnemyTable.Mode.RECOVER:
			saw_recovery = true
			check(t.pos[row].is_equal_approx(fixed) and t.vel[row] == Vector2.ZERO, "実更新でも予告位置で停止する")
			break
	check(saw_warning and saw_dive and saw_recovery and _hazards(pr) == 1, "実更新で予告から着地・炎・停止まで進む")
	pr.clear_hostile()
	enemies.clear_all()
	pr.director.advance(sim.state.world_time + 10.0, enemies)
	pr.director.configure({"enabled": true, "budget": 1.0, "jitter": 0.0})
	row = enemies.spawn(def, Vector2(200, 0))
	b.step(row, 0.1)
	check(pr.director.token(str(t.id[row])) > 0, "離脱前に攻撃の枠を取る")
	# 石化などで段階より先に攻撃枠の期限が来た場合も、枠なしで攻撃を再開しない。
	pr.director.advance(sim.state.world_time + 20.0, enemies)
	pr.director.configure({"enabled": true, "budget": 0.0, "jitter": 0.0})
	var paused := t.pos[row]
	b.step(row, 0.1)
	check(t.pos[row] == paused and _hazards(pr) == 0, "期限切れの攻撃枠は取り直すまで進めない")
	enemies.clear_all()
	check(pr.director.waiting.is_empty(), "全解放で攻撃待ちと予告を取り消す")
	session.free()
	await get_tree().process_frame
	print("[phoenix] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func _hazards(pr: ProjectileSystem) -> int:
	var count := 0
	for alive in pr.hazard_alive:
		count += int(alive)
	return count

## 描画付き確認：-- --capture。画像はリポジトリ外へ保存する。
func _capture(stage: RuntimeStage) -> void:
	OS.low_processor_usage_mode = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var session := RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 3, "seed": 42}, true)
	session.auto_step = false
	var sim := session.sim
	sim.field.bodies.clear()
	sim.enemies.clear_all()
	sim.state.ship_pos = Vector2.ZERO
	sim.state.enemy_aim = Vector2.ZERO
	sim.state.view_center = Vector2.ZERO
	var render := session.view.get_node("RunPresentation") as RunPresentation
	render.view_override = {"center": Vector2.ZERO, "zoom": 1.0}
	var row := sim.enemies.spawn(sim.enemies.def_of(&"phoenix"), Vector2(300, 0))
	var b := sim.enemies.behavior(&"phoenix")
	var p := sim.enemies.table.def[row].params
	b.step(row, 0.01)
	b.step(row, float(p.retreat_time))
	b.step(row, float(p.telegraph) * 0.6)
	for phase in ["telegraph", "dive", "impact", "recover"]:
		if phase == "dive":
			b.step(row, float(p.telegraph))
			b.step(row, float(p.dive_time) * 0.7)
		elif phase == "impact":
			b.step(row, float(p.dive_time))
			sim.projectiles.tick(0.12, 0.12)
		elif phase == "recover":
			sim.projectiles.tick(0.7, 0.7)
			b.step(row, 0.7)
		sim.state.world_time += 0.1
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/speed-phoenix-%s.png" % phase)
	if "--many" in OS.get_cmdline_user_args():
		await _capture_many(sim, render)
	session.free()
	get_tree().quit()

func _capture_many(sim: RunSimulation, render: RunPresentation) -> void:
	sim.enemies.clear_all()
	sim.projectiles.clear_hostile()
	var definition := sim.enemies.def_of(&"phoenix")
	var p := definition.params
	for x in [-360.0, 0.0, 360.0]:
		for y in [-170.0, 170.0]:
			var target := Vector2(x, y)
			sim.state.enemy_aim = target
			var row := sim.enemies.spawn(definition, target + Vector2(300, 0))
			var b := sim.enemies.behavior(&"phoenix")
			b.step(row, 0.01)
			b.step(row, float(p.retreat_time))
			b.step(row, float(p.telegraph))
			b.step(row, float(p.dive_time))
	sim.projectiles.tick(0.12, 0.12)
	var layer: DrawLayer = render._visual_for_type(&"phoenix").get("_flame_layer")
	for enabled in [false, true]:
		layer.visible = enabled
		for warmup in 12:
			await get_tree().process_frame
		var total_ms := 0.0
		var max_ms := 0.0
		for frame in 30:
			sim.state.world_time += 1.0 / 60.0
			await get_tree().process_frame
			var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			total_ms += process_ms
			max_ms = maxf(max_ms, process_ms)
		print("[phoenix visual] six flames; enabled=%s; shared layers=%d; process avg=%.2fms max=%.2fms; draw calls=%d" % [
			enabled, 1 if is_instance_valid(layer) else 0, total_ms / 30.0, max_ms,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/speed-phoenix-many.png")
