## 攻撃の表示を読み込めることと、水流の資源を初回使用時だけ準備することを確認する。
extends Node

var failed := 0
var lump_notification_only := false
var arrow_fixes := false
var mute_checks := false

func check(ok: bool, message: String) -> void:
	if mute_checks: return
	if not ok:
		failed += 1
		push_error(message)

func _ready() -> void:
	if "--cpp-render-kinds" in OS.get_cmdline_user_args() or "--cpp-render-kinds-view-fix" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_render_kinds()
		check(finished,"統合で変わった表示種別の確認を最後まで実施する")
		print("[cpp_render_kinds] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return




	if "--cpp-lump" in OS.get_cmdline_user_args() or "--cpp-lump-shoot-fix" in OS.get_cmdline_user_args():
		lump_notification_only = "--cpp-lump-shoot-fix" in OS.get_cmdline_user_args()
		mute_checks = lump_notification_only
		await check_cpp_lump()
		print("[cpp_lump] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-ring-hold" in OS.get_cmdline_user_args():
		await check_cpp_ring_hold()
		print("[cpp_ring_hold] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-star-bolt" in OS.get_cmdline_user_args():
		await check_cpp_star_bolt()
		print("[cpp_star_bolt] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-light-arrow" in OS.get_cmdline_user_args() or "--cpp-light-arrow-fixes" in OS.get_cmdline_user_args():
		arrow_fixes = "--cpp-light-arrow-fixes" in OS.get_cmdline_user_args()
		mute_checks = arrow_fixes
		await check_cpp_light_arrow()
		print("[cpp_light_arrow] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var script = load("res://scripts/render/run_presentation.gd")
	check(script != null and script.can_instantiate(), "攻撃の表示を含む描画を生成できる")
	if failed > 0:
		get_tree().quit(1)
		return
	var render = script.new()
	var world := Node2D.new()
	world.name = "World"
	render.add_child(world)
	render.world_path = NodePath("World")
	var projectiles := DrawLayer.new()
	world.add_child(projectiles)
	render._layers.projectiles = projectiles
	render.pipeline = RenderPipeline.new()
	render.add_child(render.pipeline)
	check(not ResourceLoader.has_cached("res://shaders/water_flood.gdshader"), "水流を使う前に専用shaderを読まない")
	for kind in ["bullet", "missile", "reflected", "shell", "slash", "bolt", "beam", "zone", "wave", "wall"]:
		var visual = render._attack_visual(kind)
		check(visual != null, "%sの表示を生成できる" % kind)
	check(not ResourceLoader.has_cached("res://shaders/water_flood.gdshader"), "通常の攻撃は水流のshaderを読まない")
	var flood = render.flood()
	check(flood != null and ResourceLoader.has_cached("res://shaders/water_flood.gdshader"), "水流の初回使用でshaderを準備する")
	check(render.flood() == flood and world.get_node_or_null("Flood") != null, "水流の層を再利用する")
	render.free()
	print("[attack_presentation] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

var cpp_session: RunSession
var cpp_bridge
var cpp_core
var cpp_config: GameConfig
var cpp_origin := Vector2(-900,0)
func prepare_cpp_attack(index_number: int, name: String) -> bool:
	cpp_config = ContentManager.base.duplicate(true)
	cpp_config.start_radius = 900.0
	cpp_config.planet_radius = 100.0
	cpp_config.moon_count = 0
	cpp_config.meteor_count = 0
	cpp_config.iron_count = 0
	cpp_config.saw_count = 0
	var stage := RuntimeStage.new()
	stage.index = index_number
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["drifter"])
	var output := "res://.content/dev/"+name
	var builder = load("res://tools/content/build_run_content.gd")
	if builder.build(stage,cpp_config,output,name.sha256_text())!=OK:
		check(false,"攻撃の定義を生成する: "+name)
		return false
	var path := output.path_join("stage_%d.json" % index_number)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	cpp_session = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":290},true)
	cpp_session.auto_step = false
	while cpp_session.bridge==null and cpp_session.cpp_error==OK: await get_tree().process_frame
	check(cpp_session.bridge!=null,"攻撃を表示する通常のC++ランを準備する: "+name)
	if cpp_session.bridge==null: return false
	cpp_bridge = cpp_session.bridge
	cpp_core = cpp_bridge._core
	cpp_bridge.step(1.0/120.0,cpp_bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(0,300),"velocity":Vector2.ZERO})
	cpp_core.set_motion_context(cpp_origin+Vector2(0,300),cpp_origin,Vector2(640,360))
	return true
func check_cpp_light_arrow() -> void:
	if not await prepare_cpp_attack(90,"light_arrow"): return
	var owner: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin+Vector2(-300,300)}).value
	var empty: Dictionary = cpp_bridge.checkpoint()
	var params := {"position":cpp_origin,"angle":0.0,"speed":100.0,"radius":12.0,"travel":400.0,"damage":8.0,"owner_id":owner}
	check(cpp_core.hostiles_snapshot().is_empty(),"光の矢は発射元が発射するまで生成しない")
	var fired: Dictionary = cpp_bridge.command("dev_fire_light_arrow",params)
	check(fired.ok,"発生元から長さ0の光の矢を発射する")
	if not fired.ok: cpp_session.free(); return
	cpp_core.step_hostiles(0.1)
	var state: Array = cpp_core.hostiles_snapshot()
	check(state[0].pos==cpp_origin+Vector2(10,0) and is_equal_approx(state[0].life,3.9),"光の矢が指定した方向へ飛ぶ")
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1600,-500,1400,1000)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(frame.shapes.size()==1 and frame.shapes[0].kind==preload("res://tools/content/generated/run_schema.gd").ENUMS.RenderShapeKind.LightArrow and frame.shapes[0].length==0.0 and not frame.shapes[0].cosmic,"長さ0の矢も矢じりと表示だけの尾を出す")
	check(presentation.frame_view.apply_frame(frame),"光の矢を通常画面で描く")
	await get_tree().process_frame
	cpp_bridge.command("dev_remove",{"entity_id":owner})
	var active: Dictionary = cpp_bridge.checkpoint()
	check(active.ok and cpp_core.attack_snapshot()[0].source_id==owner,"発射元退場後も元のIDで飛行中の矢を保持する")
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin-Vector2(50,0),"velocity":Vector2.ZERO})
	cpp_core.step_hostiles(0.1)
	check(cpp_core.hostiles_snapshot().size()==1 and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp),"長さ0の矢は見た目の尾だけで被弾させない")
	cpp_bridge.restore(active.value)
	check(cpp_core.hostiles_snapshot()==state,"矢の速度・寿命・長さ・位置を保持点から復元する")
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(60,0),"velocity":Vector2.ZERO})
	cpp_core.step_hostiles(0.5)
	check(cpp_core.hostiles_snapshot().is_empty() and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-8.0),"矢じりの飛行区間が命中して消える")
	var events: Array = cpp_bridge.read_frame().value.events
	check(events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause==&"arrow"),"光の矢の原因名を共通記録へ残す")
	cpp_bridge.restore(empty.value)
	params["length"] = 100.0
	params["cosmic"] = true
	mute_checks = false
	var cosmic_result: Dictionary = cpp_bridge.command("dev_fire_light_arrow",params)
	check(cosmic_result.ok,"長さを指定したコズミック矢を生成する: "+str(cosmic_result)+" owner="+str(cpp_core.enemies_snapshot()))
	if not cosmic_result.ok: cpp_session.free(); return
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin-Vector2(50,0),"velocity":Vector2.ZERO})
	frame = cpp_bridge.read_render(Rect2(-1600,-500,1400,1000)).value
	check(frame.shapes[0].cosmic and frame.shapes[0].length==100.0 and presentation.frame_view.apply_frame(frame),"コズミック矢の長い尾と色・星を通常画面へ渡す")
	await get_tree().process_frame
	cpp_core.step_hostiles(0.1)
	check(cpp_core.hostiles_snapshot().is_empty() and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-8.0),"長さを指定した矢は移動前の尾から判定する")
	cpp_bridge.restore(empty.value)
	params.position = Vector2(-300,0)
	params.speed = 1000.0
	cpp_bridge.command("dev_fire_light_arrow",params)
	cpp_bridge.command("dev_ship_motion",{"position":Vector2(80,0),"velocity":Vector2.ZERO})
	cpp_core.step_hostiles(0.5)
	check(cpp_core.hostiles_snapshot().is_empty() and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp),"長い矢も天体へ先端が着く時刻を基準に機体より先に消える")
	cpp_bridge.restore(active.value)
	cpp_core.step_hostiles(4.0)
	check(cpp_core.hostiles_snapshot().is_empty(),"光の矢は飛行距離を使い切って消える")
	cpp_bridge.release_checkpoint(active.value)
	cpp_bridge.release_checkpoint(empty.value)
	cpp_session.free()

