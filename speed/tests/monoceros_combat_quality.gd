## 実際の選択・予告・角判定へ、独立した自機軌道を流す回帰確認。
extends Node
const DT := 1.0 / 120.0
var sim: RunSimulation
var session: Node
var actor: MonocerosBoss
var failed := 0
var checks := 0
var launches := 0
var locks := 0
var hit_count := 0
var results: Array[Dictionary] = []
var selection_results: Array[Dictionary] = []
var encounter_results: Array[Dictionary] = []
var first_hit := {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	SaveManager.data = SaveManager.default_data()
	SaveManager.dev_meta_override = {}
	var stage := ContentManager.runtime_stage(1)
	session = RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 1, "seed": 42}, false)
	session.auto_step = false
	sim = session.sim
	sim.ship.hurt_recorded.connect(func(_event):
		hit_count += 1
		if first_hit.is_empty(): first_hit = {"time":actor.clock,"mode":actor.mode,"timeline":actor._runner.stage_time if actor.is_sequenced(actor.technique) else actor.timeline.current_animation_position,"at":str(sim.state.ship_pos),"horn":str(actor.horn_points())})
	print("[monoceros_quality] user_dir=", OS.get_user_data_dir())
	for phase in [1, 2]:
		for angle in [0.0, PI * 0.5, PI, -PI * 0.5]:
			for id in [&"charge", &"return_charge", &"sweep", &"kick", &"lance"]:
				if id == &"lance" and phase == 1: continue
				var distances: Array = [350.0, 900.0] if id in [&"charge", &"return_charge"] else [400.0, 650.0] if id == &"sweep" else [160.0, 225.0] if id == &"kick" else [500.0, 900.0]
				for distance in distances:
					var at := Vector2.from_angle(angle) * float(distance)
					var facing: float = angle - PI if id == &"kick" else angle
					var result := trial(id, at, Vector2.ZERO, phase, facing)
					check(result.hit, "静止自機へ到達 phase=%d %s %.0f %.2f" % [phase,id,distance,angle])
					check(result.recovered, "攻撃後は隙へ戻る " + str(result))
					check(result.lock_count == result.launch_count, "各発進の固定は一度 " + str(result))
	# 編集した距離条件も実際の形状を越えて成立させない。
	for pair in [[&"sweep", 1400.0], [&"kick", 255.0], [&"lance", 1300.0]]:
		fresh(Vector2(float(pair[1]), 0), Vector2.ZERO, 2, PI if pair[0] == &"kick" else 0.0)
		actor._cooldown = 0.0
		var gate: Dictionary = actor.action_rules.conditions[String(pair[0])].duplicate()
		gate.max = 10000.0
		check(not actor.technique_ready(pair[0], gate), "編集条件を広げても実際に届かない技を候補から外す " + str(pair))
	# 遅れた共有照準が範囲内でも、現在位置が範囲外なら開始しない。
	fresh(Vector2(1600,0), Vector2.ZERO, 2, 0.0)
	actor._cooldown = 0.0
	sim.state.enemy_aim = Vector2(600,0)
	check(not actor.technique_ready(&"charge", actor.action_rules.conditions.charge), "古い照準で遠方の自機へ空振りを選ばない")
	sim.state.ship_pos = Vector2(600,0)
	check(actor.technique_ready(&"charge", actor.action_rules.conditions.charge), "CDと形態が同じでも現在位置が範囲に戻れば選べる")
	for phase in [1,2]:
		for angle in [PI-0.55,PI+0.55]:
			for distance in [180.0,225.0]:
				var result := trial(&"kick",Vector2.from_angle(angle)*distance,Vector2.ZERO,phase,0.0)
				check(result.hit, "背後の角度条件の端でも蹄が自機へ届く " + str(result))
				check(is_zero_approx(actor.table.facing[actor.body]), "蹴りは本体を振り向かせず蹄で狙う")
	# 予告前から等速移動していた自機。方向転換を要求しない空振りを分離する。
	for id in [&"charge", &"return_charge", &"lance"]:
		for angle in [0.0, PI*0.5, PI, -PI*0.5]:
			for distance in [400.0,600.0,700.0]:
				for speed in [250.0, 500.0]:
					var radial := Vector2.from_angle(angle)
					var velocity: Vector2 = radial.orthogonal() * speed
					var result := trial(id, radial * distance - velocity * 0.65, velocity, 2, angle)
					check(result.hit, "等速横移動に脅威がある " + str(result))
					check(result.recovered, "等速軌道でも回復する " + str(result))
	# 往復の全パスも等速軌道へ再捕捉し、最後に長い回復へ戻る。
	for phase in [1,2]:
		for angle in [0.0,PI*0.5,PI,-PI*0.5]:
			var radial := Vector2.from_angle(angle)
			var velocity := radial.orthogonal()*500.0
			var result := trial(&"return_charge", radial*600.0-velocity*0.65, velocity, phase, angle, false, true)
			check(result.launch_count == int(actor.rule().passes) and result.lock_count == int(actor.rule().passes), "往復の全パスで予告・再捕捉・固定 " + str(result))
			check(result.hits >= 1, "等速軌道へ往復の各パスが到達 " + str(result))
			check(result.recovery_seconds >= float(actor.rule().recover)-DT, "往復終了後に全体の隙を作る")
	# 近接技は範囲に残る遅い等速軌道と、予告中に範囲を出る軌道を分ける。
	var sweep_result := trial(&"sweep", Vector2(400, 0), Vector2.ZERO, 1, 0.0)
	check(sweep_result.hit, "踏み込み薙ぎは正面400の静止自機へ届く")
	sweep_result = trial(&"sweep", Vector2(400, 0), Vector2.ZERO, 1, 0.0, true)
	check(not sweep_result.hit and sweep_result.recovered, "踏み込み薙ぎの固定を見て遠ざかれば回避できる")
	for id in [&"kick"]:
		for sign_y in [-1.0,1.0]:
			var at := Vector2(130, -sign_y*20) if id == &"sweep" else Vector2(-160,-sign_y*20)
			var result := trial(id, at, Vector2(0,sign_y*45), 1, 0.0)
			check(result.hit, "範囲内の近接等速軌道へ到達 " + str(result))
			result = trial(id, at, Vector2(0,sign_y*500), 1, 0.0)
			check(not result.hit and result.recovered, "予告中に近接範囲から出れば回避 " + str(result))
	# 固定を見てから方向を変える。追尾せず、予告の直線から抜けられる。
	for id in [&"charge", &"return_charge", &"lance", &"sweep", &"kick"]:
		for angle in [0.0, PI*0.5, PI, -PI*0.5]:
			var radial := Vector2.from_angle(angle)
			var distance := 600.0 if id in [&"charge", &"return_charge", &"lance"] else 400.0 if id == &"sweep" else 130.0
			var facing: float = angle-PI if id == &"kick" else angle
			var result := trial(id,radial*distance,Vector2.ZERO,2,facing,true)
			check(not result.hit, "読める固定後の横回避が成立 " + str(result))
	# 同じ抽選器を使い、距離・背後・形態・CDで候補と選択が変わる。
	for phase in [1,2]:
		for context in ["front", "rear", "middle"]:
			var chosen := {}
			for seed_value in range(1,33):
				var at := Vector2(150,0) if context == "front" else Vector2(-180,0) if context == "rear" else Vector2(700,0)
				fresh(at,Vector2.ZERO,phase,0.0)
				actor._cooldown = 0.0
				actor.selection_enabled = true
				sim.state.rng.seed = seed_value
				if context == "middle" and seed_value % 2 == 0: actor.flow_runner.index = 1
				var candidates: Array = actor.flow_adapter.candidates({"request":"any"}).candidates.map(func(c): return String(c.id))
				actor.flow_runner.tick(DT,{},actor.flow_adapter)
				var selected := String(actor.flow_runner.last[0].id) if not actor.flow_runner.last.is_empty() else ""
				chosen[selected] = int(chosen.get(selected,0))+1
				check(candidates.has(selected), "成立した候補から技を選ぶ")
				if context == "front": check(selected == "sweep", "正面近接には薙ぎを使う")
				if context == "rear": check(candidates.has("kick") and selected in ["kick", "sweep"], "背後近接では蹴りと踏み込み薙ぎから選ぶ")
				if context == "middle": check(candidates.has("charge") and candidates.has("return_charge"), "中距離は複数の突進を候補に保つ")
				if context == "middle" and phase == 2: check(candidates.has("lance"), "第2形態の中距離へ槍を加える")
			selection_results.append({"phase":phase,"context":context,"selected":chosen})
			if context == "middle":
				check(chosen.has("charge") and chosen.has("return_charge"), "中距離で通常・往復を両方選べる")
				if phase == 2:
					fresh(Vector2(700,0), Vector2.ZERO, phase, 0.0)
					actor._cooldown = 0.0
					actor.selection_enabled = true
					actor.flow_runner.index = 2
					actor.flow_runner.tick(DT, {}, actor.flow_adapter)
					check(not actor.flow_runner.last.is_empty() and actor.flow_runner.last[0].id == "lance", "第2形態の大技区間は槍を選べる")
	fresh(Vector2(-180,0),Vector2.ZERO,1,0.0)
	actor._cooldown = 0.0
	actor.cooldowns[&"kick"] = actor.clock+9.0
	check(not actor.technique_ready(&"kick",actor.action_rules.conditions.kick), "蹴りのCDを状況優先で無視しない")
	fresh(Vector2(150,0),Vector2.ZERO,1,0.0)
	actor._cooldown = 0.0
	actor.cooldowns[&"sweep"] = actor.clock+4.0
	check(not actor.technique_ready(&"charge",actor.action_rules.conditions.charge), "近接技のCD中も近距離で突進を連発しない")
	# 自機を攻撃線へ置き直さず、回復・CD・共有スタミナ込みの連続した戦闘を進める。
	for phase in [1,2]:
		for speed in [0.0,250.0,500.0]:
			for seed_value in [7,42,101]:
				fresh(Vector2(600,0),Vector2(0,speed),phase,0.0)
				actor.selection_enabled = true
				actor._cooldown = 0.0
				sim.state.rng.seed = seed_value
				var chosen: Array[String] = []
				var unique := {}
				for frame in int((18.0 if speed == 500.0 else 30.0)/DT):
					var was_running := actor.flow_runner.active
					tick(Vector2(0,speed))
					if not was_running and actor.flow_runner.active and not actor.flow_runner.last.is_empty():
						var id := String(actor.flow_runner.last[0].id)
						chosen.append(id)
						unique[id] = true
				check(chosen.size() >= 2 and hit_count > 0, "自律戦闘で接近・攻撃が脅威になる phase=%d speed=%.0f seed=%d %s" % [phase,speed,seed_value,chosen])
				# 最大速で離れ続ける相手には、射程上成立する突進だけになる場合がある。
				if speed < 500.0: check(unique.size() >= 2, "複数技が成立する自律戦闘で使い分ける " + str(chosen))
				encounter_results.append({"phase":phase,"speed":speed,"seed":seed_value,"chosen":chosen,"hits":hit_count})
	# 共有の実HP減少パルスを専用描画へ接続し、攻撃・予告の座標を保つ。
	fresh(Vector2(600,0),Vector2.ZERO,1,0.0)
	var presentation = actor._presentation
	var position_before := actor.table.pos[actor.body]
	var facing_before := actor.table.facing[actor.body]
	sim.combat.damage_enemy(actor.body,20.0,{"cause":&"ram"})
	presentation._process(0.0)
	check(float(presentation.material.get_shader_parameter("boss_hit_white")) > 0.0, "実HP減少のパルスを白色シェーダーへ渡す")
	var reaction: Dictionary = actor.hit_feedback.sample(actor.body_id)
	check(reaction.offset.length() > 0.0 and reaction.offset.length() <= 2.5 and absf(reaction.angle) <= 0.0035, "揺れは小さい表示オフセット・角度")
	for count in 50: sim.combat.damage_enemy(actor.body,1.0,{"cause":&"ram"})
	check(actor.hit_feedback.sample(actor.body_id).white <= 0.28, "連続命中でも白色・揺れを加算しない")
	check(actor.table.pos[actor.body] == position_before and actor.table.facing[actor.body] == facing_before, "被弾演出で座標・向きを変えない")
	# 世界時間が止まっていても、本番と同じ表示用更新で短時間に戻る。
	sim.bosses.tick_feedback(0.13)
	presentation._process(0.0)
	check(float(presentation.material.get_shader_parameter("boss_hit_white")) == 0.0 and actor.hit_feedback.sample(actor.body_id).offset == Vector2.ZERO, "停止中も被弾表示が終了する")
	actor.table.guard[actor.body] = 1.0
	sim.combat.damage_enemy(actor.body,20.0,{"cause":&"ram"})
	check(actor.hit_feedback.sample(actor.body_id).white == 0.0, "防がれた攻撃では被弾表示を出さない")
	actor.table.guard[actor.body] = 0.0
	sim.combat.damage_enemy(actor.body,0.0,{"cause":&"ram"})
	check(actor.hit_feedback.sample(actor.body_id).white == 0.0, "ダメージ0では被弾表示を出さない")
	var old_material: Material = presentation.material
	fresh(Vector2(600,0),Vector2.ZERO,1,0.0)
	check(actor._presentation.material != old_material, "個体ごとに専用の被弾マテリアルを持つ")
	# 真後ろの遠方へ旋回し、初動でさらに離れず攻撃圏へ戻る。
	fresh(Vector2(-2400,0),Vector2.ZERO,1,0.0)
	actor._cooldown = 0.0
	var initial_distance := actor.table.pos[actor.body].distance_to(sim.state.ship_pos)
	for frame in 40: tick(Vector2.ZERO)
	check(actor.table.pos[actor.body].distance_to(sim.state.ship_pos) <= initial_distance + 1.0, "接近前の旋回で逆走しない")
	# 500で同方向に走り続けても遠方で永久に取り残されない。
	fresh(Vector2(2400,0),Vector2(500,0),1,0.0)
	actor.selection_enabled = true
	actor._cooldown = 0.0
	var began := false
	for frame in 3600:
		tick(Vector2(500,0))
		if actor.mode == &"windup":
			began = true
			check(actor.table.pos[actor.body].distance_to(sim.state.ship_pos) <= actor._reach(actor.technique)+10, "予告した技の実到達範囲へ戻ってから攻撃")
			break
	check(began, "一定速の自機へ接近して攻撃へ復帰する")
	for frame in 500:
		tick(Vector2(500,0))
		if actor.mode == &"recovery": break
	check(hit_count > 0, "遠方へ一定速で離れる自機にも、予告後に届く距離まで接近する")
	print("[monoceros_quality] checks=", checks, " failures=", failed, " trials=", results.size())
	var output := "/tmp/monoceros-combat-quality.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): output = argument.trim_prefix("--out=")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"trajectories":results,"selection":selection_results,"encounters":encounter_results},"\t"))
	session.free()
	get_tree().quit(1 if failed else 0)

