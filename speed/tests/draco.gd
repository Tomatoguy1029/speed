extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	check(ResourceLoader.exists("res://data/bosses/draco.tres"), "竜のボス定義を登録する")
	if failed:
		get_tree().quit(1)
		return
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled = false
	var session := RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 5, "seed": 105}, false)
	session.auto_step = false
	var sim: RunSimulation = session.sim
	sim.field.bodies.clear()
	sim.state.phase = RunState.Phase.PLAY
	sim.state.ship_pos = Vector2(300,0)
	sim.state.enemy_aim = sim.state.ship_pos
	sim.bosses.spawn(load("res://data/bosses/draco.tres"), Vector2.ZERO)
	var actor = sim.bosses.actor
	check(actor != null and actor.def.id == &"draco", "実験場に本番用の竜を生成できる")
	check(actor.get("body_rows") != null, "全身の命中形状を持つ")
	if actor.get("body_rows") != null:
		var rows: Array = actor.body_rows
		check(rows.size() > 3, "長い胴体に沿って判定を置く")
		var before: float = sim.enemies.table.hp[actor.body]
		sim.combat.damage_enemy(rows[-1],50.0,{"cause": &"shot"})
		check(is_equal_approx(sim.enemies.table.hp[actor.body],before-50.0), "尾への命中が本体HPを削る")
		sim.combat.rebuild_grid()
		var trace := TraceRun.new()
		before = sim.enemies.table.hp[actor.body]
		for row: int in rows:
			var at: Vector2 = sim.enemies.table.pos[row]
			sim.combat.twin_sweep(trace,at-Vector2(20,0),at+Vector2(20,0))
		check(is_equal_approx(before-sim.enemies.table.hp[actor.body],sim.combat.attack_power()), "同じ突進で複数の部位に触れても一体分だけ命中する")
	var trace_hp: float = sim.enemies.table.hp[actor.body]
	sim.state.ship_pos = Vector2(140,0)
	sim.state.ship_vel = Vector2.RIGHT * sim.state.stats.max_speed * 2.0
	sim.state.stats.crit_chance = 0.0
	sim.combat.collide_ship(Vector2(-750,0),sim.cfg.trace_radius,TraceRun.new())
	check(is_equal_approx(trace_hp-sim.enemies.table.hp[actor.body],sim.combat.attack_power()), "実際の一筆でも胴体の重複命中を防ぐ")
	check(actor.get("flow_adapter") != null, "竜は共通フローのadapterを持つ")
	if actor.get("flow_adapter") != null:
		check(not actor.flow_adapter.candidates({"request":"any"}).candidates.is_empty(), "距離条件から噛みつきを候補にできる")
	check(actor.start_attack(&"bite"), "噛みつきを開始する")
	for frame in 600: actor.sim_tick(1.0/120.0,1.0/120.0)
	check(not actor.attack_playing(), "噛みつきの予告・実行・隙が終わる")
	actor.cancel_attack()
	check(actor.start_attack(&"tail_sweep"), "尾の薙ぎ払いをフロー登録から開始できる")
	for frame in 480: actor.sim_tick(1.0/120.0,1.0/120.0)
	check(actor.mode == &"idle", "尾の攻撃は隙を終えて戻る")
	actor.cancel_attack()
	var bullets_before := sim.projectiles.hostile_count()
	check(actor.start_attack(&"star_fan"), "頭部の星弾を開始できる")
	for frame in 240: actor.sim_tick(1.0/120.0,1.0/120.0)
	check(sim.projectiles.hostile_count() - bullets_before == 9, "扇に並んだ星弾を一斉発射する")
	actor.cancel_attack()
	var hazards_before := sim.projectiles.hazard_count()
	check(actor.start_attack(&"tail_slam"), "尾を叩きつける攻撃を開始する")
	for frame in 300: actor.sim_tick(1.0/120.0,1.0/120.0)
	check(sim.projectiles.hazard_count() > hazards_before, "尾の着地点に小さな衝撃波を出す")
	actor.cancel_attack()
	check(actor.start_attack(&"breath"), "隕石投射からブレスを開始する")
	if actor.technique == &"breath":
		var breath = actor._driver
		check(breath.rocks.size() == 3, "口から遮蔽用の隕石を出す")
		for frame in 150: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(breath.rays.size() > 12, "炎の表示と命中に使う遮蔽光線を計算する")
		actor.elapsed = float(actor.rule().active) * 0.5
		sim.state.ship_pos = Vector2(700,0)
		sim.ship.invincible = false
		sim.state.ship_invuln = 0.0
		var before_hp := sim.state.ship_hp
		breath.tick(actor,1.0/120.0)
		check(sim.state.ship_hp == before_hp, "隕石の裏にはブレスが当たらない")
		sim.enemies.mark_dead(breath.rocks[1].row)
		breath.tick(actor,1.0/120.0)
		check(sim.state.ship_hp < before_hp, "遮蔽が破壊されたら見える炎と同時に被弾する")
		actor.cancel_attack()
		check(breath.rocks.all(func(r): return sim.enemies.table.dead[r.row] != 0), "中断時に配置済みの隕石を崩す")
	for id in [&"charge",&"leap"]:
		actor.cancel_attack()
		check(actor.start_attack(id), "移動攻撃を開始する: "+id)
		var origin: Vector2 = sim.enemies.table.pos[actor.body]
		for frame in 300: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(sim.enemies.table.pos[actor.body].distance_to(origin)>100.0, "移動攻撃で本体が移動する: "+id)
		check(actor.mode == &"idle", "移動攻撃後に隙を終える: "+id)
	actor.cancel_attack()
	check(actor.start_attack(&"rifts"), "三本爪の亀裂を開始する")
	if actor.technique == &"rifts":
		for frame in 240: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(actor._driver.walls.size() == 6, "左右それぞれ三本の亀裂を残す")
		actor.cancel_attack()
		for frame in 60: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(actor.closing_walls.is_empty(), "亀裂を修復してから次へ進む")
	sim.projectiles.clear_hostile()
	var wall := sim.projectiles.fire_wall(Vector2(0,900),-PI*0.5,200.0,20.0,0.0,5.0,0.0)
	sim.projectiles.hazard_block[wall] = 1
	sim.projectiles.fire_bolt(Vector2(-200,800),0.0,400.0,10.0)
	sim.projectiles._update_hostile(1.0)
	check(sim.projectiles.hostile_count() == 0, "通行を止める壁は敵弾も遮る")
	sim.projectiles.release_hazard(wall)
	check(actor.get("picaro") != null, "ピカロの生成と所有者を持つ")
	if actor.get("picaro") != null:
		for id in [&"biter",&"pump"]:
			var row: int = actor.picaro.spawn_picaro(id,Vector2(500,300))
			check(sim.enemies.table.def[row].behavior == sim.enemies.def_of(id).behavior, "ピカロは元の敵の行動を使う")
			check(sim.enemies.table.def[row].params.get("picaro",false), "共通コズミック描画を指定する")
			check(not sim.enemies.def_of(id).params.get("picaro",false), "元の敵定義を変更しない")
		for frame in 150: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(actor.picaro.alive().size() == 2, "異なる既存敵のピカロを保持する")
	for expected_phase in [2,3]:
		var threshold := 0.7 if expected_phase == 2 else 0.4
		sim.combat.damage_enemy(actor.body,1.0e6,{"cause": &"shot"})
		check(actor.phase == expected_phase, "大きな一撃でもHP段階を一つずつ進める")
		check(is_equal_approx(sim.enemies.table.hp[actor.body],sim.enemies.table.max_hp[actor.body] * threshold), "超過分を切り捨てて閾値でHPを止める")
		if expected_phase == 2: check(sim.state.controls_locked, "初回ピカロ生成だけ操作を止める")
		else: check(not sim.state.controls_locked, "終盤移行では操作を維持する")
		check(not sim.state.boss_dead, "段階移行は最終勝利を通知しない")
		for frame in 1200: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(actor.mode == &"idle" and sim.enemies.table.guard[actor.body] <= 0.0, "移行後に攻撃と被弾を再開できる")
	session.free()
	print("[draco] failures=",failed)
	get_tree().quit(1 if failed else 0)