func check_cpp_render_kinds() -> bool:
	if not await prepare_cpp_attack(90,"light_arrow"): return false
	const SHAPES = preload("res://tools/content/generated/run_schema.gd").ENUMS.RenderShapeKind
	var params := {"position":cpp_origin,"angle":0.0,"speed":100.0,"radius":12.0,"travel":400.0,"damage":8.0}
	if not cpp_bridge.command("dev_fire_light_arrow",params).ok: return false
	params["position"] = cpp_origin+Vector2(80,0)
	params["cosmic"] = true
	params["length"] = 100.0
	if not cpp_bridge.command("dev_fire_light_arrow",params).ok: return false
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1600,-500,1400,1000)).value
	if "--cpp-render-kinds-view-fix" not in OS.get_cmdline_user_args():
		check(frame.shapes.size()==2 and frame.shapes.all(func(row): return row.kind==SHAPES.LightArrow),"光の矢の番号をC++とGodotの同じ生成定義から読む")
		check(frame.shapes.any(func(row): return row.cosmic) and frame.shapes.any(func(row): return not row.cosmic),"通常とコズミックの表示値を保持する")
	frame.shapes.append({"kind":SHAPES.Blast,"layer":10,"order":5,"owner_id":50,"points":PackedVector2Array([cpp_origin+Vector2(160,0)]),
		"offsets":PackedInt32Array([0,1]),"widths":PackedFloat32Array([30.0]),"colors":PackedColorArray([Color.ORANGE])})
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	check(presentation.frame_view.apply_frame(frame),"番号が異なる爆発と矢の表示を同じフレームへ渡す")
	await get_tree().process_frame
	check(presentation.frame_view._arrow_displays.size()==2 and presentation.frame_view._shape_displays.has("%d:10:5" % SHAPES.Blast),"爆発と矢をそれぞれの表示へ振り分ける")
	cpp_session.free()
	await get_tree().process_frame
	return true

