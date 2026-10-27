extends Node
const FORM = preload("res://scripts/bosses/draco_form.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled = false
	var session := RunManager.create_session(self, {"lab":true,"stage":stage,"stage_index":5,"seed":713}, false)
	session.auto_step = false
	var sim: RunSimulation = session.sim
	sim.field.bodies.clear()
	sim.state.phase = RunState.Phase.PLAY
	sim.state.ship_pos = Vector2(300, 40)
	sim.state.enemy_aim = Vector2(-800, -700)
	sim.bosses.spawn(load("res://data/bosses/draco.tres"), Vector2.ZERO)
	var actor = sim.bosses.actor
	actor.selection_enabled = false
	actor.phase = 3
	var baseline_width: float = actor.body_width
	var baseline_head: float = actor.head_scale
	var baseline_radius: float = actor.table.r[actor.body]
	actor.start_attack(&"spiral")
	check(is_equal_approx(actor.body_width, baseline_width), "螺旋は共通の胴幅を変えない")
	check(is_equal_approx(actor.head_scale, baseline_head), "螺旋は共通の頭倍率を変えない")
	check(is_equal_approx(actor.table.r[actor.body], baseline_radius), "螺旋は頭の判定だけを拡大しない")
	actor.cancel_attack()
	for staged_move in [&"leap", &"charge", &"rifts"]:
		sim.state.ship_pos = Vector2(300, 0)
		sim.state.view_center = Vector2.ZERO
		actor.table.pos[actor.body] = Vector2.ZERO
		actor.table.facing[actor.body] = PI * 0.25
		actor.body_trail.clear()
		actor.reset_pose()
		var initial_facing: float = actor.table.facing[actor.body]
		actor.start_attack(staged_move)
		var driver = actor._driver
		check(is_equal_approx(actor.table.facing[actor.body], initial_facing), "画面退場前に顔の向きを飛ばさない: " + staged_move)
		check(actor.telegraph_paths.is_empty(), "画面退場中に攻撃予告を出さない: " + staged_move)
		var frames := 0
		while driver.staging.phase != &"ready" and frames < 900:
			actor.elapsed += 1.0 / 120.0
			driver.windup(actor, 1.0 / 120.0)
			actor._update_body()
			frames += 1
		check(driver.staging.phase == &"ready" and driver.staging.exited_all, "胴体全体の退場後に入口を作る: " + staged_move)
		check(not actor.telegraph_paths.is_empty(), "再配置後に固定した経路を予告する: " + staged_move)
		actor.cancel_attack()
		check(actor.body_override.is_empty() and actor.telegraph_paths.is_empty(), "中断で胴体姿勢と予告を回収する: " + staged_move)
	actor.start_attack(&"rifts")
	check(actor._driver.center == sim.state.ship_pos, "亀裂は古い共通照準ではなく現在の自機を基準に予告する")
	actor.cancel_attack()
	actor.start_attack(&"picaro_wall")
	var wall = actor._driver
	actor.mode = &"active"
	actor.elapsed = 0.0
	wall.tick(actor, 0.01)
	check(wall.impacts.size() == 1, "口から上へ光の矢を発射する")
	if not wall.impacts.is_empty():
		sim.state.ship_pos = Vector2(520, -220)
		wall.tick(actor, float(wall.impacts[0].wait) + 0.01)
		check(wall.impacts[0].pos.distance_to(sim.state.ship_pos)<0.01, "着弾予告を見せた瞬間の自機位置を固定する")
		var locked: Vector2 = wall.impacts[0].pos
		sim.state.ship_pos += Vector2(200, 100)
		wall.tick(actor, 0.1)
		check(wall.impacts[0].pos == locked, "予告を出した後は着地点を追尾しない")
	actor.cancel_attack()
	actor.picaro.clear()
	sim.projectiles.clear_hostile()
	sim.state.ship_pos = Vector2.ZERO
	sim.state.enemy_aim = Vector2(-800, -700)
	sim.ship.invincible = false
	sim.state.ship_invuln = 0.0
	actor.start_attack(&"rifts")
	var rifts = actor._driver
	var staging_frames := 0
	while rifts.staging.phase != &"ready" and staging_frames < 600:
		actor.elapsed += 1.0 / 120.0
		rifts.windup(actor, 1.0 / 120.0)
		actor._update_body()
		staging_frames += 1
	check(rifts.staging.phase == &"ready" and staging_frames < 600, "引っ掻きは全身退場後に画面へ再入場する")
	check(rifts.paths.size() == 6 and actor.telegraph_paths.size() == 6, "引っ掻きの予告と左右の三本爪は同じ経路を使う")
	actor.mode = &"active"
	actor.elapsed = 0.16
	sim.state.ship_pos = rifts.paths[0][0].lerp(rifts.paths[0][1], 0.25)
	var hp: float = sim.state.ship_hp
	rifts.tick(actor, 0.01)
	sim.projectiles._update_hazards(0.01)
	check(sim.state.ship_hp < hp, "引っ掻きの動作に触れると実際に被弾する")
	actor.elapsed = 0.9
	rifts.tick(actor, 0.01)
	check(rifts.walls.size() == 6, "左右二回の引っ掻きが0.9秒以内に完成する")
	for h in rifts.walls: check(sim.projectiles.hazard_dmg[h] == 0.0, "残った亀裂はダメージを持たない")
	rifts.end(actor, false)
	var length: float = sim.projectiles.hazard_len[rifts.walls[0]]
	actor._update_closing_walls(float(actor.rule().recover) * 0.5)
	check(is_equal_approx(length, sim.projectiles.hazard_len[rifts.walls[0]]), "亀裂は回復中に縮まず障害物として残る")
	rifts.end(actor, true)
	actor._update_closing_walls(0.4)
	check(actor.closing_walls.is_empty(), "回復中の中断でも亀裂を修復して回収する")
	actor.cancel_attack()
	sim.projectiles.clear_hostile()
	sim.ship.invincible = true
	sim.state.ship_pos = Vector2.ZERO
	actor.table.pos[actor.body] = Vector2.ZERO
	actor.reset_pose()
	actor.start_attack(&"clones")
	var clones = actor._driver
	check(clones.units.size() == 3, "本体と複製二体で共同攻撃する")
	for unit: Dictionary in clones.units:
		for j in unit.parts.size():
			var part: Dictionary = unit.parts[j]
			var fraction := float(j + 1) / float(unit.parts.size())
			check(actor.table.pos[part.row].distance_to(FORM.sample(unit.points, fraction)) < 0.1, "複製の胴体表示と判定は同じ点列を使う")
			check(is_equal_approx(actor.table.r[part.row], actor.body_width * 0.5 * FORM.taper(fraction)), "複製の尾も描画と同じ細さの判定を持つ")
	sim.ship.invincible = false
	sim.state.ship_pos = clones.center
	sim.state.ship_invuln = 0.0
	actor.mode = &"active"
	actor.elapsed = 0.45
	var entry_hp: float = sim.state.ship_hp
	clones.tick(actor, 0.01)
	check(sim.state.ship_hp < entry_hp and clones.units[0].entry_hit, "本体の飛びかかりで被弾する")
	sim.state.ship_invuln = 0.0
	actor.elapsed = 1.15
	entry_hp = sim.state.ship_hp
	clones.tick(actor, 0.01)
	check(sim.state.ship_hp < entry_hp and clones.units[1].entry_hit, "本体に被弾後も次の複製が独立して飛びかかる")
	sim.enemies.mark_dead(clones.units[1].row)
	sim.state.ship_invuln = 0.0
	actor.elapsed = 1.85
	entry_hp = sim.state.ship_hp
	clones.tick(actor, 0.01)
	check(sim.state.ship_hp < entry_hp and clones.units[2].entry_hit, "先の複製を倒しても残った複製の攻撃は成立する")
	actor.cancel_attack()
	actor.picaro.clear()
	actor.table.pos[actor.body] = Vector2.ZERO
	sim.state.ship_pos = Vector2.ZERO
	actor.start_attack(&"spiral")
	var spiral = actor._driver
	actor.mode = &"active"
	for frame in 720:
		actor.elapsed = float(frame + 1) / 120.0
		spiral.tick(actor, 1.0 / 120.0)
		var size := 0.0
		var pose: PackedVector2Array = actor.body_points()
		for j in range(pose.size() - 1): size += pose[j].distance_to(pose[j + 1])
		check(absf(size - spiral.spiral_length) < spiral.spiral_length * 0.025, "螺旋をほどいても有効長を縮めない")
	var last_head: Vector2 = actor.table.pos[actor.body]
	spiral.end(actor, false)
	check(actor.table.pos[actor.body] == last_head, "螺旋終了時に頭を別位置へ瞬間移動しない")
	for h in spiral.walls: check(not sim.projectiles.owns_hazard(h, actor.body, actor.body_id), "終了後に螺旋の壁を残さない")
	actor.cancel_attack()
	session.free()
	print("[draco_special_quality] failures=", failures)
	get_tree().quit(1 if failures else 0)
