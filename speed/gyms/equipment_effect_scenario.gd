## 装備の実戦プレビュー。編集画面と実行時エラー検査で同じ発動手順を使う。
extends RefCounted
const PASSIVE_KEYS := ["trait/quickCharge","trait/capacity","trait/critRate","trait/speed","trait/attack","trait/pickup","trait/length","trait/glideDuration","trait/bigSwing","trait/multiShot"]

static func play(session, key: String, use_sample_weapon := true) -> void:
	var run: RunSimulation = session.run
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
		var row := spawn(session,pos)
		if key in ["weapon/flashSlash","trait/duplicator"]:
			run.enemies.table.hp[row] = 100.0
			run.enemies.table.max_hp[row] = 100.0
		targets.append(row)
	if key == "weapon/sonic":
		# 進路上の敵は体当たりで倒れるため、音の円錐へ触れる敵を左右にも置く。
		for i in 8:
			for side in [-1.0,1.0]: spawn(session,Vector2(230.0+i*70.0,80.0*side))
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
			var paired_weapon = null
			if use_sample_weapon: paired_weapon = run.loadout.weapon_behaviors.get(&"W01")
			elif not run.loadout.weapon_behaviors.is_empty(): paired_weapon = run.loadout.weapon_behaviors.values().front()
			if paired_weapon != null:
				paired_weapon.tick(0.5,false)
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

## ビジュアル編集専用。敵や撃破条件を追加せず、本番の装備と描画イベントを発火する。
static func preview(session, key: String, heading: Vector2) -> void:
	var run: RunSimulation = session.run
	var is_trait := key.begins_with("trait/")
	var table: Dictionary = run.loadout.trait_behaviors if is_trait else run.loadout.weapon_behaviors
	var behavior = null
	for item in table.values():
		if String(item.def.code_id) == key.get_slice("/", 1): behavior = item
	if behavior == null: return
	var origin: Vector2 = run.state.ship_pos
	run.state.ship_heading = heading
	run.state.gauge = run.state.stats.capacity
	var forward := origin + heading * 260.0
	match key:
		"weapon/forward", "weapon/scatter", "weapon/rear":
			behavior.tick(2.0, false)
		"weapon/interceptor":
			behavior.tick(0.1, false)
			behavior.fire_shot(origin + heading * 60.0, heading.angle(), behavior.atk(),
				{"life": behavior.p("life"), "visual_key": "weapon/interceptor"})
		"weapon/knockback":
			run.state.emit(&"hull_scatter", {"pos": forward})
		"weapon/contactArc":
			run.state.emit(&"bolt", {"segments": PackedVector2Array([origin, forward, forward, forward + heading.rotated(0.6) * 140.0])})
		"weapon/contactWave":
			behavior.on_contact(-1, forward, heading)
		"weapon/barrier":
			behavior.block_segment(origin, forward, 1.0, 100.0)
		"weapon/mines":
			behavior.on_end()
			run.state.emit(&"explode", {"pos": forward, "radius": 65.0, "life": 0.6, "cause": &"mine", "color": Color("#ffb030")})
		"weapon/massTow":
			run.state.emit(&"anchor_capture", {"pos": forward, "to": origin})
			run.state.emit(&"anchor_fire", {"pos": origin, "dir": heading, "radius": 20.0})
		"weapon/flashSlash":
			run.state.emit(&"flash_slash", {"pos": forward, "angle": heading.angle(), "length": 150.0, "width": 3.2, "id": -1})
		"trait/killSonic":
			run.state.emit(&"chain_shock", {"pos": forward, "radius": behavior.val("radius"), "life": 0.4})
		"trait/runUp":
			run.state.emit(&"run_up_hit", {"pos": forward, "dir": heading, "strength": 1.0})
		"trait/critBeam":
			behavior.on_critical(origin)
		"trait/vortex":
			behavior.on_end()
		"trait/fullBurst":
			behavior.tick(0.01, false)
		"trait/rampage":
			behavior.strength = 1.0
			behavior.pop = 1.0
		"trait/duplicator":
			run.state.emit(&"duplicate", {"pos": origin, "directions": [heading, heading.rotated(0.25)]})
		_:
			if is_trait:
				var sample = run.loadout.weapon_behaviors.values().front() if not run.loadout.weapon_behaviors.is_empty() else null
				if sample != null: sample.tick(2.0, false)
	# 距離に応じた演出は実際の本番ルートを描いて発動させる。
	if key not in ["weapon/forward", "weapon/scatter", "weapon/rear", "weapon/interceptor", "trait/rampage"]:
		var p0 := origin
		var p1 := origin + heading * 600.0
		var p2 := p1 + heading.rotated(0.2) * 320.0
		session.perform("route", {"points": [[p0.x, p0.y], [p1.x, p1.y], [p2.x, p2.y]], "draw_seconds": 0.3})

static func spawn(session, pos: Vector2) -> int:
	session.perform("spawn",{"type":"drifter","pos":[pos.x,pos.y]})
	return session.selected