func check_cpp_star_bolt() -> void:
	if not await prepare_cpp_attack(91,"star_bolt"): return
	var owner: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin+Vector2(-300,300)}).value
	var empty: Dictionary = cpp_bridge.checkpoint()
	var params := {"position":cpp_origin,"angle":PI*0.5,"speed":100.0,"damage":8.0,"owner_id":owner}
	var fired: Dictionary = cpp_bridge.command("dev_fire_star_bolt",params)
	check(fired.ok,"発生元から星弾を生成する")
	if not fired.ok: cpp_session.free(); return
	cpp_core.step_hostiles(0.1)
	var state: Array = cpp_core.hostiles_snapshot()
	check(state[0].pos.distance_to(cpp_origin+Vector2(0,10))<0.001 and state[0].radius==9.0 and is_equal_approx(state[0].life,5.9),"星弾は半径9・寿命6秒で直進する")
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1600,-500,1400,1000)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(presentation.frame_view.apply_frame(frame),"星弾の生成済みメッシュを通常画面へ渡す")
	var stars: Array = frame.batches.filter(func(b): return presentation.frame_view.visuals[b.visual_id].role==preload("res://tools/content/generated/run_schema.gd").ENUMS.VisualRole.StarBolt)
	check(stars.size()==1 and stars[0].ids.size()==1 and presentation.frame_view.batches[stars[0].visual_id].multimesh.mesh!=null,"星と芯の生成済みFlightメッシュをバッチで描く")
	await get_tree().process_frame
	cpp_bridge.command("dev_remove",{"entity_id":owner})
	var active: Dictionary = cpp_bridge.checkpoint()
	check(active.ok and cpp_core.attack_snapshot()[0].source_id==owner,"発射元退場後も星弾を元のIDで保持する")
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(0,60),"velocity":Vector2.ZERO})
	cpp_core.step_hostiles(0.5)
	check(cpp_core.hostiles_snapshot().is_empty() and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-8.0),"星弾が共通被弾へ通って消える")
	var events: Array = cpp_bridge.read_frame().value.events
	check(events.any(func(e): return e.type==&"combat_player_damage" and e.payload.cause==&"star_bolt"),"星弾の原因名を共通記録へ残す")
	cpp_bridge.restore(active.value)
	check(cpp_core.hostiles_snapshot()==state,"星弾の飛行途中の値を復元する")
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(300,0),"velocity":Vector2.ZERO})
	cpp_core.step_hostiles(6.0)
	check(cpp_core.hostiles_snapshot().is_empty(),"星弾は寿命で消える")
	cpp_bridge.restore(empty.value)
	params.position = Vector2(-300,0)
	params.angle = 0.0
	params.speed = 1000.0
	check(cpp_bridge.command("dev_fire_star_bolt",params).ok,"天体へ向かう星弾を生成する")
	cpp_core.step_hostiles(0.5)
	check(cpp_core.hostiles_snapshot().is_empty(),"星弾は天体に当たって消える")
	frame = cpp_bridge.read_render(Rect2(-1600,-500,2000,1000)).value
	check(not frame.batches.any(func(b): return presentation.frame_view.visuals[b.visual_id].role==preload("res://tools/content/generated/run_schema.gd").ENUMS.VisualRole.StarBolt),"終了した星弾のFlight表示を回収する")
	cpp_bridge.release_checkpoint(active.value)
	cpp_bridge.release_checkpoint(empty.value)
	cpp_session.free()

