## 仕掛けの更新と、フィールドから使う共通の入口を確認する。
extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var failed := 0
var mute_checks := false
var moons_finished := false
var rocks_finished := false
var comets_finished := false
func check(ok: bool, message: String) -> void:
	if mute_checks: return
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	if "--cpp-comets" in OS.get_cmdline_user_args():
		await check_cpp_comets()
		mute_checks = false
		check(comets_finished,"彗星の確認本体が最後まで進んだ")
		print("[cpp_comets] %d failures" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-warp" in OS.get_cmdline_user_args():
		await check_cpp_warp()
		print("[cpp_warp] %d failures" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-gravity" in OS.get_cmdline_user_args():
		await check_cpp_gravity()
		print("[cpp_gravity] %d failures" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-rocks" in OS.get_cmdline_user_args():
		await check_cpp_rocks()
		check(rocks_finished,"岩の確認本体が最後まで進んだ")
		print("[cpp_rocks] %d failures" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-moons" in OS.get_cmdline_user_args() or "--cpp-moons-tail" in OS.get_cmdline_user_args() or "--cpp-moons-events" in OS.get_cmdline_user_args():
		mute_checks = "--cpp-moons-tail" in OS.get_cmdline_user_args() or "--cpp-moons-events" in OS.get_cmdline_user_args()
		await check_cpp_moons()
		mute_checks = false
		check(moons_finished,"月の確認本体が最後まで進んだ")
		print("[cpp_moons] %d failures" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-planet" in OS.get_cmdline_user_args():
		await check_cpp_planet()
		print("[cpp_planet] %d failures" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var sim: RunSimulation = session.sim
	var field := sim.field
	check(field.has_method("gimmick"), "仕掛けの種類ごとの処理を取得できる")
	if field.has_method("gimmick"):
		for id in [&"moons", &"meteors", &"comets", &"warp", &"gravity"]:
			check(field.gimmick(id) != null, "%sの仕掛けを登録する" % id)
	sim.state.ship_pos = Vector2(3000, 0)
	sim.state.ship_vel = Vector2.ZERO
	field.add_well(Vector2(3100, 0), 10.0, 500.0, 1000.0)
	sim.state.world_time += 0.1
	field.tick(0.1, 0.1)
	check(sim.state.ship_vel.x > 0.0, "低速の機体を重力の中心へ引く")
	sim.state.glide = true
	sim.state.ship_vel = Vector2.ZERO
	field.tick(0.1, 0.1)
	check(sim.state.ship_vel == Vector2.ZERO, "高速の機体を重力で引かない")
	field.warp_pos = sim.state.ship_pos
	field.warp_gone = sim.state.world_time + 1.0
	check(field.take_warp() and not field.take_warp(), "接触したワープを一度だけ取得する")
	session.free()
	await get_tree().process_frame
	print("[field_gimmicks] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func fixed_step(bridge, intent: Intent = null) -> void:
	if intent==null: intent = Intent.new()
	check(bridge.step(1.0/120.0,bridge.pack_intent(intent),{"logical_size":Vector2(640,480)}).ok,"通常Runnerで地形の固定更新を進める")

func check_cpp_planet() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 100.0
	config.start_radius = 300.0
	config.world_tick_div = 1
	config.draw_step = 1.0
	var stage := RuntimeStage.new()
	stage.index = 83
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_planet"
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder!=null and builder.can_instantiate(),"地形の生成入口を読み込める")
	if builder==null or not builder.can_instantiate(): return
	var built: Error = builder.build(stage,config,output,"惑星と機体の固定入力".sha256_text())
	check(built==OK,"惑星の位置・半径と表示キーを生成する")
	if built!=OK: return
	var index_path := output.path_join("stage_83.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":index_path,"cpp_signature":index.input_sha256,"seed":42},true)
	session.auto_step = false
	for frame in 240:
		if session.bridge!=null or session.cpp_error!=OK: break
		await get_tree().process_frame
	check(session.bridge!=null,"資源準備後に惑星のあるランを開始する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var saved: Dictionary = bridge.checkpoint()
	var field := FieldSystem.new()
	field.cfg = config
	var body := FieldSystem.Body.new()
	body.r = config.planet_radius
	body.is_planet = true
	field.bodies.append(body)
	var context := RunContext.new()
	context.state = RunState.new()
	context.state.stats.max_speed = config.base_max_speed
	context.cfg = config
	context.field = field
	var ship := ShipSystem.new()
	ship.ctx = context
	ship.state = context.state
	ship.cfg = config
	var cases := [[Vector2(-300,126),Vector2(300,126)],[Vector2(50,0),Vector2(300,0)],
		[Vector2.ZERO,Vector2.ZERO],[Vector2(-1000,0),Vector2(1000,0)],[Vector2(-300,130),Vector2(300,130)]]
	for pair in cases:
		var expected = field.first_body_hit(pair[0],pair[1],config.ship_radius)
		var result: Dictionary = bridge.command("dev_field_query",{"action":"hit","from":pair[0],"to":pair[1],"radius":config.ship_radius})
		check(result.ok and ((expected==null and result.value==null) or (expected!=null and result.value!=null and is_equal_approx(result.value.t,expected.t) and result.value.point.is_equal_approx(expected.point))),"接線・内部開始・零長・高速横断・範囲外の問い合わせが現行と一致する")
	var pushed: Dictionary = bridge.command("dev_field_query",{"action":"push","position":Vector2.ZERO,"radius":config.ship_radius})
	check(pushed.ok and pushed.value==field.push_out(Vector2.ZERO,config.ship_radius),"中心からの押し出しも同じ向きと半径を使う")
	var gap: Dictionary = bridge.command("dev_field_query",{"action":"gap","position":Vector2(200,0),"radius":config.ship_radius})
	check(gap.ok and gap.value==field.body_gap(Vector2(200,0),config.ship_radius),"境界からの距離が現行と一致する")
	for point in [Vector2.ZERO,Vector2(config.field_radius,0),Vector2(config.field_radius+100,0)]:
		var force: Dictionary = bridge.command("dev_field_query",{"action":"accel","position":point})
		check(force.ok and force.value==field.boundary_accel(point),"外縁の加速が現行と一致する")
	for values in [[Vector2(115,0),Vector2(-200,0)],[Vector2(115,0),Vector2(200,0)],
		[Vector2.ZERO,Vector2(-200,0)],[Vector2(126,0),Vector2(-200,0)],
		[Vector2(config.field_radius+501,0),Vector2(100,0)]]:
		context.state.ship_pos = values[0]
		context.state.ship_vel = values[1]
		context.state.glide = true
		context.state.events.clear()
		ship._collide_bodies()
		var collided: Dictionary = bridge.command("dev_field_collide",{"position":values[0],"velocity":values[1],"glide":true})
		check(collided.ok and collided.value.ship_pos.is_equal_approx(context.state.ship_pos) and collided.value.ship_vel.is_equal_approx(context.state.ship_vel) and collided.value.glide==context.state.glide,"移動後の押し出し・内向き反射・接線・中心開始・外周反射が現行と一致する")
	var before := Vector2(-300,0)
	var velocity := Vector2(100000,0)
	context.state.ship_pos = before
	context.state.ship_vel = velocity
	context.state.glide = false
	ship._step(1.0/120.0,field.boundary_accel(before))
	ship._collide_bodies()
	check(bridge.command("dev_ship_motion",{"position":before,"velocity":velocity}).ok,"高速移動の初期値を設定する")
	fixed_step(bridge)
	var moved: Dictionary = bridge.read_frame().value.ui.ship
	check(moved.ship_pos.is_equal_approx(context.state.ship_pos) and moved.ship_vel.is_equal_approx(context.state.ship_vel),"高速横断でも機体の現行の判定方式を変えない")
	check(bridge.restore(saved.value).ok,"地形も同じ保持点へ戻す")
	var draw := DrawSystem.new()
	draw.ctx = context
	draw.cfg = config
	draw.state = context.state
	context.state.draw_points = PackedVector2Array([before])
	context.state.draw_length = 0.0
	context.state.draw_limit = 1000.0
	draw._extend(Vector2(300,0))
	var intent := Intent.new()
	intent.press = true
	intent.has_cursor = true
	intent.touch = true
	intent.pen = before
	fixed_step(bridge,intent)
	intent.press = false
	intent.pen = Vector2(300,0)
	fixed_step(bridge,intent)
	var traced: Dictionary = bridge.read_frame().value.ui.draw
	check(traced.draw_blocked and traced.trace_path[-1].is_equal_approx(context.state.draw_points[-1]),"惑星の直前で描線を止めて同じ終端を使う")
	check(bridge.restore(saved.value).ok,"描線確認後も惑星の保持点へ戻せる")
	var render: Dictionary = bridge.read_render(Rect2(-2000,-2000,4000,4000)).value
	var visual_id := 0
	for entry: Dictionary in session.cpp_resources.visuals:
		if entry.role==9: visual_id = entry.id
	var displayed := false
	for batch: Dictionary in render.batches:
		if batch.visual_id==visual_id:
			displayed = batch.layer==2 and batch.ids.size()==1 and is_equal_approx(batch.transforms[0],body.r) and Vector2(batch.transforms[4],batch.transforms[5])==body.pos
	check(displayed,"惑星の表示が判定と同じ位置・半径を使い、敵・結晶より奥へ出る")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(presentation.frame_view.batches.has(visual_id),"通常の表示へ惑星の資源キーを届ける")
	await get_tree().process_frame
	bridge.release_checkpoint(saved.value)
	session.free()
	ship.dispose()
	draw.dispose()
	context.field = null

func moon_snapshot(bridge) -> Dictionary:
	var result: Dictionary = bridge.command("dev_field_query",{"action":"snapshot"})
	check(result.ok,"月の値状態を読み取る")
	return result.value if result.ok else {}

func source_moon_field(config: GameConfig, snapshot: Dictionary) -> FieldSystem:
	var field := FieldSystem.new()
	field.cfg = config
	field._body_origin = Vector2.ONE*(-config.field_radius-FieldSystem.BODY_CELL_SIZE)
	field._body_width = ceili((config.field_radius*2.0+FieldSystem.BODY_CELL_SIZE*2.0)/FieldSystem.BODY_CELL_SIZE)
	field._body_cells.resize(field._body_width*field._body_width)
	for i in field._body_cells.size(): field._body_cells[i] = []
	for row: Dictionary in snapshot.bodies:
		var body := FieldSystem.Body.new()
		body.pos = row.position
		body.r = row.radius
		body.is_planet = not row.moon
		body.orbit = row.orbit
		body.a0 = row.a0
		body.dir = row.direction
		field.bodies.append(body)
		if row.moon: field.moons.append(body)
	field.body_speed_max = snapshot.body_speed_max
	field._build_moon_bands()
	field._update_body_grid()
	return field

func check_cpp_moons() -> void:
	var events_only := "--cpp-moons-events" in OS.get_cmdline_user_args()
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 100.0
	config.moon_count = 2
	config.moon_orbit_speed = 0.4
	config.start_radius = 300.0
	config.world_tick_div = 2
	var stage := RuntimeStage.new()
	stage.index = 84
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_moons"
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder!=null and builder.can_instantiate(),"月の生成入口を読み込める")
	if builder==null or not builder.can_instantiate(): return
	var built: Error = builder.build(stage,config,output,"月の世界時計と敵・弾の衝突".sha256_text())
	check(built==OK,"月の数・公転・大きさの定義と表示キーを生成する")
	if built!=OK: return
	var index_path := output.path_join("stage_84.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":index_path,"cpp_signature":index.input_sha256,"seed":43},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK:
		await get_tree().process_frame
	check(session.bridge!=null,"月の表示資源を準備してから開始する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var initial := moon_snapshot(bridge)
	check(initial.bodies.size()==3,"惑星に続いて設定した数の月を初期化する")
	if initial.bodies.size()!=3:
		session.free()
		return
	var field := source_moon_field(config,initial)
	var context := RunContext.new()
	context.cfg = config
	context.state = RunState.new()
	context.field = field
	field.ctx = context
	context.enemies = EnemySystem.new()
	var table: EnemyTable = context.enemies.table
	var update = load("res://scripts/gimmicks/moons.gd").new()
	update.setup(context)
	for moon: FieldSystem.Body in field.moons:
		check(moon.orbit>=1500.0 and moon.orbit<=config.field_radius-600.0 and moon.r>=110.0 and moon.r<=180.0 and absf(moon.dir)==1.0,"月の初期値は現行と同じ範囲を使う")
	var moon: FieldSystem.Body = field.moons[0]
	var start := moon.pos-Vector2(moon.r+80.0,0.0)
	check(bridge.command("dev_ship_motion",{"position":moon.pos+Vector2(500,-500),"velocity":Vector2.ZERO}).ok,"月の近くを通常の表示範囲にする")
	var spawned: Dictionary = bridge.command("dev_spawn",{"definition_id":"drifter","position":start})
	check(spawned.ok,"月へ向かう敵を出す")
	if not spawned.ok:
		session.free()
		return
	var id: int = spawned.value
	check(bridge._core.set_enemy_motion(id,{"knock_t":1.0,"vel":Vector2(60000,0)}),"敵の外力による横断を設定する")
	var enemy_before: Dictionary = bridge._core.enemies_snapshot()[0]
	var events: Array = []
	bridge.subscribe("月の衝突確認",func(frame: Dictionary):
		for event: Dictionary in frame.events: events.append(event.duplicate(true))
		return true)
	for pool in [0,1]:
		var offset := Vector2(0,moon.r*0.6*(1.0 if pool==0 else -1.0))
		check(bridge.command("dev_emit_attack",{"pool":pool,"position":start+offset,"velocity":Vector2(60000,0),"radius":5.0,"life":2.0,"contact_definition":1}).ok,"月を横断する味方弾と敵弾を作る")
	var saved: Dictionary = bridge.checkpoint()
	check(saved.ok,"月と横断中の敵・弾を保持する")
	for i in 2: fixed_step(bridge)
	var first := moon_snapshot(bridge)
	check(first.world_time>0.0,"通常Runnerが月の世界時計を進める")
	context.state.world_time = first.world_time
	update.update()
	for i in field.bodies.size():
		check(first.bodies[i].position.is_equal_approx(field.bodies[i].pos),"月の位置を現在の解析式で求める")
	table.pos = PackedVector2Array([start+Vector2(60000,0)*exp(-2.0*first.world_time)*first.world_time])
	table.vel = PackedVector2Array([Vector2(60000,0)*exp(-2.0*first.world_time)])
	table.r = PackedFloat64Array([enemy_before.radius])
	table.shove_time = PackedFloat64Array([0.0])
	table.shove_vel = PackedVector2Array([Vector2.ZERO])
	field.collide_enemy(0,start)
	var first_enemies: Array = bridge._core.enemies_snapshot()
	mute_checks = events_only
	check(first_enemies[0].id==id and Vector2(first_enemies[0].pos[0],first_enemies[0].pos[1]).is_equal_approx(table.pos[0]) and Vector2(first_enemies[0].vel[0],first_enemies[0].vel[1]).is_equal_approx(table.vel[0]),"動いた月への敵の掃引衝突・接面への移動・内向き速度の除去が現行と一致する")
	check(bridge._core.projectiles_snapshot().is_empty() and bridge._core.hostiles_snapshot().is_empty(),"月に当たった味方弾と敵弾を同じ更新で終了する")
	mute_checks = false
	var retired := 0
	var rings := 0
	for event: Dictionary in events:
		if event.type==&"attack_retired":
			retired += 1
			var at: Vector2 = event.payload.pos
			check(absf(at.distance_to(field.moons[0].pos)-(field.moons[0].r+5.0))<0.1,"弾の終了位置は移動後の月の表面を使う")
		if event.type==&"ring": rings += 1
	check(retired==2 and rings==1,"両方の弾を一度ずつ終了し、味方弾の接触演出を届ける（終了%d・演出%d）" % [retired,rings])
	if events_only:
		bridge.release_checkpoint(saved.value)
		update.dispose()
		field.ctx = null
		context.field = null
		context.enemies.dispose()
		context.enemies = null
		session.free()
		moons_finished = true
		return
	check(bridge.restore(saved.value).ok,"月・乱数・敵・弾を保持点へ戻す")
	events.clear()
	for i in 2: fixed_step(bridge)
	check(moon_snapshot(bridge)==first and bridge._core.enemies_snapshot()==first_enemies and bridge._core.projectiles_snapshot().is_empty() and bridge._core.hostiles_snapshot().is_empty(),"復帰後も同じ月の移動と敵・弾の衝突になる")
	var stopped := moon_snapshot(bridge)
	check(bridge.command("pause",{"paused":true}).ok,"月のあるランを停止する")
	fixed_step(bridge)
	check(moon_snapshot(bridge)==stopped,"停止中は世界時計と月が進まない")
	check(bridge.command("pause",{"paused":false}).ok,"月のあるランを再開する")
	var intent := Intent.new()
	intent.press = true
	intent.has_cursor = true
	intent.touch = true
	intent.pen = bridge.read_frame().value.ui.ship.ship_pos
	fixed_step(bridge,intent)
	intent.press = false
	fixed_step(bridge,intent)
	var slow := moon_snapshot(bridge)
	check(slow.world_time>stopped.world_time and slow.world_time-stopped.world_time<2.0/120.0,"描線中の月は減速した世界時計を使う")
	context.state.world_time = slow.world_time
	update.update()
	check(slow.bodies[1].position.is_equal_approx(field.moons[0].pos),"描線中も月の解析式と一致する")
	var render: Dictionary = bridge.read_render(Rect2(-config.field_radius*Vector2.ONE,config.field_radius*2.0*Vector2.ONE)).value
	var visual := 0
	for entry: Dictionary in session.cpp_resources.visuals:
		if entry.role==10: visual = entry.id
	var shown := false
	for batch: Dictionary in render.batches:
		if batch.visual_id!=visual: continue
		shown = batch.layer==2 and batch.ids.size()==config.moon_count
		for i in batch.ids.size():
			var body: Dictionary = slow.bodies[i+1]
			check(Vector2(batch.transforms[i*6+4],batch.transforms[i*6+5]).is_equal_approx(body.position) and is_equal_approx(batch.transforms[i*6],body.radius),"月の表示と当たり判定が同じ位置・半径を使う")
	check(shown,"同じ画像の月をまとめて敵より奥へ表示する")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(presentation.frame_view.batches.has(visual),"月を通常の表示へ渡す")
	await get_tree().process_frame
	bridge.release_checkpoint(saved.value)
	update.dispose()
	field.ctx = null
	context.field = null
	context.enemies.dispose()
	context.enemies = null
	session.free()
	moons_finished = true

func rock_snapshot(bridge) -> Array:
	var result: Dictionary = bridge.command("dev_field_query",{"action":"rocks"})
	check(result.ok,"岩の配置と敵IDを読み取る")
	return result.value if result.ok else []

func check_cpp_rocks() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.planet_radius = 100.0
	config.moon_count = 0
	config.meteor_count = 1
	config.iron_count = 1
	config.saw_count = 1
	config.start_radius = 1500.0
	config.world_tick_div = 1
	config.meteor_coin_chance = 1.0
	config.meteor_heal_chance = 1.0
	config.meteor_magnet_chance = 1.0
	var stage := RuntimeStage.new()
	stage.index = 85
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_rocks"
	var builder = load("res://tools/content/build_run_content.gd")
	check(builder!=null and builder.can_instantiate(),"岩の生成入口を読み込める")
	if builder==null or not builder.can_instantiate(): return
	var built: Error = builder.build(stage,config,output,"岩の配置と生成・退場・破壊".sha256_text())
	check(built==OK,"地形の敵定義・配置の値・隕石の画像シートを生成する")
	if built!=OK: return
	var index_path := output.path_join("stage_85.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":index_path,"cpp_signature":index.input_sha256,"seed":44},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"隕石・鉄屑・鋸と破片の資源を準備して開始する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var generated := rock_snapshot(bridge)
	var kinds := {}
	for rock: Dictionary in generated:
		kinds[rock.kind] = true
		check(rock.position.length()>=config.planet_radius+200.0 and rock.position.length()<=config.field_radius-100.0,"初期配置を惑星と外縁から離す")
	check(kinds.has(1) and kinds.has(2) and kinds.has(3),"設定した漂流隕石・鉄屑・丸鋸を配置する")
	var ids: Array[int] = []
	for entry in [[0,Vector2(-1500,0),40.0,false],[2,Vector2(-1500,250),35.0,false],
		[3,Vector2(-1500,-250),30.0,false],[0,Vector2(-1500,700),40.0,true]]:
		var added: Dictionary = bridge.command("dev_add_rock",{"kind":entry[0],"position":entry[1],"size":entry[2],"manual":entry[3]})
		check(added.ok,"固定の岩を配置する")
		if not added.ok:
			session.free()
			return
		ids.append(int(added.value))
	var size := 60.0 if (ids[0]-1)%2==0 else 40.0
	var collision_radius := size*config.character_scale
	check(bridge.command("dev_ship_motion",{"position":Vector2(-1500-collision_radius-config.ship_radius+0.5,0),"velocity":Vector2(30,0)}).ok,"生成直後に岩へ触れる機体を置く")
	fixed_step(bridge)
	var rocks := rock_snapshot(bridge)
	var first_ids: Array[int] = []
	for id in ids:
		var rock: Dictionary = rocks[id-1]
		check(rock.enemy_id>0 and not rock.destroyed,"画面近傍の配置と敵の論理IDを結ぶ")
		first_ids.append(int(rock.enemy_id))
	var ship: Dictionary = bridge.read_frame().value.ui.ship
	check(ship.ship_pos.x<=-1500-collision_radius-config.ship_radius and ship.ship_vel.x<=0.0,"生成した同じ更新で低速接触を反射し、岩を通り抜けない")
	var render: Dictionary = bridge.read_render(Rect2(-2300,-1000,1600,2000)).value
	for id in first_ids:
		var shown := false
		for batch: Dictionary in render.batches:
			if batch.ids.has(id): shown = true
		check(shown,"隕石・鉄屑・丸鋸・手動配置を表示する")
	check(bridge.command("dev_stream_rocks",{"center":Vector2(8000,8000),"half":Vector2(100,100),"dt":0.2}).ok,"表示範囲を岩から離す")
	rocks = rock_snapshot(bridge)
	for i in 3: check(rocks[ids[i]-1].enemy_id==0 and not rocks[ids[i]-1].destroyed,"画面外の敵行だけを退場させて配置を残す")
	check(rocks[ids[3]-1].enemy_id==first_ids[3],"手動配置は画面外でも同じ敵IDで残す")
	check(bridge.command("dev_stream_rocks",{"center":Vector2(-1500,0),"half":Vector2(700,700),"dt":0.2}).ok,"岩を表示範囲へ戻す")
	rocks = rock_snapshot(bridge)
	for i in 3: check(rocks[ids[i]-1].enemy_id>first_ids[i],"再入場は新しい敵IDを同じ岩に結ぶ")
	var before: Dictionary = bridge._core.pickups_snapshot()
	check(before.gems.is_empty() and before.coins.is_empty() and before.capsules.is_empty(),"画面外への退場はドロップを出さない")
	var target: int = rocks[ids[0]-1].enemy_id
	var killed: Dictionary = bridge.command("dev_kill",{"entity_id":target,"cause":"ram"})
	check(killed.ok and killed.value.killed,"隕石の撃破を共通の撃破・報酬へ通す")
	var drops: Dictionary = bridge._core.pickups_snapshot()
	check(not drops.gems.is_empty() and drops.coins.size()>=1 and drops.coins.size()<=3 and drops.capsules.size()==2,"隕石の固定結晶・固有の部品数・回復/マグネットを出す")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(not presentation.frame_view._meteor_shards.is_empty(),"隕石の撃破から既存の画像片を表示する")
	fixed_step(bridge)
	check(bridge.command("dev_stream_rocks",{"center":Vector2(8000,8000),"half":Vector2(100,100),"dt":0.2}).ok,"撃破後にも画面外を処理する")
	check(bridge.command("dev_stream_rocks",{"center":Vector2(-1500,0),"half":Vector2(700,700),"dt":0.2}).ok,"撃破後に表示範囲を戻す")
	rocks = rock_snapshot(bridge)
	check(rocks[ids[0]-1].destroyed and rocks[ids[0]-1].enemy_id==0,"撃破後は画面を出入りしても復活させない")
	var saw_id: int = rocks[ids[2]-1].enemy_id
	check(saw_id>0,"鋸の接触対象を保持する")
	var rejected: Dictionary = bridge.command("dev_damage",{"entity_id":saw_id,"amount":1000000.0,"cause":"shot"})
	check(rejected.ok and rejected.value.reason=="damage_gate","丸鋸は通常の攻撃で壊さない")
	var saw: Dictionary
	for enemy: Dictionary in bridge._core.enemies_snapshot():
		if enemy.id==saw_id: saw = enemy
	var at := Vector2(saw.pos[0],saw.pos[1])
	var from := at-Vector2(saw.radius+config.ship_radius+2.0,0)
	check(bridge.command("dev_ship_motion",{"position":at+Vector2(saw.radius+config.ship_radius+2.0,0),"velocity":Vector2(800,0)}).ok,"鋸を横断する機体を設定する")
	bridge._core.collide_ship(from,config.ship_radius)
	var shots: Array = bridge._core.projectiles_snapshot()
	var launched := false
	for shot: Dictionary in shots:
		if shot.type==&"saw": launched = shot.kind==2 and shot.pierce and shot.vel.x>=config.saw_speed and is_equal_approx(shot.radius,saw.radius)
	check(launched,"接触方向へ同じ半径の貫通する鋸を投射する")
	check(bridge.command("dev_stream_rocks",{"center":Vector2(-1500,0),"half":Vector2(700,700),"dt":0.2}).ok,"鋸接触後の配置を同期する")
	rocks = rock_snapshot(bridge)
	check(rocks[ids[2]-1].destroyed and rocks[ids[2]-1].enemy_id==0,"投射した鋸の配置を復活させない")
	var held_drops: Dictionary = bridge._core.pickups_snapshot()
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"岩・敵との参照・破壊状態とドロップを保持する")
	check(bridge.command("dev_stream_rocks",{"center":Vector2(8000,8000),"half":Vector2(100,100),"dt":0.2}).ok,"保持点のあとに表示範囲を変える")
	check(bridge.restore(held.value).ok and rock_snapshot(bridge)==rocks and bridge._core.pickups_snapshot()==held_drops,"保持点から岩の配置・敵ID・破壊状態へ戻す")
	bridge.release_checkpoint(held.value)
	await get_tree().process_frame
	session.free()
	rocks_finished = true

func gravity_enemy(core, id: int) -> Dictionary:
	for enemy: Dictionary in core.enemies_snapshot():
		if enemy.id==id: return enemy
	return {}

func check_cpp_gravity() -> void:
	mute_checks = "--cpp-gravity-tail" in OS.get_cmdline_user_args()
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 1200.0
	cfg.planet_radius = 0.0
	cfg.world_tick_div = 1
	cfg.gravity_life = 0.5
	cfg.gravity_radius = 500.0
	cfg.gravity_pull = 1000.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 57
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter","hydra_bite"])
	var output := "res://.content/dev/run_gravity"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"重力の吸引と世界時計".sha256_text())
	check(built==OK,"重力の編集値を生成する")
	if built!=OK: return
	var path := output.path_join("stage_57.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":574},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"重力のあるランと通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	fixed_step(bridge)
	var target: Vector2 = core.ship_snapshot().ship_pos
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	core.set_motion_context(target,target,Vector2(640,360))
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"seed":574,"empty":true,"field":{"terrain":false,"rocks":false,"gimmicks":false},"config":{"start_radius":1200.0,"planet_radius":0.0,"gravity_life":0.5,"gravity_radius":500.0,"gravity_pull":1000.0}})
	var run: RunSimulation = lab.run
	run.state.ship_pos = target
	run.state.ship_vel = Vector2.ZERO
	run.state.world_time = core.inspect().world_time
	var center := target+Vector2(100,0)
	var point := target+Vector2(0,80)
	var row := run.enemies.spawn(run.enemies.def_of(&"drifter"),point)
	var id: int = core.spawn_enemy(&"drifter",point,{"guard":100.0})
	var boss_row := run.enemies.spawn(run.enemies.def_of(&"drifter"),point)
	run.enemies.table.is_boss[boss_row] = 1
	var boss: int = core.spawn_enemy(&"drifter",point,{"is_boss":true})
	var part_row := run.enemies.spawn_part(boss_row,run.enemies.def_of(&"hydra_bite"),point)
	var part: int = bridge.command("dev_spawn_part",{"parent_id":boss,"definition_id":"hydra_bite","position":point}).value
	for enemy_id in [id,boss,part]: core.set_enemy_motion(enemy_id,{"held":true})
	bridge.command("dev_add_rock",{"position":point,"kind":0,"manual":true})
	bridge.command("dev_stream_rocks",{"center":target,"half":Vector2(640,360),"dt":0.3})
	var rock: int = bridge.command("dev_field_query",{"action":"rocks"}).value[0].enemy_id
	var rock_row := run.enemies.spawn(run.enemies.def_of(&"meteor"),point,{"meteor_index":0})
	var shot := run.projectiles._add_hostile(point,Vector2(0,20),20.0,7.0,4.0,1.0,0.0,0.0,RunIds.HostileKind.Bullet)
	core.spawn_hostile({"kind":0,"pos":point,"vel":Vector2(0,20),"speed":20.0,"r":7.0,"life":4.0,"dmg":1.0,"slow":0.0,"turn":0.0})
	run.field.add_well(center,0.5,500.0,1000.0)
	check(bridge.command("dev_add_well",{"position":center,"life":0.5,"radius":500.0,"pull":1000.0}).ok,"同じ位置と世界寿命の重力を生成する")
	core.step(0.1)
	run.state.world_time += 0.1
	run.field.gimmick(&"gravity").tick(0.1,0.1)
	bridge.command("dev_tick_gravity",{"dt":0.1})
	check(core.ship_snapshot().ship_vel.is_equal_approx(run.state.ship_vel) and run.state.ship_vel.x>0.0,"低速の機体を現行と同じ強さで中心へ引く")
	var actual := gravity_enemy(core,id)
	check(Vector2(actual.vel[0],actual.vel[1]).is_equal_approx(run.enemies.table.vel[row]) and core.hostiles_snapshot()[0].vel.is_equal_approx(run.projectiles.hostile_vel[shot]),"普通の敵と敵弾を同じ吸引で動かす")
	for enemy_id in [boss,part,rock]:
		actual = gravity_enemy(core,enemy_id)
		check(Vector2(actual.vel[0],actual.vel[1])==Vector2.ZERO,"ボス・部位・岩を重力で引かない")
	var velocity: Vector2 = core.ship_snapshot().ship_vel
	bridge.command("dev_tick_gravity",{"dt":0.0})
	check(core.ship_snapshot().ship_vel==velocity,"世界dtが0なら吸引を重ねない")
	for fast in [true,false]:
		var speed := Vector2.ZERO if fast else Vector2(100000,0)
		run.state.glide = fast
		run.state.ship_vel = speed
		bridge.command("dev_ship_motion",{"position":target,"velocity":speed,"glide":fast})
		core.step(0.1)
		run.state.world_time += 0.1
		run.field.gimmick(&"gravity").tick(0.1,0.1)
		bridge.command("dev_tick_gravity",{"dt":0.1})
		check(core.ship_snapshot().ship_vel==speed and run.state.ship_vel==speed,"滑空中と閾値以上の機体を重力で引かない")
	var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(700,400),Vector2(1400,800))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	check(frame.gravity.wells.size()==5 and is_equal_approx(frame.gravity.time,run.state.world_time) and presentation.frame_view.apply_frame(frame),"同じ世界時計で縮む渦と三本の輪を通常画面へ表示する")
	await get_tree().process_frame
	var pending: Dictionary = bridge.checkpoint()
	var clock: float = core.inspect().world_time
	bridge.command("pause",{"paused":true})
	fixed_step(bridge)
	check(core.inspect().world_time==clock and core.ship_snapshot().ship_vel==Vector2(100000,0),"停止中は重力の期限と吸引を進めない")
	bridge.command("pause",{"paused":false})
	fixed_step(bridge)
	run.state.world_time += 1.0/120.0
	run.field.gimmick(&"gravity").tick(1.0/120.0,1.0/120.0)
	actual = gravity_enemy(core,id)
	check(Vector2(actual.vel[0],actual.vel[1]).is_equal_approx(run.enemies.table.vel[row]),"再開後は通常Runnerの世界更新で吸引を一度だけ進める")
	var future: Array = core.enemies_snapshot()
	check(bridge.restore(pending.value).ok,"重力の位置・生成時刻・寿命を値から復帰する")
	fixed_step(bridge)
	check(core.enemies_snapshot()==future,"復帰後の世界更新でも吸引を重ねず同じ結果へ進む")
	core.step(0.3)
	bridge.command("dev_tick_gravity",{"dt":0.3})
	check(bridge.command("dev_field_query",{"action":"wells"}).value.is_empty(),"世界寿命で重力が消滅し定期発生を始めない")
	frame = bridge.read_render(Rect2(target-Vector2(700,400),Vector2(1400,800))).value
	check(frame.gravity.wells.is_empty() and presentation.frame_view.apply_frame(frame),"寿命終了後の渦を通常表示から消す")
	core.set_motion_context(target,target,Vector2(640,360))
	# 配置条件は現行と同じにし、乱数列は設計17.1のPCG32を使う。
	mute_checks = false
	var first := pcg_step(int(core.inspect().rng_state))
	var second := pcg_step(first[0])
	check(bridge.command("dev_spawn_well",{}).ok,"明示したランダム配置の重力を生成する")
	var well: Dictionary = bridge.command("dev_field_query",{"action":"wells"}).value[0]
	var expected := target+Vector2((-0.7+1.4*float(first[1])/4294967296.0)*640.0,(-0.7+1.4*float(second[1])/4294967296.0)*360.0)
	check(well.position==expected and well.life==0.5 and well.radius==500.0 and well.pull==1000.0 and int(core.inspect().rng_state)==second[0],"配置の距離条件・編集値とPCG32の二つの出力を保持する")
	var count: int = bridge.command("dev_field_query",{"action":"wells"}).value.size()
	for cause in ["wave","bullet"]:
		var now: float = core.inspect().world_time
		check(bridge.command("dev_add_rock",{"position":target+Vector2(250,250),"kind":4,"manual":true,"born":now,"gone":now+10.0}).ok,"寿命を持つ通常の彗星を生成する")
		bridge.command("dev_stream_rocks",{"center":target,"half":Vector2(640,360),"dt":0.3})
		var rocks: Array = bridge.command("dev_field_query",{"action":"rocks"}).value
		var comet: int = rocks.back().enemy_id
		var killed: Dictionary = bridge.command("dev_kill",{"entity_id":comet,"cause":cause})
		check(comet>0 and killed.ok and killed.value.killed,"通常の彗星を共通撃破へ渡す")
		if cause=="bullet": count += 1
		check(bridge.command("dev_field_query",{"action":"wells"}).value.size()==count,"敵の波の破壊では増やさず機体側の彗星撃破で重力を一つ残す")
	bridge.release_checkpoint(pending.value)
	lab.free()
	session.free()

func warp_attacks(bridge, core, at: Vector2) -> void:
	check(core.spawn_hostile({"kind":0,"pos":at,"vel":Vector2.ZERO,"speed":0.0,"r":2.0,"life":10.0,"dmg":1.0,"slow":0.0,"turn":0.0})>=0,"突入と終了の直前に敵弾を残す")
	check(bridge.command("dev_fire_wall",{"position":at,"angle":0.0,"length":50.0,"width":10.0,"delay":0.0,"active":10.0,"damage":1.0}).ok,"突入と終了の直前に敵の帯を残す")

func check_cpp_warp() -> void:
	var phase_only := "--cpp-warp-card-phase" in OS.get_cmdline_user_args()
	mute_checks = "--cpp-warp-card" in OS.get_cmdline_user_args() or phase_only
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 1200.0
	cfg.planet_radius = 0.0
	cfg.world_tick_div = 1
	cfg.levelup_bonus_chance = 0.0
	cfg.levelup_bonus_more = 0.0
	cfg.levelup_bonus_last = 0.0
	cfg.bonus_time = 0.05
	cfg.bonus_pop = 6.0
	cfg.density_mult = 1.0
	cfg.spawn_refill_time = 0.01
	cfg.warp_radius = 30.0
	cfg.warp_life = 0.1
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 83
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter","pulser","lynx","hydra_bite"])
	stage.enemy_tuning = {"pulser":{"speed":0.0}}
	var phase := PhaseDef.new()
	phase.id = &"warp_test"
	phase.pop_from = 4.0
	phase.pop_to = 4.0
	phase.rate = 120.0
	phase.xp_bonus = 1.0
	phase.attack_budget = 0
	phase.mix = {&"drifter":2.0,&"pulser":1.0,&"lynx":1.0}
	stage.phases = [phase]
	for pair in [[&"drifter",2.0],[&"pulser",1.0],[&"lynx",1.0]]:
		var curve := SpawnCurve.new()
		curve.type = pair[0]
		curve.points = PackedVector2Array([Vector2(0,pair[1]),Vector2(10,pair[1])])
		stage.zako_curves.append(curve)
	var output := "res://.content/dev/run_warp"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"ワープとボーナスの補充".sha256_text())
	check(built==OK,"ワープと既存配分の時間帯・曲線を生成する")
	if built!=OK: return
	var path := output.path_join("stage_83.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":835},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"ワープのあるランと通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	fixed_step(bridge)
	var target: Vector2 = core.ship_snapshot().ship_pos
	bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	core.set_motion_context(target,target,Vector2(640,360))
	var position := target-Vector2(300,0)
	var ordinary: int = core.spawn_enemy(&"drifter",position,{})
	var boss: int = core.spawn_enemy(&"drifter",position,{"is_boss":true})
	var child: int = bridge.command("dev_spawn_part",{"parent_id":boss,"definition_id":"hydra_bite","position":position+Vector2(10,0)}).value
	for entity in [ordinary,boss,child]: core.set_enemy_motion(entity,{"held":true})
	bridge.command("dev_add_rock",{"position":position+Vector2(0,200),"kind":0,"manual":true})
	bridge.command("dev_stream_rocks",{"center":target,"half":Vector2(640,360),"dt":0.3})
	var rock: int = bridge.command("dev_field_query",{"action":"rocks"}).value[0].enemy_id
	var waiting: int = core.spawn_enemy(&"pulser",position,{})
	core.set_enemy_motion(waiting,{"fire_t":0.0})
	core.set_attack_formation_mode(true)
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	core.step(0.01)
	check(not core.attack_budget_snapshot().waiting.is_empty(),"攻撃の予算待ちを突入前に残す")
	var friendly: Dictionary = bridge.command("dev_emit_attack",{"pool":0,"position":target+Vector2(1000,0),"velocity":Vector2.ZERO,"life":10.0,"damage":1.0,"radius":2.0,"policies":33})
	var friend_id: int = friendly.value.id
	warp_attacks(bridge,core,target+Vector2(1000,0))
	check(bridge.command("dev_set_warp",{"position":target,"life":0.1}).ok,"機体が触れる位置にワープを置く")
	var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(800,400),Vector2(1600,800))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	check(frame.warp.gone>frame.warp.time and frame.warp.radius==30.0 and presentation.frame_view.apply_frame(frame),"回る三本のワープの輪を通常画面へ表示する")
	await get_tree().process_frame
	var before_entry: Dictionary = bridge.checkpoint()
	fixed_step(bridge)
	var clock: float = core.inspect().time
	check(is_equal_approx(core.inspect().bonus_remaining,0.05) and bridge.command("dev_field_query",{"action":"warp"}).value.gone<0.0,"接触を一度だけ受け取りボーナスへ入る")
	check(gravity_enemy(core,ordinary).dead and gravity_enemy(core,waiting).dead and not gravity_enemy(core,boss).dead and not gravity_enemy(core,child).dead and not gravity_enemy(core,rock).dead,"通常敵だけを掃除してボス・存命ボス部位・岩を保つ")
	check(core.hostiles_snapshot().is_empty() and core.hazards_snapshot().is_empty() and core.attack_budget_snapshot().waiting.is_empty(),"敵弾・残る帯・消えた敵の予算待ちを掃除する")
	check(core.attack_snapshot().any(func(item): return item.id==friend_id and item.pool==0) and bridge.read_frame().value.ui.draw.gauge==1.0,"味方弾を保ちゲージを回復する")
	var bonus: Dictionary = core.spawn_target(clock,true)
	var normal: Dictionary = core.spawn_target(clock,false)
	check(bonus.pop==6.0 and bonus.per_type.get(&"drifter")==4.0 and bonus.per_type.get(&"pulser")==2.0 and not bonus.per_type.has(&"lynx") and normal.per_type.has(&"lynx"),"既存曲線の比率を保ち雑魚と硬めだけのボーナス配分へ切り替える")
	core.set_population_mode(true,false,false)
	fixed_step(bridge)
	var fresh: Array = core.enemies_snapshot().filter(func(enemy): return enemy.id not in [boss,child,rock] and not enemy.dead)
	check(not fresh.is_empty() and fresh.all(func(enemy): return enemy.type in ["drifter","pulser"]),"通常Runnerが生成済みの配分でボーナスを補充する")
	check(core.inspect().time==clock and core.inspect().bonus_remaining<0.05,"ボーナス中はラン時計を止め残り秒だけを進める")
	var pending: Dictionary = bridge.checkpoint()
	mute_checks = phase_only
	var xp_ui: Dictionary = bridge.read_frame().value.ui
	check(is_equal_approx(xp_ui.bonus_remaining,core.inspect().bonus_remaining),"ボーナス残り秒を通常HUDへ渡す")
	await get_tree().process_frame
	check(is_equal_approx(session.view.get_node("Hud/HudRoot")._cpp_ui.bonus_remaining,xp_ui.bonus_remaining),"通常HUDがボーナス残り秒を表示に受け取る")
	bridge.command("dev_add_xp",{"amount":xp_ui.next_xp-xp_ui.xp})
	fixed_step(bridge)
	var ui: Dictionary = bridge.read_frame().value.ui
	mute_checks = false
	check(ui.phase==RunIds.Phase.Levelup and ui.cards.offer_id>0,"ボーナス中もレベルアップのカード待ちへ入る")
	mute_checks = phase_only
	var paused_time: float = core.inspect().world_time
	var paused_bonus: float = core.inspect().bonus_remaining
	fixed_step(bridge)
	check(core.inspect().time==clock and core.inspect().world_time==paused_time and core.inspect().bonus_remaining==paused_bonus,"カード待ち中は世界時計とボーナス残り秒も止める")
	mute_checks = "--cpp-warp-card" in OS.get_cmdline_user_args() or phase_only
	check(bridge.restore(pending.value).ok,"ワープ後のボーナス時計と配分を値から復帰する")
	warp_attacks(bridge,core,target+Vector2(1000,0))
	for tick in 8:
		fixed_step(bridge)
		if core.inspect().bonus_remaining==0.0: break
	check(core.inspect().bonus_remaining==0.0 and core.inspect().time==clock,"期限でボーナスを終え通常のラン時計へ戻す")
	check(core.hostiles_snapshot().is_empty() and core.hazards_snapshot().is_empty() and core.attack_snapshot().any(func(item): return item.id==friend_id),"終了時も敵攻撃だけを消し味方弾を保つ")
	fresh = core.enemies_snapshot().filter(func(enemy): return enemy.id not in [boss,child,rock] and not enemy.dead)
	check(not fresh.is_empty() and core.spawn_target(clock,false).per_type.has(&"lynx"),"終了した同じ世界更新で通常配分の補充を再開する")
	fixed_step(bridge)
	check(core.inspect().time>clock,"通常へ戻った次の更新でラン時計を進める")
	check(bridge.restore(before_entry.value).ok,"未取得のワープと残留攻撃へ値から復帰する")
	bridge.command("dev_ship_motion",{"position":target+Vector2(500,0),"velocity":Vector2.ZERO})
	core.step(0.2)
	fixed_step(bridge)
	check(core.inspect().bonus_remaining==0.0 and bridge.command("dev_field_query",{"action":"warp"}).value.gone<0.0,"期限切れのワープには入らない")
	bridge.release_checkpoint(pending.value)
	bridge.release_checkpoint(before_entry.value)
	session.free()

