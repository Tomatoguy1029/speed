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
	check(actor.get("entrance") != null, "静かな星空から対面までを所有する")
	if actor.get("entrance") != null:
		actor.entrance.begin()
		check(not actor.start_attack(&"bite") and sim.state.controls_locked, "登場中は攻撃と操作を止める")
		for frame in 1100: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(actor.mode==&"idle" and not sim.state.controls_locked and sim.state.cinematic_bars==0.0, "対面後に戦闘へ引き渡す")
	# The entrance now stages an authored world-space confrontation. The
	# independent collision/attack fixtures below explicitly use their own origin.
	sim.enemies.table.pos[actor.body] = Vector2.ZERO
	sim.enemies.table.facing[actor.body] = 0.0
	actor.reset_pose()
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
		for frame in ceili((float(actor.rule().warn)+float(actor.rule().active)+float(actor.rule().recover)+0.1)*120.0): actor.sim_tick(1.0/120.0,1.0/120.0)
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
	actor.cancel_attack()
	check(actor.start_attack(&"picaro_wall"), "隊列と口からの光の矢を開始する")
	if actor.technique == &"picaro_wall":
		var driver = actor._driver
		for frame in 240: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(driver.shots>1, "口から上向きに複数発を連射する")
		check(not driver.impacts.is_empty(), "画面外へ消えた後に固定地点を予告する")
		if not driver.impacts.is_empty():
			var target: Vector2 = driver.impacts[0].pos
			sim.state.enemy_aim += Vector2(200,0)
			actor.sim_tick(0.01,0.01)
			check(driver.impacts[0].pos == target, "予告後は自機を追わない")
		actor.cancel_attack()
	actor.cancel_attack()
	check(actor.start_attack(&"clones"), "全身複製を開始できる")
	if actor.technique == &"clones":
		var clones = actor._driver
		check(clones.units.size()==3, "本体を含め合計三体を編成する")
		var hp: float = sim.enemies.table.hp[actor.body]
		var row: int = clones.units[1].row
		sim.combat.damage_enemy(row,10.0,{"cause":&"shot"})
		check(sim.enemies.table.hp[actor.body]==hp, "複製のHPは本体と独立する")
		for frame in 1400: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(actor.mode==&"idle", "複製の共同攻撃から回収を終える")
		check(sim.enemies.table.dead[row]!=0, "残った複製は吸収だけで回収する")
	actor.cancel_attack()
	check(actor.start_attack(&"inhale"), "吸引と吐き出しを開始する")
	if actor.technique == &"inhale":
		var inhale = actor._driver
		var member: int = actor.picaro.spawn_picaro(&"pump",sim.enemies.table.pos[actor.body]+Vector2(70,0))
		for frame in 600: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(sim.enemies.table.dead[member]!=0, "口元に来たピカロを吸収する")
		check(inhale.spent and inhale.stars==0, "吸収星数は直後の吐き出し一回で使い切る")
		actor.cancel_attack()
	actor.cancel_attack()
	check(actor.start_attack(&"spiral"), "螺旋収縮を開始する")
	if actor.technique == &"spiral":
		var spiral = actor._driver
		var center: Vector2 = spiral.center
		sim.state.enemy_aim += Vector2(500,0)
		for frame in 540: actor.sim_tick(1.0/120.0,1.0/120.0)
		check(spiral.center==center, "螺旋の中心は開始時の位置に固定する")
		check(not spiral.walls.is_empty(), "青紫の胴体オーラは弾と機体を遮る")
		actor.cancel_attack()
		check(spiral.walls.all(func(h): return sim.projectiles.hazard_alive[h]==0), "中断した螺旋壁を残さない")
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
	check(actor.get("finale") != null, "HP0を専用の最終決着へ接続する")
	if actor.get("finale") != null:
		sim.combat.damage_enemy(actor.body,1.0e6,{"cause":&"shot"})
		check(actor.mode==&"finale" and not sim.state.boss_dead, "核解放前に勝利を通知しない")
		for frame in 720: actor.advance_finale(1.0/120.0,Intent.new())
		check(actor.finale.stage==&"input", "解放と合体から自由描画へ進む")
		check(sim.state.final_modules.size()==4, "四つの伝説モジュールを武器欄へ渡す")
		var intent := Intent.new()
		intent.press=true;intent.has_cursor=true;intent.pen=Vector2.ZERO
		actor.advance_finale(0.01,intent)
		intent.press=false;intent.pen=Vector2(10000,10000)
		actor.advance_finale(0.01,intent)
		check(actor.finale.strokes.size()>=2 and actor.finale.stage==&"input", "無制限の自由描画中も自動確定しない")
		check(sim.state.world_scale==0.0, "最終描画中の世界速度はゼロ")
		intent.pen_release=true
		actor.advance_finale(0.01,intent)
		check(actor.finale.stage==&"strikes", "離すと入力経路に関係なく固定フィニッシュを始める")
		sim.state.lab_mode=false
		for frame in 1500: actor.advance_finale(1.0/120.0,Intent.new())
		check(sim.state.boss_dead and actor.finale.completed, "固定連撃と切断・爆発を終えて勝利を通知する")
		var wins := sim.state.events.filter(func(e): return e.type==&"boss_defeated").size()
		actor.advance_finale(1.0,Intent.new())
		check(sim.state.events.filter(func(e): return e.type==&"boss_defeated").size()==wins and wins==1, "最終勝利を一度だけ通知する")
		sim.state.lab_mode=true
	session.free()
	print("[draco] failures=",failed)
	get_tree().quit(1 if failed else 0)