func check_cpp_ring_hold() -> void:
	if not await prepare_cpp_attack(92,"ring_hold"): return
	var owner: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin}).value
	var empty: Dictionary = cpp_bridge.checkpoint()
	var params := {"source_id":owner,"count":4,"radius":100.0,"wait":0.25,"speed":100.0,"damage":8.0}
	var fired: Dictionary = cpp_bridge.command("dev_fire_ring_hold",params)
	check(fired.ok and fired.value.size()==4,"発生元の円周へ4発の待機弾を生成する")
	if not fired.ok: cpp_session.free(); return
	var states: Array = cpp_core.hostiles_snapshot()
	for k in 4:
		var expected := cpp_origin+Vector2.from_angle(TAU*k/4.0)*100.0
		check(states[k].pos.distance_to(expected)<0.001 and is_equal_approx(states[k].life,4.25) and is_equal_approx(states[k].wait,0.25),"円周配置と待機を含む寿命を保つ: %d" % k)
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1600,-500,1400,1000)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(presentation.frame_view.apply_frame(frame),"円周に並んだ通常弾を画面へ渡す")
	var bullets: Array = frame.batches.filter(func(b): return presentation.frame_view.visuals[b.visual_id].role==11)
	check(bullets.size()==1 and bullets[0].ids.size()==4 and is_equal_approx(bullets[0].transforms[0],8.0),"待機弾は半径8の通常弾として描く")
	await get_tree().process_frame
	cpp_core.step_hostiles(0.125)
	var waiting: Array = cpp_core.hostiles_snapshot()
	check(waiting[0].pos==states[0].pos and is_equal_approx(waiting[0].life,4.125) and is_equal_approx(waiting[0].wait,0.125),"待機中は動かず寿命だけ減る")
	cpp_bridge.command("dev_remove",{"entity_id":owner})
	var held: Dictionary = cpp_bridge.checkpoint()
	check(held.ok and cpp_core.attack_snapshot().all(func(a): return a.source_id==owner and not a.source_alive),"発生元の退場後も待機弾を元のIDで保持する")
	cpp_core.step_hostiles(0.125)
	check(cpp_core.hostiles_snapshot()[0].pos==states[0].pos and cpp_core.hostiles_snapshot()[0].wait==0.0,"待機時間を使い切る更新は動かない")
	cpp_core.step_hostiles(0.125)
	check(cpp_core.hostiles_snapshot()[0].pos.distance_to(states[0].pos+Vector2(12.5,0))<0.001,"待機が終わった次の更新から外向きに飛び出す")
	cpp_bridge.restore(held.value)
	check(cpp_core.hostiles_snapshot()==waiting,"待機時間・速度・寿命・位置を保持点から復元する")
	cpp_core.step_hostiles(0.125)
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(160,0),"velocity":Vector2.ZERO})
	cpp_core.step_hostiles(0.5)
	check(cpp_core.hostiles_snapshot().size()==3 and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-8.0),"飛び出した弾が共通被弾へ通って消える")
	cpp_core.step_hostiles(4.0)
	check(cpp_core.hostiles_snapshot().is_empty(),"待機を含む寿命を使い切ると残りの弾も消える")
	cpp_bridge.restore(empty.value)
	params.wait = -1.0
	check(not cpp_bridge.command("dev_fire_ring_hold",params).ok and cpp_core.hostiles_snapshot().is_empty(),"不正な待機時間は弾を追加せず拒否する")
	cpp_bridge.release_checkpoint(held.value)
	cpp_bridge.release_checkpoint(empty.value)
	cpp_session.free()

