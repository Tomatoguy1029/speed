## 守る雑魚の整列・攻撃切替・対象の失効を、短い独立ランで確認する。
extends Node

var failed := 0
var passed := 0
var run: RunSimulation

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error(label)

func advance(seconds: float) -> void:
	for frame in ceili(seconds * 60.0):
		run.state.world_time += 1.0 / 60.0
		run.enemies.tick(1.0 / 60.0, 1.0 / 60.0)

func bites() -> int:
	var result := 0
	for h in run.projectiles.hazard_alive.size():
		if run.projectiles.hazard_alive[h] != 0 and run.projectiles.hazard_style[h] == ProjectileSystem.HazardStyle.BITE:
			result += 1
	return result

func reset() -> void:
	run.enemies.clear_all()
	run.projectiles.clear_hostile()
	run.state.ship_pos = Vector2.ZERO
	run.state.enemy_aim = Vector2.ZERO

func strong_at(pos: Vector2, rank := 4) -> int:
	var definition := run.enemies.def_of(&"shield").duplicate(true) as EnemyDef
	definition.speed = 0.0
	definition.rank = rank
	return run.enemies.spawn(definition, pos, {"vel": Vector2.ZERO})

func _ready() -> void:
	check(ResourceLoader.exists("res://data/enemies/defender.tres"), "守る雑魚の定義がある")
	if failed:
		get_tree().quit(1)
		return
	var stage := load("res://tools/content/build_runtime_stage.gd").compile(ContentManager.stage(2)) as RuntimeStage
	var capture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")
	var cfg := ContentManager.base.duplicate(true) as GameConfig
	for key in ["moon_count", "meteor_count", "iron_count", "saw_count"]: cfg.set(key, 0)
	var session := RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 2, "seed": 42, "config": cfg}, not capture.is_empty())
	session.auto_step = false
	run = session.sim
	run.field.bodies.clear()
	var enemies := run.enemies
	var t := enemies.table
	var definition := enemies.def_of(&"defender")
	check(definition != null, "カタログから守る雑魚を取得できる")
	if definition == null:
		session.free()
		get_tree().quit(1)
		return
	reset()
	var lone := enemies.spawn(definition, Vector2(140, 0))
	advance(1.5)
	check(bites() > 0, "強敵がいないと追跡して予告後に噛みつく")
	check(t.gate[lone] == EnemyTable.Gate.NONE, "特殊な防御条件を追加しない")

	reset()
	var guards: Array[int] = []
	for y in [-70, 0, 70]:
		guards.append(enemies.spawn(definition, Vector2(240, y)))
	var strong := strong_at(Vector2(420, 0))
	# 攻撃の予告中でも、強敵を見つけたら噛みつきを取り消す。
	t.mode[guards[1]] = EnemyTable.Mode.WINDUP
	t.timer[guards[1]] = 0.001
	t.charge[guards[1]] = 0.9
	advance(3.0)
	var center := (t.pos[guards[0]] + t.pos[guards[1]] + t.pos[guards[2]]) / 3.0
	check(center.x > 0.0 and center.x < t.pos[strong].x and absf(center.y) < 3.0, "列の中心が強敵と自機の間にある")
	check(absf(t.pos[guards[0]].x - t.pos[guards[2]].x) < 5.0 and absf(t.pos[guards[2]].y - t.pos[guards[0]].y) > t.r[guards[0]] * 2.0, "仲間が重ならず横一列に並ぶ")
	check(bites() == 0 and t.charge[guards[1]] == 0.0, "整列中は予告も噛みつきも発生しない")
	run.state.ship_pos = Vector2(420, 420)
	advance(3.0)
	center = (t.pos[guards[0]] + t.pos[guards[1]] + t.pos[guards[2]]) / 3.0
	check(absf(center.x - 420.0) < 8.0 and center.y > 0.0 and center.y < 420.0, "自機が回り込むと前衛の列も移る")
	enemies.mark_dead(strong)
	advance(3.0)
	check(bites() > 0, "強敵の死亡後は噛みつきへ戻る")

	reset()
	strong_at(Vector2(150, 0), 2)
	strong_at(Vector2(160, 0), 6)
	var boss := strong_at(Vector2(170, 0))
	t.is_boss[boss] = 1
	var part := strong_at(Vector2(180, 0))
	t.parent[part] = boss
	var far := strong_at(Vector2(float(definition.params.guard_radius) + 500.0, 0))
	enemies.spawn(definition, Vector2(100, 0))
	advance(1.5)
	check(bites() > 0, "硬め・大物・ボス・部位・遠い強敵を前衛の対象にしない")
	enemies.mark_dead(far)
	reset()
	enemies.spawn(definition, Vector2(100, 0))
	advance(1.5)
	check(bites() > 0, "クリアと行再利用の後に古い整列先を引き継がない")
	var victim := enemies.behavior(&"defender").rows()[0]
	run.state.phase = RunState.Phase.PLAY
	run.combat.damage_enemy(victim, t.max_hp[victim] + 1.0, {"cause": &"test"})
	check(t.dead[victim] != 0, "通常の攻撃で倒せる")
	check("params.guard_distance" in StageEnemyTuning.keys_for(definition), "ステージ別の整列距離を調整できる")
	if not capture.is_empty():
		reset()
		run.state.ship_pos = Vector2(-240, 0)
		strong_at(Vector2(240, 0))
		for y in [-90, -45, 0, 45, 90]:
			enemies.spawn(definition, Vector2(80, y))
		advance(2.0)
		var render := session.view.get_node("RunPresentation") as RunPresentation
		render.view_override = {"center": Vector2.ZERO, "zoom": 1.0}
		for frame in 4: await get_tree().process_frame
		check(get_viewport().get_texture().get_image().save_png(capture) == OK, "通常描画の仮表示を保存できる")

	session.free()
	await get_tree().process_frame
	print("[defender] %d passed, %d failures" % [passed, failed])
	get_tree().quit(1 if failed else 0)