func unsigned_shift(value: int, bits: int) -> int:
	return (value>>bits)&(0x7fffffffffffffff>>(bits-1))

func pcg_step(value: int) -> Array[int]:
	var lo := value&0xffffffff
	var hi := unsigned_shift(value,32)
	var product := lo*1284865837+4150755663
	var next_hi := (((hi*1284865837)&0xffffffff)+((lo*1481765933)&0xffffffff)+335903614+(product>>32))&0xffffffff
	var advanced := ((next_hi&0x7fffffff)<<32)|(product&0xffffffff)
	if next_hi&0x80000000: advanced += -9223372036854775807-1
	var x := unsigned_shift(unsigned_shift(value,18)^value,27)&0xffffffff
	var rotation := unsigned_shift(value,59)
	return [advanced,((x>>rotation)|(x<<((-rotation)&31)))&0xffffffff]

func check_cpp_comets() -> void:
	mute_checks = "--cpp-comets-tail" in OS.get_cmdline_user_args() or "--cpp-comets-collect" in OS.get_cmdline_user_args() or "--cpp-comets-expiry" in OS.get_cmdline_user_args()
	var known := pcg_step(8101019391883367851)
	check(known[1]==372258371 and pcg_step(known[0])[1]==2721001807,"PCGの参照計算が既知の二出力と一致する")
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 1200.0
	cfg.planet_radius = 0.0
	cfg.field_radius = 10000.0
	cfg.world_tick_div = 1
	cfg.weapon_slots = 1
	cfg.comet_interval_min = 0.025
	cfg.comet_interval_max = 0.025
	cfg.comet_speed = 300.0
	cfg.rare_comet_after = 0.0
	cfg.rare_comet_chance = 0.0
	cfg.rare_comet_hp_mult = 2.0
	cfg.warp_chance = 1.0
	cfg.meteor_heal_chance = 0.0
	cfg.meteor_magnet_chance = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 86
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/run_comets"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"彗星の軌道と同時破壊の予約".sha256_text())
	check(built==OK,"彗星の編集値と限定武器のメタ情報を生成する")
	if built!=OK: return
	var path := output.path_join("stage_86.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":866},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"彗星とカプセルのある通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	for tick in 5: fixed_step(bridge)
	var target: Vector2 = core.ship_snapshot().ship_pos
	check(bridge.command("dev_field_query",{"action":"warp"}).value.gone>0.0 and rock_snapshot(bridge).is_empty(),"期限でワープを選んだ回は彗星を重ねない")
	bridge.command("dev_set_warp",{"position":target+Vector2(2000,0),"life":0.0})
	fixed_step(bridge)
	bridge.command("dev_comet_state",{"remaining":0.0,"boss_spawned":true})
	fixed_step(bridge)
	var normal: Dictionary = rock_snapshot(bridge).back()
	check(normal.kind==4 and normal.rare_weapon.is_empty() and is_equal_approx(normal.velocity.length(),300.0) and normal.size>=35.0 and normal.size<=55.0,"通常Runnerの期限から普通の彗星を設定どおり生成する")
	bridge.command("dev_comet_state",{"remaining":1000.0})
	var position: Vector2 = normal.position
	core.step(0.1)
	check(rock_snapshot(bridge).back().position.is_equal_approx(position+normal.velocity*0.1),"世界秒から彗星の直線軌道を求める")
	var remaining: float = bridge.command("dev_field_query",{"action":"snapshot"}).value.comet_t
	bridge.command("pause",{"paused":true})
	fixed_step(bridge)
	check(bridge.command("dev_field_query",{"action":"snapshot"}).value.comet_t==remaining,"停止中は次の彗星までの残り秒を進めない")
	bridge.command("pause",{"paused":false})
	check(bridge.command("dev_spawn_comet",{"rare":true}).ok,"未装備の限定武器を持つレア彗星を生成する")
	var rare: Dictionary = rock_snapshot(bridge).back()
	mute_checks = "--cpp-comets-collect" in OS.get_cmdline_user_args() or "--cpp-comets-expiry" in OS.get_cmdline_user_args()
	check(rare.rare_weapon in ["W21","W22"],"レア彗星は現行の限定武器から報酬を選ぶ")
	var now: float = core.inspect().world_time
	var ids: Array[int] = []
	for entry in [[target+Vector2(180,0),false],[target+Vector2(260,0),true],[target+Vector2(260,30),true]]:
		var data := {"position":entry[0],"kind":4,"manual":true,"size":40.0,"velocity":Vector2(300,0),"born":now,"gone":now+10.0}
		if entry[1]: data["rare_weapon"] = rare.rare_weapon
		check(bridge.command("dev_add_rock",data).ok,"寿命付きの普通とレア彗星を同じ場面へ置く")
	bridge.command("dev_stream_rocks",{"center":target,"half":Vector2(640,360),"dt":0.3})
	var rocks := rock_snapshot(bridge)
	for rock: Dictionary in rocks.slice(-3): ids.append(int(rock.enemy_id))
	var plain := gravity_enemy(core,ids[0])
	var golden := gravity_enemy(core,ids[1])
	check(ids.all(func(id): return id>0) and is_equal_approx(golden.hp,plain.hp*2.0),"同じ大きさのレア彗星だけHP倍率を掛ける")
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(700,400),Vector2(1400,800))).value
	check(frame.comets.values.size()==18 and frame.comets.values[5]==0.0 and frame.comets.values[11]==1.0 and presentation.frame_view.apply_frame(frame),"普通の白青の尾とレアの金色の尾を共通描画へ渡す")
	var ui: Dictionary = bridge.read_frame().value.ui
	check(ui.rare_comets.size()==3 and ui.view_half.x>0.0,"画面外を含むレア彗星の位置をHUDの端の矢印へ渡す")
	await get_tree().process_frame
	var wells: int = bridge.command("dev_field_query",{"action":"wells"}).value.size()
	for id in ids.slice(1):
		var killed: Dictionary = bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
		check(killed.ok and killed.value.killed,"同じ更新でレア彗星を共通撃破へ渡す")
	check(core.pickups_snapshot().capsules.size()==2 and bridge.command("dev_field_query",{"action":"wells"}).value.size()==wells,"同時破壊では報酬を個体ごとに一つ出しレアから重力を出さない")
	check(not bridge.command("dev_kill",{"entity_id":ids[1],"cause":"bullet"}).value.killed and core.pickups_snapshot().capsules.size()==2,"同じ彗星の撃破を二度受け取らない")
	var drops: Array = core.pickups_snapshot().capsules.duplicate(true)
	core.step_pickups(30.0)
	check(core.pickups_snapshot().capsules.size()==2 and core.pickups_snapshot().capsules[0].pos==drops[0].pos,"彗星武器のカプセルは吸い寄せず寿命で消さない")
	frame = bridge.read_render(Rect2(target-Vector2(700,400),Vector2(1400,800))).value
	check(frame.capsules.values.size()==6 and frame.capsules.values[2]==2.0 and presentation.frame_view.apply_frame(frame),"二つの彗星武器カプセルを通常画面へ表示する")
	await get_tree().process_frame
	bridge.read_frame()
	var saved: Dictionary = bridge.checkpoint()
	mute_checks = "--cpp-comets-expiry" in OS.get_cmdline_user_args()
	var equipped: Array = bridge.read_frame().value.ui.weapon_levels.duplicate(true)
	bridge.command("dev_ship_motion",{"position":target+Vector2(260,15),"velocity":Vector2.ZERO})
	core.step_pickups(0.001)
	var collected: Dictionary = core.pickups_snapshot()
	check(collected.capsules.is_empty() and collected.pending_comet_weapons==[rare.rare_weapon,rare.rare_weapon],"別々のカプセルを回収して二個分の武器を予約する")
	core.step_pickups(0.001)
	check(core.pickups_snapshot().pending_comet_weapons==collected.pending_comet_weapons and bridge.read_frame().value.ui.weapon_levels==equipped,"同じ報酬を二度回収せず満枠の装備を保つ")
	var events: Dictionary = bridge.read_frame().value
	# read_frameは出来事を消費しないので同じフレームを表示側へ一度だけ届ける。
	check(events.events.filter(func(e): return e.type==&"pickup" and e.payload.kind==&"comet_weapon").size()==2,"回収を二個分の表示イベントへ渡す")
	presentation.frame_view.receive_frame(events)
	presentation.frame_view.update_effects(events,0.0)
	check(presentation.frame_view._rings.size()>=2,"回収した金色の輪を通常表示へ渡す")
	check(bridge.restore(saved.value).ok and core.pickups_snapshot().pending_comet_weapons.is_empty() and core.pickups_snapshot().capsules.size()==2,"未回収のカプセルと選んだ報酬を値から復帰する")
	bridge.command("dev_ship_motion",{"position":target+Vector2(260,15),"velocity":Vector2.ZERO})
	core.step_pickups(0.001)
	check(core.pickups_snapshot().pending_comet_weapons==collected.pending_comet_weapons,"復帰後も同じ二個分を予約する")
	mute_checks = false
	core.set_motion_context(target,target,Vector2(640,360))
	check(core.step(20.0),"寿命の確認まで世界秒を進める")
	bridge.command("dev_stream_rocks",{"center":target,"half":Vector2(640,360),"dt":0.3})
	check(gravity_enemy(core,ids[0]).is_empty() and rock_snapshot(bridge).slice(-3)[0].destroyed,"通常彗星は寿命で退場する")
	bridge.release_checkpoint(saved.value)
	comets_finished = true
	session.free()
