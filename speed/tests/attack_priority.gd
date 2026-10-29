## 攻撃優先度・予算予約・照準の開始条件と取消の対象チェック。
extends Node
var failed := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":932,"empty":true,"stage":4})
	var em: EnemySystem = lab.run.enemies
	var pm: ProjectileSystem = lab.run.projectiles
	var stage := StageDef.new()
	stage.enemy_attack_values = {"telescope":1.0}
	stage.enemy_attack_priorities = {"aquarius":5.0}
	lab.run.state.stage = stage
	check(stage.enemy_attack_priority(&"telescope") == 0.0 and stage.enemy_attack_priority(&"aquarius") == 5.0, "Neutral default and configured priority")
	var d = load("res://scripts/encounters/attack_director.gd").new()
	d.projectiles = pm
	d.formation_mode = true
	d.configure({"enabled":true,"budget":4.0,"jitter":0.0})
	pm.director = d
	var a := em.spawn(em.def_of(&"telescope"), Vector2(400,0))
	var b := em.spawn(em.def_of(&"telescope"), Vector2(400,30))
	var c := em.spawn(em.def_of(&"telescope"), Vector2(400,-30))
	check(d.request("a",["beam"],a,em.table.id[a],1.0,0.0,1.0), "First light attack")
	check(d.request("b",["beam"],b,em.table.id[b],1.0,0.0,1.0), "Second light attack")
	check(not d.request("heavy",["beam"],c,em.table.id[c],1.0,5.0,4.0), "Heavy waits without exceeding capacity")
	check(not d.request("light",["beam"],a,em.table.id[a],1.0,0.0,1.0), "Lower priority cannot refill reserved budget")
	em.table.stone[c] = 1.0
	d.advance(0.1,em)
	check(not d.waiting.has("heavy"), "Incapacitated waiting actor cannot block other attackers")
	em.table.stone[c] = 0.0
	d.request("heavy",["beam"],c,em.table.id[c],1.0,5.0,4.0)
	d.advance(2.0,em)
	check(not d.request("light",["beam"],a,em.table.id[a],1.0,0.0,1.0), "Pending heavy wins even when light requests first")
	check(d.request("heavy",["beam"],c,em.table.id[c],1.0,5.0,4.0) and d.used_cost() == 4.0, "Heavy eventually acquires all four slots")
	d.advance(4.0,em)
	d.waiting.clear()
	check(not d.request("impossible",["beam"],a,em.table.id[a],1.0,100.0,5.0), "Over-budget request remains denied")
	check(d.request("small",["beam"],b,em.table.id[b],1.0,0.0,0.5), "Impossible request cannot block viable fractional attack")
	pm.lab_context = d.token("small")
	var h := pm.fire_wall(Vector2.ZERO,0.0,10.0,2.0,0.0,100.0,1.0,Color.WHITE)
	d.cancel_attack("small",em.table.id[b])
	d.advance(6.0,em)
	check(d.used_cost() == 0.5, "Canceled actor retains its live hazard budget")
	pm.release_hazard(h)
	d.advance(7.0,em)
	check(d.used_cost() == 0.0, "Budget returns after hazard release")
	d.waiting.clear()
	check(d.request("shared",["beam"],a,em.table.id[a],1.0,0.0,1.5), "Shared override starts")
	check(d.request("shared",["beam"],b,em.table.id[b],1.0,0.0,1.5) and d.used_cost() == 1.5, "Shared override charged once")
	d.cancel_attack("shared",em.table.id[a])
	check(d.groups[d.token("shared")].members.has(str(em.table.id[b])), "Cancel preserves shared sibling")
	d.advance(9.0,em)
	d.waiting.clear()
	d.settings.budget = 2.0
	lab.run.field.bodies.clear()
	lab.run.state.ship_pos = Vector2.ZERO
	em._aim = Vector2.ZERO
	for row in [a,b,c]:
		em.table.pos[row] = Vector2(400,0)
		em.table.facing[row] = PI
		em.table.mode[row] = EnemyTable.Mode.MOVE
		em.table.charge[row] = 0.0
	lab.run.combat.rebuild_grid()
	for row in [a,b,c]: em.behavior(&"sniper").step(row,0.01)
	check(em.table.charge[a] > 0.0 and d.token(str(em.table.id[a])) > 0, "Budget reserved before first lock-on progress")
	check(em.behavior(&"sniper").telescope_aiming(a) and em.behavior(&"sniper").telescope_aiming(b) and not em.behavior(&"sniper").telescope_aiming(c), "Only two telegraphs with budget two")
	em.table.pos[a] = Vector2(2000,0)
	em.behavior(&"sniper").step(a,0.01)
	check(not em.behavior(&"sniper").telescope_aiming(a) and em.table.charge[a] == 0.0, "Outside existing range hides and cancels aim")
	d.advance(9.1,em)
	check(d.token(str(em.table.id[a])) == 0, "Out-of-range reservation releases")
	var body := FieldSystem.Body.new()
	body.pos = Vector2(200,0)
	body.r = 80.0
	lab.run.field.bodies.append(body)
	em.behavior(&"sniper").step(b,0.01)
	check(not em.behavior(&"sniper").telescope_aiming(b), "Occlusion cancels telegraph")
	d.advance(9.2,em)
	check(d.token(str(em.table.id[b])) == 0, "Occlusion reservation releases")
	# 扇の候補絞り込みが48本の従来の円交差結果を保つ。
	lab.run.field.bodies.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 823
	for k in 80:
		var obstacle := FieldSystem.Body.new()
		obstacle.pos = Vector2.from_angle(rng.randf_range(-PI,PI)) * rng.randf_range(30.0,1500.0)
		obstacle.r = rng.randf_range(2.0,150.0)
		lab.run.field.bodies.append(obstacle)
	em.table.pos[a] = Vector2.ZERO
	for angle in [0.0,1.2,-2.4]:
		for charge in [0.0,0.7,1.0]:
			em.table.facing[a] = angle
			em.table.charge[a] = charge
			em.behavior(&"sniper")._cast_telescope(a)
			var rays: PackedFloat32Array = em.behavior(&"sniper").telescope_rays(a)
			var lens: Vector2 = em.behavior(&"sniper").telescope_lens(a)
			var half: float = em.behavior(&"sniper").telescope_half(a)
			var same := true
			for n in 48:
				var direction := Vector2.from_angle(angle-half+2.0*half*n/47.0)
				var reach := 1000.0
				for obstacle in lab.run.field.bodies:
					var offset: Vector2 = obstacle.pos-lens
					var along := offset.dot(direction)
					if along < -obstacle.r: continue
					var distance_squared := offset.length_squared()-along*along
					if distance_squared > obstacle.r*obstacle.r: continue
					reach = minf(reach,maxf(0.0,along-sqrt(obstacle.r*obstacle.r-distance_squared)))
				if absf(rays[n]-reach)>0.001: same=false
			check(same,"48 ray blocker equivalence")
			lab.run.state.ship_pos = Vector2.from_angle(angle+half*0.7)*600.0
			var target_angle: float = (lab.run.state.ship_pos-lens).angle()
			var full_reach: float = em.behavior(&"sniper").telescope_reach(a,target_angle)
			em.behavior(&"sniper")._cast_telescope(a,true)
			check(absf(em.behavior(&"sniper").telescope_reach(a,target_angle)-full_reach)<0.001,"Two-ray admission equals full 48-ray interpolation")
	lab.run.field.bodies.clear()
	lab.run.state.ship_pos = Vector2.ZERO
	em.table.pos[a] = Vector2(400,0)
	em.table.facing[a] = PI
	var rock := em.spawn(em.def_of(&"meteor"),Vector2(200,0),{"meteor_index":0,"size":20.0})
	em._behavior_index(&"reticle")
	check(em.behavior(&"reticle")._blocking_rock(a,30.0)==rock,"New rock invalidates shared sight cache")
	em.table.pos[rock] = Vector2(200,250)
	check(em.behavior(&"reticle")._blocking_rock(a,30.0)==-1,"Shared sight cache reads moving rock position")
	em.table.pos[rock] = Vector2(200,0)
	em.table.dead[rock] = 1
	check(em.behavior(&"reticle")._blocking_rock(a,30.0)==-1,"Destroyed rock immediately excluded")
	# からす座の横断・結晶回収は予算0でも、他の攻撃が占有中でも進む。
	em.clear_all()
	pm.clear_hostile()
	var crow_director = load("res://scripts/encounters/attack_director.gd").new()
	crow_director.projectiles = pm
	crow_director.formation_mode = true
	crow_director.configure({"enabled": true, "budget": 0.0, "jitter": 0.0})
	pm.director = crow_director
	var crow := em.spawn(em.def_of(&"crow"), Vector2(0, 100))
	check(not em.behavior(&"crow").admission, "Crow flight bypasses attack admission")
	var crow_before: Vector2 = em.table.pos[crow]
	em.tick(0.1, 0.1)
	check(em.table.pos[crow] != crow_before and crow_director.used_cost() == 0.0
		and crow_director.waiting.is_empty(), "Crow flies at zero attack budget without requesting a slot")
	var pickups: PickupSystem = lab.run.pickups
	var foot := em.table.pos[crow] - Vector2.from_angle(em.table.facing[crow]) * em.table.r[crow] * 0.62
	var gem: int = pickups.drop_gem(foot, 7.0)
	pickups.gem_pos[gem] = foot
	em.gather_pickups(pickups, 0.1)
	check(em.table.carry[crow] >= 7.0 and pickups.gem_alive[gem] == 0,
		"Crow collects experience with zero attack budget")
	crow_director.settings.budget = 1.0
	var blocker := em.spawn(em.def_of(&"telescope"), Vector2(400, 0))
	check(crow_director.request("other", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 1.0),
		"Other attacker occupies the budget")
	crow_before = em.table.pos[crow]
	em.tick(0.1, 0.1)
	check(em.table.pos[crow] != crow_before and crow_director.used_cost() == 1.0,
		"Crow flies without consuming another attacker's slot")
	em.mark_dead(crow)
	em.cleanup()
	crow_director.advance(1.0, em)
	check(crow_director.used_cost() == 1.0 and crow_director.token("other") > 0,
		"Crow removal does not return another attacker's budget")
	crow_director.advance(20.0, em)
	crow_director.advance(21.0, em)
	check(crow_director.used_cost() == 0.0 and crow_director.owners.is_empty(),
		"Budget returns once when its actual attack ends")
	# float valueの反復加算は数ULPだけずれる。予算0と微小な正値は区別する。
	var precision = load("res://scripts/encounters/attack_director.gd").new()
	precision.projectiles = pm
	precision.formation_mode = true
	precision.configure({"enabled": true, "budget": 0.3, "jitter": 0.0})
	for n in 3:
		check(precision.request("decimal_%d" % n, ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 0.1),
			"0.1を3回使って予算0.3に収まる")
	check(absf(precision.used_cost() - 0.3) < 1e-14, "反復加算の予算使用量")
	check(not precision.request("tiny_over", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 1e-14),
		"満杯では微小な正valueも追加しない")
	precision.groups.clear()
	precision.owners.clear()
	precision.waiting.clear()
	precision.configure({"enabled": true, "budget": 0.0, "jitter": 0.0})
	check(precision.request("zero", ["beam"], blocker, em.table.id[blocker], 0.1, 0.0, 0.0)
		and precision.groups.is_empty() and precision.waiting.is_empty(),
		"予算0でもvalue0は枠と待機を作らず通す")
	check(not precision.request("tiny", ["beam"], blocker, em.table.id[blocker], 0.1, 0.0, 1e-18),
		"予算0で微小な正valueを無料扱いしない")
	precision.waiting.clear()
	precision.configure({"enabled": true, "budget": 1e-12, "jitter": 0.0})
	check(precision.request("small_1", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 5e-13)
		and precision.request("small_2", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 5e-13),
		"微小な正予算と正valueはその精度のまま使う")
	check(not precision.request("small_over", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 1e-16),
		"微小な正予算でも満杯後の超過を止める")
	precision.groups.clear()
	precision.owners.clear()
	precision.waiting.clear()
	precision.configure({"enabled": true, "budget": 1.0, "jitter": 0.0})
	check(precision.request("free", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 0.0)
		and precision.used_cost() == 0.0, "正の予算内ではvalue0は残量を消費しない")
	check(precision.request("positive", ["beam"], blocker, em.table.id[blocker], 10.0, 0.0, 1e-16)
		and precision.used_cost() > 0.0, "微小な正valueを0へ丸めない")
	precision.groups.clear()
	precision.owners.clear()
	precision.waiting.clear()
	precision.configure({"enabled": true, "budget": 0.5, "jitter": 0.0})
	check(not precision.request("negative_default", ["beam"], blocker, em.table.id[blocker], 0.1, 0.0, -1.0),
		"負の省略印は既定value1へ戻す")
	precision.waiting.clear()
	precision.configure({"enabled": true, "budget": 1.0, "jitter": 0.0})
	precision.now = 0.2
	check(precision.request("deadline", ["beam"], blocker, em.table.id[blocker], 0.1, 0.0, 0.2),
		"小数秒の期限を持つ攻撃を開始")
	precision.advance(0.3, em)
	check(precision.token("deadline") == 0 and precision.used_cost() == 0.0,
		"0.2+0.1の丸め残りで攻撃枠を保持しない")
	precision.waiting.clear()
	precision.serial = 10000 # 過去の弾に付いた別Directorのtokenと重ねない。
	precision.configure({"enabled": true, "budget": 0.3, "jitter": 0.0})
	var cycles_ok := true
	for cycle in 20:
		precision.now = float(cycle)
		for n in 3:
			cycles_ok = precision.request("repeat_%d_%d" % [cycle, n], ["beam"], blocker,
				em.table.id[blocker], 0.1, 0.0, 0.1) and cycles_ok
		precision.advance(float(cycle) + 0.1, em)
		cycles_ok = precision.used_cost() == 0.0 and cycles_ok
	check(cycles_ok, "小数valueの反復取得・期限切れで予算残差を残さない")
	precision.configure({"enabled": true, "budget": 1.0, "jitter": 0.0})
	precision.now = 30.0
	var owner_id := em.table.id[blocker]
	check(precision.request("existing", ["beam"], blocker, owner_id, 1.0, 0.0, 1.0),
		"予算縮小前に攻撃を開始")
	precision.settings.budget = 0.0
	check(precision.request("existing", ["beam"], blocker, owner_id, 1.0, 0.0, 1.0),
		"予算0へ縮小しても開始済み個体は継続")
	check(not precision.request("existing", ["beam"], blocker, owner_id + 1, 1.0, 0.0, 1.0),
		"予算0では共有枠への新規個体追加を止める")
	lab.queue_free()
	await get_tree().process_frame
	print("[attack_priority] %d checks, %d failures" % [checks,failed])
	get_tree().quit(1 if failed else 0)