func check_cpp_lump() -> void:
	if not await prepare_cpp_attack(93,"lump"): return
	var owner: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin}).value
	var source: Dictionary = cpp_core.enemies_snapshot()[0]
	var empty: Dictionary = cpp_bridge.checkpoint()
	var params := {"source_id":owner,"angle":PI*0.5,"speed":100.0,"radius":18.0,"damage":10.0}
	var fired: Dictionary = cpp_bridge.command("dev_fire_lump",params)
	check(fired.ok,"発生元から指定半径の塊の弾を生成する")
	if not fired.ok: cpp_session.free(); return
	var shot: Dictionary = cpp_core.hostiles_snapshot()[0]
	var expected: Vector2 = cpp_origin+Vector2.from_angle(PI*0.5)*(float(source.radius)+18.0)
	check(shot.pos.distance_to(expected)<0.001 and is_equal_approx(shot.life,4.0),"敵の位置と半径に弾半径を足した位置から寿命4秒で発射する")
	var events: Array = cpp_bridge.latest_frame().value.events
	if lump_notification_only: mute_checks = false
	check(events.any(func(e): return e.type==&"shoot" and e.payload.kind==&"lump" and e.payload.pos==cpp_origin),"敵の中心からlumpの発射通知を出す")
	if lump_notification_only:
		cpp_bridge.release_checkpoint(empty.value)
		cpp_session.free()
		return
	cpp_core.step_hostiles(0.1)
	var state: Array = cpp_core.hostiles_snapshot()
	check(state[0].pos.distance_to(expected+Vector2(0,10))<0.001 and is_equal_approx(state[0].life,3.9),"塊の弾が直進し寿命を減らす")
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1600,-500,1400,1000)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(presentation.frame_view.apply_frame(frame),"塊の弾を通常画面へ渡す")
	var bullets: Array = frame.batches.filter(func(b): return presentation.frame_view.visuals[b.visual_id].role==11)
	check(bullets.size()==1 and is_equal_approx(bullets[0].transforms[0],18.0),"指定した弾の半径で通常弾を描く")
	await get_tree().process_frame
	cpp_bridge.command("dev_remove",{"entity_id":owner})
	var held: Dictionary = cpp_bridge.checkpoint()
	check(held.ok and cpp_core.attack_snapshot()[0].source_id==owner,"発射元退場後も塊の弾を元のIDで保持する")
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(0,150),"velocity":Vector2.ZERO})
	cpp_core.step_hostiles(1.0)
	check(cpp_core.hostiles_snapshot().is_empty() and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-10.0),"塊の弾が共通被弾へ通って消える")
	cpp_bridge.restore(held.value)
	check(cpp_core.hostiles_snapshot()==state,"塊の弾の位置・速度・寿命を保持点から復元する")
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(300,0),"velocity":Vector2.ZERO})
	cpp_core.step_hostiles(4.0)
	check(cpp_core.hostiles_snapshot().is_empty(),"塊の弾が寿命で消える")
	cpp_bridge.restore(empty.value)
	var terrain_source: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-300,0)}).value
	params.source_id = terrain_source
	params.angle = 0.0
	params.speed = 1000.0
	check(cpp_bridge.command("dev_fire_lump",params).ok,"天体へ向かう塊の弾を生成する")
	cpp_core.step_hostiles(0.5)
	check(cpp_core.hostiles_snapshot().is_empty(),"塊の弾は天体に当たって消える")
	cpp_bridge.restore(empty.value)
	params.source_id = owner
	params.radius = -1.0
	check(not cpp_bridge.command("dev_fire_lump",params).ok and cpp_core.hostiles_snapshot().is_empty(),"負の半径の塊の弾を追加せず拒否する")
	cpp_bridge.release_checkpoint(held.value)
	cpp_bridge.release_checkpoint(empty.value)
	cpp_session.free()