func fresh(at: Vector2, velocity: Vector2, phase: int, facing: float) -> void:
	sim.bosses.remove_boss()
	sim.enemies.clear_all()
	sim.projectiles.clear_hostile()
	sim.projectiles.director.configure({"enabled": false})
	sim.field.bodies.clear()
	sim.field.rocks.clear()
	sim.field.moons.clear()
	sim.field.battle_arenas.clear()
	sim.field._build_moon_bands()
	sim.field.refresh_bodies()
	sim.state.phase = RunState.Phase.PLAY
	sim.state.boss_dead = false
	sim.state.lab_mode = true
	sim.state.ship_pos = at
	sim.state.ship_vel = velocity
	# 近似的な定常遅れで開始し、以後は本番の共有照準更新を使う。
	sim.state.enemy_aim = at - velocity * sim.cfg.enemy_aim_lag
	sim.state.ship_hp = 10000.0
	sim.state.ship_invuln = 0.0
	sim.state.controls_locked = false
	sim.ship.invincible = false
	sim.bosses.spawn(load("res://data/bosses/monoceros.tres"),Vector2.ZERO)
	actor = sim.bosses.actor as MonocerosBoss
	actor.phase = phase
	actor._cooldown = 1000.0
	actor.selection_enabled = false
	actor.table.facing[actor.body] = facing
	locks = 0
	launches = 0
	hit_count = 0
	first_hit = {}
	actor.presentation_event.connect(func(e):
		if e.cue == &"aim_locked": locks += 1
		if e.cue == &"attack_started": launches += 1)

