## 装備の実戦プレビュー。編集画面と実行時エラー検査で同じ発動手順を使う。
extends RefCounted
const PASSIVE_KEYS := ["trait/quickCharge","trait/capacity","trait/critRate","trait/speed","trait/attack","trait/pickup","trait/length","trait/glideDuration","trait/bigSwing","trait/multiShot"]

static func play(session, key: String) -> void:
	var run: RunSimulation = session.run
	var is_trait := key.begins_with("trait/")
	var table: Dictionary = run.loadout.trait_behaviors if is_trait else run.loadout.weapon_behaviors
	var behavior
	for item in table.values():
		if String(item.def.code_id) == key.get_slice("/",1): behavior = item
	if behavior == null: return
	# 数値だけの特性は、効き先の武器・移動・回収を一緒に再生する。
	if key in ["trait/multiShot","trait/fullBurst","trait/duplicator","trait/attack"]:
		run.loadout.grant(&"weapon",&"W01",5)
	if key == "trait/bigSwing": run.loadout.grant(&"weapon",&"W29",5)
	if key == "trait/duplicator":
		behavior.def = behavior.def.duplicate(true)
		behavior.def.params.chance_by_level = [1.0,1.0,1.0,1.0,1.0]
	var targets: Array[int] = []
	for pos in [Vector2(230,0),Vector2(360,30),Vector2(520,-30),Vector2(790,0),Vector2(900,100),Vector2(-180,0)]:
		var row := spawn(session,pos)
		if key in ["weapon/flashSlash","trait/duplicator"]:
			run.enemies.table.hp[row] = 100.0
			run.enemies.table.max_hp[row] = 100.0
		targets.append(row)
	run.state.gauge = run.state.stats.capacity
	run.state.ship_heading = Vector2.RIGHT
	run.combat.rebuild_grid()
	match key:
		"weapon/knockback":
			behavior.def = behavior.def.duplicate(true)
			behavior.def.params.chance_by_level = [1.0,1.0,1.0,1.0,1.0]
			run.combat.damage_enemy(targets[0],100.0,{"cause":&"shot","dir":Vector2.RIGHT})
		"weapon/interceptor":
			behavior.tick(1.0,false)
		"trait/duplicator":
			run.loadout.weapon_behaviors[&"W01"].tick(0.5,false)
			run.projectiles._update_friendly(0.3)
		"weapon/mines":
			behavior.on_end()
			if not behavior.mines.is_empty(): spawn(session,behavior.mines[0].to)
		"weapon/barrier":
			behavior.block_segment(Vector2(100,0),Vector2.ZERO,1.0,100.0)
		"trait/critBeam":
			# 先に槍を発動し、その後の本番ブーストでも移動通知を通す。
			run.loadout.on_critical(Vector2.ZERO)
		"trait/killSonic":
			run.state.tracing = true
			run.loadout.on_launch(true)
			for i in 10: run.loadout.on_kill(&"shot",Vector2(400+i*5,0))
			run.state.tracing = false
		"trait/rampage":
			run.state.tracing = true
			run.loadout.on_launch(true)
			for i in 150: run.loadout.on_kill(&"shot",Vector2(400,0))
			run.loadout.on_end()
			run.state.tracing = false
		"trait/pickup":
			for pos in [Vector2(80,80),Vector2(160,80),Vector2(230,80)]: run.pickups.drop_gem(pos,1.0)
		"trait/vortex":
			run.loadout.on_end()
		"trait/fullBurst":
			run.state.gauge = 0.99
			behavior.tick(0.01,false)
			run.state.gauge = run.state.stats.capacity
			behavior.tick(0.01,false)
	# 全項目で描き始め・移動中・接触・終点・その後の寿命を通す。
	session.perform("route",{"points":[[0,0],[600,0],[900,100]],"draw_seconds":0.3})

static func spawn(session, pos: Vector2) -> int:
	session.perform("spawn",{"type":"drifter","pos":[pos.x,pos.y]})
	return session.selected
