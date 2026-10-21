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
	var em: EnemyManager = lab.run.enemies
	var pm: ProjectileManager = lab.run.projectiles
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
	for row in [a,b,c]: em._telescope(row,0.01)
	check(em.table.charge[a] > 0.0 and d.token(str(em.table.id[a])) > 0, "Budget reserved before first lock-on progress")
	check(em.telescope_aiming(a) and em.telescope_aiming(b) and not em.telescope_aiming(c), "Only two telegraphs with budget two")
	em.table.pos[a] = Vector2(2000,0)
	em._telescope(a,0.01)
	check(not em.telescope_aiming(a) and em.table.charge[a] == 0.0, "Outside existing range hides and cancels aim")
	d.advance(9.1,em)
	check(d.token(str(em.table.id[a])) == 0, "Out-of-range reservation releases")
	var body := FieldManager.Body.new()
	body.pos = Vector2(200,0)
	body.r = 80.0
	lab.run.field.bodies.append(body)
	em._telescope(b,0.01)
	check(not em.telescope_aiming(b), "Occlusion cancels telegraph")
	d.advance(9.2,em)
	check(d.token(str(em.table.id[b])) == 0, "Occlusion reservation releases")
	# 扇の候補絞り込みが48本の従来の円交差結果を保つ。
	lab.run.field.bodies.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 823
	for k in 80:
		var obstacle := FieldManager.Body.new()
		obstacle.pos = Vector2.from_angle(rng.randf_range(-PI,PI)) * rng.randf_range(30.0,1500.0)
		obstacle.r = rng.randf_range(2.0,150.0)
		lab.run.field.bodies.append(obstacle)
	em.table.pos[a] = Vector2.ZERO
	for angle in [0.0,1.2,-2.4]:
		for charge in [0.0,0.7,1.0]:
			em.table.facing[a] = angle
			em.table.charge[a] = charge
			em._cast_telescope(a)
			var rays := em.telescope_rays(a)
			var lens := em.telescope_lens(a)
			var half := em.telescope_half(a)
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
			var full_reach := em.telescope_reach(a,target_angle)
			em._cast_telescope(a,true)
			check(absf(em.telescope_reach(a,target_angle)-full_reach)<0.001,"Two-ray admission equals full 48-ray interpolation")
	lab.run.field.bodies.clear()
	lab.run.state.ship_pos = Vector2.ZERO
	em.table.pos[a] = Vector2(400,0)
	em.table.facing[a] = PI
	var rock := em.spawn(em.def_of(&"meteor"),Vector2(200,0),{"meteor_index":0,"size":20.0})
	check(em._blocking_rock(a,30.0)==rock,"New rock invalidates shared sight cache")
	em.table.pos[rock] = Vector2(200,250)
	check(em._blocking_rock(a,30.0)==-1,"Shared sight cache reads moving rock position")
	em.table.pos[rock] = Vector2(200,0)
	em.table.dead[rock] = 1
	check(em._blocking_rock(a,30.0)==-1,"Destroyed rock immediately excluded")
	lab.queue_free()
	await get_tree().process_frame
	print("[attack_priority] %d checks, %d failures" % [checks,failed])
	get_tree().quit(1 if failed else 0)