func tick(velocity: Vector2) -> void:
	sim.state.ship_pos += velocity * DT
	sim.state.ship_vel = velocity
	sim.state.ship_invuln = maxf(0.0, sim.state.ship_invuln-DT)
	sim.state.time += DT
	sim.state.world_time += DT
	sim.enemies.motion._update_aim(DT)
	sim.bosses.tick_feedback(DT)
	actor.sim_tick(DT,DT)

func trial(id: StringName, at: Vector2, velocity: Vector2, phase: int, facing: float, dodge := false, full_return := false) -> Dictionary:
	fresh(at, velocity, phase, facing)
	actor.start_attack(id)
	if id in [&"charge", &"return_charge", &"lance"]:
		var warning := actor.warning_points()
		check(is_equal_approx(warning[1].distance_to(actor.horn_points()[1]), float(actor.rule().distance)), "予告線が移動後の角先までを示す " + String(id))
	var start := actor.clock
	var dodged := false
	var locked_direction := Vector2.ZERO
	var recovered := false
	for frame in 2400:
		var v := velocity
		if dodge and actor.locked:
			if not dodged:
				locked_direction = actor.direction
				dodged = true
			v = (sim.state.ship_pos-actor.table.pos[actor.body]).normalized() * 500.0 if id == &"sweep" else locked_direction.orthogonal() * 500.0
		# 往復技は各回の予告を評価。以降は別の位置から再捕捉する技として扱う。
		tick(v)
		if actor.mode == &"active" and dodged:
			check(actor.direction.is_equal_approx(locked_direction), "発進後は回避先へ追尾しない " + String(id))
		if actor.mode == &"recovery" or ((actor.mode == &"turnaround" or (id == &"return_charge" and actor._runner.stage == &"brake")) and not full_return):
			recovered = true
			break
	var result := {"id":id,"phase":phase,"at":str(at),"velocity":str(velocity),"dodge":dodge,"hit":hit_count>0,"hits":hit_count,"recovery_seconds":actor.recovery,"recovered":recovered,"lock_count":locks,"launch_count":launches,"elapsed":actor.clock-start,"end_mode":actor.mode,"first_hit":first_hit}
	results.append(result)
	return result
