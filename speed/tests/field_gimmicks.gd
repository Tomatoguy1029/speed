## 仕掛けの更新と、フィールドから使う共通の入口を確認する。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
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
