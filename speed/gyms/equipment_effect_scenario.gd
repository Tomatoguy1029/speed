## 装備の実戦プレビュー。編集画面と実行時エラー検査で同じ発動手順を使う。
extends RefCounted
const PASSIVE_KEYS := ["trait/quickCharge","trait/capacity","trait/critRate","trait/speed","trait/attack","trait/pickup","trait/length","trait/glideDuration","trait/bigSwing","trait/multiShot"]

static func play(session, key: String, use_sample_weapon := true, heading := Vector2.RIGHT) -> void:
	var run: RunSimulation = session.run
	var origin := run.state.ship_pos
	var is_trait := key.begins_with("trait/")
	var table: Dictionary = run.loadout.trait_behaviors if is_trait else run.loadout.weapon_behaviors
	var behavior
	for item in table.values():
		if String(item.def.code_id) == key.get_slice("/",1): behavior = item
	if behavior == null: return
	# 数値だけの特性は、効き先の武器・移動・回収を一緒に再生する。
	if use_sample_weapon and key in ["trait/multiShot","trait/fullBurst","trait/duplicator","trait/attack"]:
		run.loadout.grant(&"weapon",&"W01",5)
	if use_sample_weapon and key == "trait/bigSwing": run.loadout.grant(&"weapon",&"W29",5)
	if key == "trait/duplicator":
		behavior.def = behavior.def.duplicate(true)
		behavior.def.params.chance_by_level = [1.0,1.0,1.0,1.0,1.0]
	var targets: Array[int] = []
	for pos in [Vector2(230,0),Vector2(360,30),Vector2(520,-30),Vector2(790,0),Vector2(900,100),Vector2(-180,0)]:
		var row := spawn(session,origin+pos.rotated(heading.angle()))
		if key in ["weapon/flashSlash","trait/duplicator"]:
			run.enemies.table.hp[row] = 100.0
			run.enemies.table.max_hp[row] = 100.0
		targets.append(row)
	if key == "weapon/sonic":
		# 進路上の敵は体当たりで倒れるため、音の円錐へ触れる敵を左右にも置く。
		for i in 8:
			for side in [-1.0,1.0]: spawn(session,origin+Vector2(230.0+i*70.0,80.0*side).rotated(heading.angle()))
	run.state.gauge = run.state.stats.capacity
	run.state.ship_heading = heading
	run.combat.rebuild_grid()
	match key:
		"weapon/knockback":
			behavior.def = behavior.def.duplicate(true)
			behavior.def.params.chance_by_level = [1.0,1.0,1.0,1.0,1.0]
			run.combat.damage_enemy(targets[0],100.0,{"cause":&"shot","dir":heading})
		"weapon/interceptor":
			behavior.tick(1.0,false)
		"trait/duplicator":
			var paired_weapon = null
			if use_sample_weapon: paired_weapon = run.loadout.weapon_behaviors.get(&"W01")
			elif not run.loadout.weapon_behaviors.is_empty(): paired_weapon = run.loadout.weapon_behaviors.values().front()
			if paired_weapon != null:
				paired_weapon.tick(0.5,false)
				run.projectiles._update_friendly(0.3)
		"weapon/mines":
			for offset in [Vector2(990,90),Vector2(1050,160),Vector2(1100,40)]:
				spawn(session,origin+offset.rotated(heading.angle()))
		"weapon/barrier":
			behavior.block_segment(origin+heading*100.0,origin,1.0,100.0)
		"trait/critBeam":
			# 先に槍を発動し、その後の本番ブーストでも移動通知を通す。
			run.loadout.on_critical(origin)
		"trait/killSonic", "trait/rampage":
			# 実際にブーストが始まってから対象特性の発動条件を作る。
			run.frame_events.connect(_seed_trait_conditions.bind(weakref(run),key,{"done":false}))
		"trait/pickup":
			for pos in [Vector2(80,80),Vector2(160,80),Vector2(230,80)]: run.pickups.drop_gem(origin+pos.rotated(heading.angle()),1.0)
		"trait/fullBurst":
			run.state.gauge = 0.99
			behavior.tick(0.01,false)
			run.state.gauge = run.state.stats.capacity
			behavior.tick(0.01,false)
	# 全項目で描き始め・移動中・接触・終点・その後の寿命を通す。
	var points: Array = []
	for point in [Vector2.ZERO,Vector2(600,0),Vector2(900,100)]:
		var world: Vector2 = origin+point.rotated(heading.angle())
		points.append([world.x,world.y])
	session.perform("route",{"points":points,"draw_seconds":0.3})

static func _seed_trait_conditions(_events: Array, reference: WeakRef, key: String, seeded: Dictionary) -> void:
	var run: RunSimulation = reference.get_ref()
	if run == null or seeded.done or not run.state.tracing: return
	seeded.done=true
	var id: StringName = &"T05" if key=="trait/killSonic" else &"T33"
	var behavior = run.loadout.trait_behaviors.get(id)
	if behavior == null: return
	for i in (10 if id==&"T05" else 150):
		run.loadout.kill_position=run.state.ship_pos+run.state.ship_heading*100.0
		behavior.on_kill(&"shot")

static func spawn(session, pos: Vector2) -> int:
	session.perform("spawn",{"type":"drifter","pos":[pos.x,pos.y]})
	return session.selected
