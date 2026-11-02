## 攻撃の表示を読み込めることと、水流の資源を初回使用時だけ準備することを確認する。
extends Node
const ENUMS = preload("res://tools/content/generated/run_schema.gd").ENUMS

var failed := 0
var lump_notification_only := false
var arrow_fixes := false
var mute_checks := false
var zone_fade_only := false
var lances_finished := false
var lances_tick_only := false

func check(ok: bool, message: String) -> void:
	if mute_checks: return
	if not ok:
		failed += 1
		push_error(message)

func _ready() -> void:
	if "--cpp-corona-throw" in OS.get_cmdline_user_args() or "--cpp-corona-throw-order" in OS.get_cmdline_user_args() or "--cpp-corona-throw-order-fix" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_corona_throw()
		check(finished,"かんむり座の投射の指定確認を最後まで実施する")
		print("[cpp_corona_throw] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-corona" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_corona()
		check(finished,"かんむり座の指定確認を最後まで実施する")
		print("[cpp_corona] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-pump" in OS.get_cmdline_user_args() or "--cpp-pump-fix2" in OS.get_cmdline_user_args() or "--cpp-pump-final" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_pump()
		check(finished,"ポンプ座の指定確認を最後まで実施する")
		print("[cpp_pump] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-gates" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_gates()
		check(finished,"判定ゲートの指定確認を最後まで実施する")
		print("[cpp_gates] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-crab" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_crab()
		check(finished,"かに座の指定確認を最後まで実施する")
		print("[cpp_crab] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-aquila" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_aquila()
		check(finished,"わし座の指定確認を最後まで実施する")
		print("[cpp_aquila] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-phoenix" in OS.get_cmdline_user_args() or "--cpp-phoenix-fix" in OS.get_cmdline_user_args() or "--cpp-phoenix-fix2" in OS.get_cmdline_user_args() or "--cpp-phoenix-fix3" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_phoenix()
		check(finished,"ほうおう座の指定確認を最後まで実施する")
		print("[cpp_phoenix] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-bomber" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_bomber()
		check(finished,"自爆する雑魚の指定確認を最後まで実施する")
		print("[cpp_bomber] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-cross-enemy" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_cross_enemy()
		check(finished,"みなみじゅうじ座の指定確認を最後まで実施する")
		print("[cpp_cross_enemy] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-aquarius" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_aquarius()
		check(finished,"みずがめ座の指定確認を最後まで実施する")
		print("[cpp_aquarius] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-shell" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_shell()
		check(finished,"圧縮弾の指定確認を最後まで実施する")
		print("[cpp_shell] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-rings" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_rings()
		check(finished,"複数輪の不足条件を最後まで確認する")
		print("[cpp_rings] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-cosmic-arrow" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_cosmic_arrow()
		check(finished,"コズミック矢の不足条件を最後まで確認する")
		print("[cpp_cosmic_arrow] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-saw" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_saw()
		check(finished,"丸鋸の不足条件を最後まで確認する")
		print("[cpp_saw] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-fling-corpse" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_fling_corpse()
		check(finished,"死体投射の指定確認を最後まで実施する")
		print("[cpp_fling_corpse] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-scatter-hull" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_scatter_hull()
		check(finished,"船体散開の不足条件を最後まで確認する")
		print("[cpp_scatter_hull] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-burst-debris" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_burst_debris()
		check(finished,"破砕片の不足条件を最後まで確認する")
		print("[cpp_burst_debris] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-light-lances" in OS.get_cmdline_user_args() or "--cpp-light-lances-step-fix" in OS.get_cmdline_user_args():
		lances_tick_only = "--cpp-light-lances-step-fix" in OS.get_cmdline_user_args()
		mute_checks = lances_tick_only
		await check_cpp_light_lances()
		check(lances_finished,"光の槍の指定確認を最後まで実施する")
		print("[cpp_light_lances] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-star-role" in OS.get_cmdline_user_args():
		var finished: bool = await check_cpp_star_role()
		check(finished,"統合した星弾の表示役割の確認を最後まで実施する")
		print("[cpp_star_role] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return


	if "--cpp-flood" in OS.get_cmdline_user_args():
		await check_cpp_flood()
		print("[cpp_flood] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-cross" in OS.get_cmdline_user_args():
		await check_cpp_cross()
		print("[cpp_cross] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-zone" in OS.get_cmdline_user_args() or "--cpp-zone-fade-fix" in OS.get_cmdline_user_args():
		zone_fade_only = "--cpp-zone-fade-fix" in OS.get_cmdline_user_args()
		mute_checks = zone_fade_only
		await check_cpp_zone()
		print("[cpp_zone] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-friendly-angle-fix" in OS.get_cmdline_user_args():
		mute_checks = true
		var ready: bool = await prepare_cpp_attack(96,"friendly_angle")
		mute_checks = false
		check(ready,"回転の前角度を確認するランを準備する")
		if ready:
			cpp_bridge.command("dev_fire_saw",{"position":cpp_origin,"velocity":Vector2(500,0),"radius":18.0,"damage":10.0,"life":1.0})
			cpp_core.step_projectiles(0.1)
			cpp_bridge.step(1.0/120.0,cpp_bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
			var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000),0.0).value
			check(frame.shapes.any(func(s): return s.kind==ENUMS.RenderShapeKind.FriendHull and s.saw and is_equal_approx(s.angle,1.4)),"回転する味方弾は描画補間の前角度にもangleを保持する")
			cpp_session.free()
		print("[cpp_friendly_angle] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-friend-hull" in OS.get_cmdline_user_args():
		await check_cpp_friend_hull()
		print("[cpp_friend_hull] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-friend-debris" in OS.get_cmdline_user_args():
		await check_cpp_friend_debris()
		print("[cpp_friend_debris] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
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
func prepare_cpp_attack(index_number: int, name: String, enemy_ids := PackedStringArray(["drifter"]), tuning: Dictionary = {}, definitions: Dictionary = {}) -> bool:
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
	stage.resources.enemy_ids = enemy_ids
	stage.enemy_tuning = tuning
	var output := "res://.content/dev/"+name
	var builder = load("res://tools/content/build_run_content.gd")
	if builder.build(stage,cpp_config,output,name.sha256_text(),definitions)!=OK:
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

func check_cpp_star_role() -> bool:
	if not await prepare_cpp_attack(91,"star_bolt"): return false
	const ROLES = preload("res://tools/content/generated/run_schema.gd").ENUMS.VisualRole
	check(ROLES.StarBolt!=ROLES.EnemyPolygon,"星弾と画像なしの敵の表示役割を分ける")
	var fired: Dictionary = cpp_bridge.command("dev_fire_star_bolt",{"position":cpp_origin,"angle":0.0,"speed":100.0,"damage":4.0})
	if not fired.ok: cpp_session.free(); return false
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1600,-500,1400,1000)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	var stars: Array = frame.batches.filter(func(batch): return presentation.frame_view.visuals[batch.visual_id].role==ROLES.StarBolt)
	check(stars.size()==1 and presentation.frame_view.apply_frame(frame),"生成済みの星形メッシュを新しい表示役割で通常画面へ渡す")
	await get_tree().process_frame
	if stars.size()==1:
		check(presentation.frame_view.batches.has(stars[0].visual_id),"星弾の専用一括表示を選ぶ")
	cpp_session.free()
	await get_tree().process_frame
	return true

func check_cpp_friend_debris() -> void:
	if not await prepare_cpp_attack(94,"friend_debris"): return
	var source: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin+Vector2(100,0)}).value
	var empty: Dictionary = cpp_bridge.checkpoint()
	var fixture: Dictionary = cpp_bridge.command("dev_debris_on_death",{"source_id":source,"count":1,"speed":100.0,"damage":2.0})
	check(fixture.ok,"開発用の撃破元へ破片生成を予約する")
	if not fixture.ok: cpp_session.free(); return
	check(cpp_core.fire_shot(cpp_origin,0.0,100.0,{"speed":1000.0,"life":1.0}),"破片を生成する敵へ味方弾を発射する")
	cpp_core.step_projectiles(0.1)
	var pieces: Array = cpp_core.projectiles_snapshot().filter(func(p): return p.kind==1)
	check(pieces.size()==1 and is_equal_approx(pieces[0].age,0.1),"撃破で後ろへ追加された破片も同じ更新で移動する")
	check(pieces.size()==1 and pieces[0].hit_ids.has(source),"破片は撃破元の命中済みIDを引き継ぐ")
	cpp_core.step_projectiles(0.1)
	var state: Array = cpp_core.projectiles_snapshot()
	check(state[0].trail.size()==2 and state[0].angle!=0.0,"破片が回転して通った位置を残す")
	var held: Dictionary = cpp_bridge.checkpoint()
	check(held.ok,"飛んでいる破片と軌跡を値で保持する")
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(frame.shapes.any(func(s): return s.kind==ENUMS.RenderShapeKind.FriendDebris and s.trail.size()==2),"破片の形と軌跡を表示用の値へ渡す")
	check(presentation.frame_view.apply_frame(frame),"破片の形と軌跡を通常画面で描く")
	await get_tree().process_frame
	cpp_core.step_projectiles(1.0)
	check(cpp_core.projectiles_snapshot().is_empty(),"破片が寿命で消える")
	var events: Array = cpp_bridge.read_frame().value.events
	check(events.any(func(e): return e.type==&"debris_trail" and e.payload.points.size()>1),"消えた破片は軌跡の終了表示を通知する")
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	check(not presentation.frame_view._debris_trails.is_empty(),"終了後の軌跡を表示側が保持して描く")
	cpp_bridge.restore(held.value)
	check(cpp_core.projectiles_snapshot()==state,"破片の速度・角度・軌跡・命中済みIDを復元する")
	cpp_bridge.restore(empty.value)
	var scattered: Dictionary = cpp_bridge.command("dev_scatter_hull",{"source_id":source,"direction":Vector2.RIGHT,"speed":100.0,"damage":2.0,"shatter_depth":2})
	check(scattered.ok,"星屑の破片を型付き生成器から出す")
	cpp_core.step_projectiles(0.1)
	var dust: Array = cpp_core.projectiles_snapshot()
	check(not dust.is_empty() and dust.all(func(p): return p.trail.is_empty() and p.shatter_depth==2),"星屑は通常の軌跡を作らず連鎖の深さを保つ")
	frame = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	check(presentation.frame_view.apply_frame(frame),"星屑の点と尾を通常画面で描く")
	await get_tree().process_frame
	cpp_bridge.restore(empty.value)
	var pumped: Dictionary = cpp_bridge.command("dev_burst_debris",{"position":cpp_origin,"count":2,"speed":100.0,"damage":2.0,"armor_count":1})
	check(pumped.ok,"ポンプ由来の装甲と敵の破片を生成する")
	cpp_core.step_projectiles(0.1)
	check(cpp_core.projectiles_snapshot().all(func(p): return p.trail.is_empty()),"ポンプ由来の破片は通常の軌跡を作らない")
	frame = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	check(presentation.frame_view.apply_frame(frame),"ポンプ由来の破片を通常画面で描く")
	await get_tree().process_frame
	cpp_bridge.release_checkpoint(held.value)
	cpp_bridge.release_checkpoint(empty.value)
	cpp_session.free()

func check_cpp_friend_hull() -> void:
	if not await prepare_cpp_attack(95,"friend_hull"): return
	var source: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin-Vector2(200,0)}).value
	var empty: Dictionary = cpp_bridge.checkpoint()
	var params := {"position":cpp_origin,"velocity":Vector2(1000,0),"radius":10.0,"damage":10.0,"life":1.0,"knock":300.0,"angle":0.7,"definition_id":"drifter","source_id":source}
	var fired: Dictionary = cpp_bridge.command("dev_fire_hull",params)
	check(fired.ok,"元の敵の外観とIDを持つ船体弾を生成する")
	if not fired.ok: cpp_session.free(); return
	cpp_core.step_projectiles(0.05)
	var state: Array = cpp_core.projectiles_snapshot()
	check(state[0].pos.distance_to(cpp_origin+Vector2(50,0))<0.001 and state[0].source_id==source and state[0].source_definition>0,"船体弾は元のIDを保って直進する")
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(frame.shapes.any(func(s): return s.kind==ENUMS.RenderShapeKind.FriendHull and s.visual_id>0 and not s.saw),"船体弾へ元の敵の外観の参照を渡す")
	check(presentation.frame_view.apply_frame(frame),"元の敵の船体を通常画面で描く")
	await get_tree().process_frame
	cpp_bridge.command("dev_remove",{"entity_id":source})
	var held: Dictionary = cpp_bridge.checkpoint()
	check(held.ok,"元の敵が退場した後も船体弾を保持する")
	var near: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin+Vector2(120,0)}).value
	var far: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin+Vector2(220,0)}).value
	cpp_core.step_projectiles(0.2)
	var events: Array = cpp_bridge.read_frame().value.events
	var hits: Array = events.filter(func(e): return e.type==&"combat_damage" and e.payload.cause==&"towShot")
	check(hits.size()==2 and hits[0].payload.target_id==near and hits[1].payload.target_id==far,"船体弾は近い敵から順に連続命中する")
	check(cpp_core.projectiles_snapshot().size()==1 and cpp_core.projectiles_snapshot()[0].hit_ids.has(source),"船体弾は貫通して元のIDの命中済み記録を残す")
	cpp_bridge.restore(held.value)
	check(cpp_core.projectiles_snapshot()==state,"船体弾の外観・元ID・角度・寿命・命中済みIDを復元する")
	cpp_bridge.restore(empty.value)
	var saw: Dictionary = cpp_bridge.command("dev_fire_saw",{"position":cpp_origin,"velocity":Vector2(500,0),"radius":18.0,"damage":10.0,"life":1.0})
	check(saw.ok,"丸鋸を船体弾の生成器から出す")
	cpp_core.step_projectiles(0.1)
	check(is_equal_approx(cpp_core.projectiles_snapshot()[0].angle,1.4),"丸鋸は14rad/sで回る")
	frame = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	check(frame.shapes.any(func(s): return s.kind==ENUMS.RenderShapeKind.FriendHull and s.saw and s.hull_points.size()==24) and presentation.frame_view.apply_frame(frame),"丸鋸の24頂点の歯を通常画面で描く")
	await get_tree().process_frame
	cpp_bridge.restore(empty.value)
	params.position = Vector2(-300,0)
	params.velocity = Vector2(1000,0)
	check(cpp_bridge.command("dev_fire_hull",params).ok,"天体へ向かう船体弾を生成する")
	cpp_core.step_projectiles(0.5)
	check(cpp_core.projectiles_snapshot().is_empty(),"船体弾は天体に当たって消える")
	cpp_bridge.restore(held.value)
	cpp_core.step_projectiles(1.0)
	check(cpp_core.projectiles_snapshot().is_empty(),"船体弾は寿命で消える")
	cpp_bridge.release_checkpoint(held.value)
	cpp_bridge.release_checkpoint(empty.value)
	cpp_session.free()

func check_cpp_zone() -> void:
	var library: Resource = load("res://.content/attack_visuals.res")
	var original: Dictionary = library.get_meta("looks").duplicate(true)
	var looks: Dictionary = original.duplicate(true)
	var phase_scene := "res://scenes/attacks/zone_reticle.tscn"
	looks[phase_scene]["Hit"] = QuadMesh.new()
	looks[phase_scene]["Fade"] = QuadMesh.new()
	library.set_meta("looks",looks)
	if not await prepare_cpp_attack(97,"zone"):
		library.set_meta("looks",original)
		return
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	var source: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin-Vector2(300,0)}).value
	var target: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin+Vector2(60,0)}).value
	var token: int = cpp_core.passive_attack("zone_owner",source)
	var params := {"position":cpp_origin,"radius":80.0,"delay":0.2,"damage":8.0,"enemy_damage":2.0,"style":1,"owner_id":source,"budget":token}
	var fired: Dictionary = cpp_bridge.command("dev_fire_zone",params)
	check(fired.ok and token>0,"発生元の枠を保持して範囲攻撃を生成する")
	if not fired.ok: cpp_session.free(); library.set_meta("looks",original); return
	cpp_core.step_hazards(0.1)
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	check(frame.shapes.any(func(s): return s.kind==ENUMS.RenderShapeKind.Zone and s.time<s.delay) and presentation.frame_view.apply_frame(frame),"範囲の照準予告を通常画面で描く")
	check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp),"予告中は機体へ当てない")
	await get_tree().process_frame
	cpp_bridge.command("dev_remove",{"entity_id":source})
	cpp_core.advance_attack_budget(1.0)
	check(cpp_core.attack_budget_snapshot().groups.size()==1 and cpp_core.hazards_snapshot().size()==1,"発生元の退場後も予告と残留枠を保つ")
	var held: Dictionary = cpp_bridge.checkpoint()
	var saved: Array = cpp_core.hazards_snapshot()
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin,"velocity":Vector2.ZERO})
	cpp_core.step_hazards(0.11)
	var events: Array = cpp_bridge.read_frame().value.events
	check(events.filter(func(e): return e.type==&"combat_damage" and e.payload.cause==&"chain" and e.payload.target_id==target).size()==1,"発動時に範囲の敵へ一度だけ誘爆する")
	check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-8.0),"発動時に円と機体半径で一度だけ命中する")
	check(events.any(func(e): return e.type==&"attack_visual_end" and e.payload.phase=="Hit"),"図形のあるHitだけを通知する")
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	check(not presentation.frame_view._attack_ends.is_empty(),"命中後のHit図形を通常画面へ渡す")
	cpp_core.step_hazards(0.02)
	check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-8.0) and cpp_bridge.read_frame().value.events.all(func(e): return e.type!=&"explode"),"発動後は表示を残して機体と敵へ重ねて当てない")
	check(cpp_bridge.restore(held.value).ok and cpp_core.hazards_snapshot()==saved,"予告時刻・誘爆値・未命中・所有枠を復元する")
	if zone_fade_only: mute_checks = false
	cpp_core.step_hazards(0.5)
	events = cpp_bridge.read_frame().value.events
	check(cpp_core.hazards_snapshot().is_empty() and events.any(func(e): return e.type==&"attack_visual_end" and e.payload.phase=="Fade"),"終了時にFadeを通知し範囲を消す")
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	if zone_fade_only:
		check(not presentation.frame_view._attack_ends.is_empty(),"終了後のFade図形を通常画面へ渡す")
		cpp_bridge.release_checkpoint(held.value)
		cpp_session.free()
		library.set_meta("looks",original)
		return
	cpp_core.advance_attack_budget(2.0)
	check(cpp_core.attack_budget_snapshot().groups.is_empty(),"終了した範囲の所有枠を解放する")
	for style in [0,2,3,4,5,6,7]:
		check(cpp_bridge.command("dev_fire_zone",{"position":cpp_origin+Vector2(style*30,0),"radius":45.0,"delay":0.0,"damage":0.0,"style":style}).ok,"種類ごとの範囲表示を生成する: %d" % style)
	cpp_core.step_hazards(0.01)
	frame = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	check(presentation.frame_view.apply_frame(frame),"通常・雷・噛み・わし・ほうおう・ボマー・ポンプの発動表示を描く")
	await get_tree().process_frame
	cpp_core.step_hazards(0.3)
	frame = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	presentation.frame_view.apply_frame(frame)
	check(cpp_core.hazards_snapshot().is_empty() and presentation.frame_view._zone_bursts.size()==3 and presentation.frame_view._zone_bursts.values().all(func(b): return not b._items.is_empty()),"火球の表示寿命は当たりの終了後も独立して残る")
	cpp_bridge.release_checkpoint(held.value)
	cpp_session.free()
	library.set_meta("looks",original)

func check_cpp_cross() -> void:
	if not await prepare_cpp_attack(98,"cross"): return
	var source: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin-Vector2(300,0)}).value
	var token: int = cpp_core.passive_attack("cross_owner",source)
	var params := {"position":cpp_origin,"angle":0.23,"length":280.0,"width":12.0,"delay":0.2,"active":0.4,"damage":8.0,"owner_id":source,"budget":token}
	var fired: Dictionary = cpp_bridge.command("dev_fire_cross",params)
	check(fired.ok,"発生元から4本の十字ビームを生成する")
	if not fired.ok: cpp_session.free(); return
	var beams: Array = cpp_core.hazards_snapshot()
	check(beams.size()==4 and fired.value.size()==4,"十字の4辺を独立したビーム行にする")
	for k in 4:
		check(beams[k].pos==cpp_origin and is_equal_approx(beams[k].angle,params.angle+k*PI/2.0) and is_equal_approx(beams[k].length,params.length),"辺%dの発生位置・向き・長さを保つ" % k)
	cpp_core.step_hazards(0.1)
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	check(frame.shapes.size()==4 and frame.shapes.all(func(s): return s.kind==ENUMS.RenderShapeKind.Circle) and presentation.frame_view.apply_frame(frame),"4辺の予告を通常画面へ渡す")
	await get_tree().process_frame
	var saved: Array = cpp_core.hazards_snapshot()
	var held: Dictionary = cpp_bridge.checkpoint()
	for k in 4:
		if k>0: cpp_bridge.restore(held.value)
		cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2.from_angle(params.angle+k*PI/2.0)*200.0,"velocity":Vector2.ZERO})
		cpp_core.step_hazards(0.15)
		check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-8.0) and cpp_core.hazards_snapshot().filter(func(h): return h.hit).size()==1,"有効時間に辺%dだけが命中する" % k)
		if k==0:
			frame = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
			check(frame.shapes.size()==4 and frame.shapes.all(func(s): return s.kind==ENUMS.RenderShapeKind.Polyline) and presentation.frame_view.apply_frame(frame),"発動した十字の4本の光を通常画面で描く")
			await get_tree().process_frame
	cpp_bridge.restore(held.value)
	check(cpp_core.hazards_snapshot()==saved,"4辺の時刻・向き・未命中・所有枠をまとめて復元する")
	cpp_bridge.command("dev_remove",{"entity_id":source})
	check(cpp_core.hazards_snapshot().is_empty(),"発生元が退場したら4辺とも掃除する")
	cpp_bridge.restore(held.value)
	cpp_core.step_hazards(0.6)
	check(cpp_core.hazards_snapshot().is_empty(),"有効時間の終わりに十字の4辺を掃除する")
	cpp_core.advance_attack_budget(2.0)
	check(cpp_core.attack_budget_snapshot().groups.is_empty(),"4辺の残留枠をすべて解放する")
	cpp_bridge.release_checkpoint(held.value)
	cpp_session.free()

func check_cpp_flood() -> void:
	if not await prepare_cpp_attack(99,"flood"): return
	var source: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin-Vector2(300,0)}).value
	var token: int = cpp_core.passive_attack("flood_owner",source)
	var params := {"position":cpp_origin,"angle":0.0,"length":280.0,"width":20.0,"spread":0.25,"delay":0.2,"active":0.4,"damage":8.0,"owner_id":source,"budget":token}
	var fired: Dictionary = cpp_bridge.command("dev_fire_flood",params)
	check(fired.ok,"発生元から広がる水流を生成する")
	if not fired.ok: cpp_session.free(); return

	cpp_core.step_hazards(0.1)
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	check(frame.shapes.size()==1 and frame.shapes[0].kind==ENUMS.RenderShapeKind.Flood and frame.shapes[0].time<frame.shapes[0].delay and presentation.frame_view.apply_frame(frame),"水流の広がる予告を通常画面で描く")
	var water: Dictionary = presentation.frame_view._flood_displays.values()[0]
	var material: ShaderMaterial = water.node.material
	check(is_equal_approx(material.get_shader_parameter("half0"),params.width*0.5) and is_equal_approx(material.get_shader_parameter("slope"),tan(params.spread)) and is_equal_approx(material.get_shader_parameter("beam_len"),params.length),"予告の根元の片側幅・広がり・長さを実判定と同じ値にする")
	await get_tree().process_frame
	var saved: Array = cpp_core.hazards_snapshot()
	var held: Dictionary = cpp_bridge.checkpoint()
	var ship_radius: float = cpp_bridge.read_frame().value.ui.ship_radius
	var reach: float = params.width*0.5+180.0*tan(params.spread)+ship_radius
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(180,reach+0.1),"velocity":Vector2.ZERO})
	cpp_core.step_hazards(0.15)
	check(not cpp_core.hazards_snapshot()[0].hit and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp),"水流の広がる幅の外は命中を消費しない")
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(180,reach-0.1),"velocity":Vector2.ZERO})
	cpp_core.step_hazards(0.05)
	check(cpp_core.hazards_snapshot()[0].hit and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-8.0),"水流の広がる幅の内へ入ると命中する")
	frame = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	check(frame.shapes.size()==1 and frame.shapes[0].time>=frame.shapes[0].delay and presentation.frame_view.apply_frame(frame),"命中後も有効時間の水流を描き続ける")
	await get_tree().process_frame
	cpp_core.step_hazards(0.05)
	check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-8.0),"水流は命中後に重ねて機体へ当てない")
	cpp_bridge.restore(held.value)
	check(cpp_core.hazards_snapshot()==saved,"水流の広がり・時刻・所有者・未命中状態を復元する")
	for along: float in [-ship_radius,params.length+ship_radius]:
		cpp_bridge.restore(held.value)
		cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(along,0),"velocity":Vector2.ZERO})
		cpp_core.step_hazards(0.15)
		check(cpp_core.hazards_snapshot()[0].hit,"採用済みの接触境界を水流にも適用する: %s" % along)
	cpp_bridge.restore(held.value)
	cpp_bridge.command("dev_remove",{"entity_id":source})
	check(cpp_core.hazards_snapshot().is_empty() and cpp_bridge.latest_frame().value.events.all(func(e): return e.type!=&"flood_end"),"予告中に発生元が退場すると霧を出さず掃除する")
	cpp_bridge.restore(held.value)
	cpp_core.step_hazards(0.6)
	check(cpp_core.hazards_snapshot().is_empty(),"水流は有効期間の終わりに当たりを消す")
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	check(presentation.frame_view._flood_tails.size()==1 and is_equal_approx(presentation.frame_view._flood_tails[0].life,1.4),"当たりが消えた後に独立した1.4秒の霧を描く")
	var tail: Dictionary = presentation.frame_view._flood_tails[0]
	check(is_equal_approx(tail.node.material.get_shader_parameter("half0"),params.width*0.5) and is_equal_approx(tail.node.material.get_shader_parameter("slope"),tan(params.spread)),"終わりの水と霧にも同じ広がりを渡す")
	await get_tree().process_frame
	var later: Dictionary = cpp_bridge.latest_frame().value.duplicate(true)
	later.ui.world_time += 1.5
	presentation.frame_view.update_effects(later,0.0)
	check(presentation.frame_view._flood_tails.is_empty(),"霧は表示寿命で消える")
	cpp_core.advance_attack_budget(2.0)
	check(cpp_core.attack_budget_snapshot().groups.is_empty(),"水流の終了で所有枠を解放する")
	cpp_bridge.release_checkpoint(held.value)
	cpp_session.free()

func check_cpp_light_lances() -> void:
	var duplicator: TraitDef = load("res://data/traits/T37_duplicator.tres")
	var original: Dictionary = duplicator.params.duplicate(true)
	duplicator.params.chance_by_level = [1.0,1.0,1.0,1.0,1.0]
	duplicator.params.angle_min = 0.0
	duplicator.params.angle_max = 0.0
	var ready: bool = await prepare_cpp_attack(100,"light_lances")
	duplicator.params = original
	if not ready: return
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	cpp_bridge.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5})
	var far: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin-Vector2(200,0)}).value
	var near: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin-Vector2(100,0)}).value
	var empty: Dictionary = cpp_bridge.checkpoint()
	var params := {"position":cpp_origin,"direction":Vector2.LEFT,"length":300.0,"width":120.0,"damage":1.0,"knock":0.0}
	var fired: Dictionary = cpp_bridge.command("dev_fire_light_lances",params)
	check(fired.ok and fired.value.size()==3,"元を登録して左右の複製を待ち列から順に生成する")
	if not fired.ok: cpp_session.free(); return
	var events: Array = cpp_bridge.latest_frame().value.events
	var hits: Array = events.filter(func(e): return e.type==&"combat_damage" and e.payload.cause==&"critBeam")
	check(hits.size()==6,"元と複製の3本がそれぞれ貫通して即時命中する")
	if hits.size()==6:
		check(hits[0].payload.target_id==near and hits[1].payload.target_id==far and hits[2].payload.target_id==near and hits[3].payload.target_id==far and hits[4].payload.target_id==near and hits[5].payload.target_id==far,"元の距離順命中を終えてから複製を1本ずつ距離順に解決する")
		check(is_equal_approx(hits[0].payload.requested,1.0) and is_equal_approx(hits[2].payload.requested,0.8),"複製だけにT37の威力を掛ける")
	check(events[0].type==&"duplicate" and events.filter(func(e): return e.type==&"critical_lance").size()==3 and events.filter(func(e): return e.type==&"hit").all(func(e): return not e.payload.crit),"分裂通知を先に出し、発射通知とno_critを保つ")
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	presentation._present_cpp(0.0)
	check(presentation.frame_view._critical_lances!=null and presentation.frame_view._critical_lances.shots.size()==3 and presentation.frame_view._lance_hits.size()==6,"発射・貫通・敵の火花をC++通知から通常画面で描く")
	await get_tree().process_frame
	var state: Dictionary = cpp_bridge.command("dev_light_lances_state",{}).value
	check(state.items.size()==3 and state.flying_count==3 and state.pending==0 and state.items.all(func(l): return l.hits.size()==2 and is_equal_approx(l.life,0.5)),"槍の独立した命中集合と寿命を同時数に含める")
	var held: Dictionary = cpp_bridge.checkpoint()
	var stepped: Dictionary = cpp_bridge.step(1.0/120.0,cpp_bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var after: Dictionary = cpp_bridge.command("dev_light_lances_state",{}).value
	if lances_tick_only: mute_checks = false
	check(stepped.ok and after.items[0].life<state.items[0].life and after.items[0].from==state.items[0].from and after.items[0].hits==state.items[0].hits,"世界更新では寿命だけが進み再命中や始点の移動をしない")
	if lances_tick_only:
		cpp_bridge.release_checkpoint(held.value)
		cpp_bridge.release_checkpoint(empty.value)
		lances_finished = true
		cpp_session.free()
		return
	check(cpp_bridge.restore(held.value).ok and cpp_bridge.command("dev_light_lances_state",{}).value==state,"元・複製の向き・威力・寿命・命中IDを復元する")
	check(cpp_bridge.command("dev_tick_light_lances",{"world_dt":0.5}).value.items.is_empty(),"世界時間の寿命で槍を回収する")
	presentation.frame_view.update_effects(cpp_bridge.latest_frame().value,0.51)
	check(presentation.frame_view._critical_lances.shots.is_empty() and presentation.frame_view._lance_flashes.is_empty() and presentation.frame_view._lance_hits.is_empty(),"飛行と発射・命中の演出も寿命で消える")
	cpp_bridge.restore(empty.value)
	cpp_bridge.command("dev_remove_trait",{"id":"T37"})
	var births := []
	for n in 216: births.append({"position":cpp_origin+Vector2(0,400),"velocity":Vector2.ZERO,"damage":0.0,"life":1.0})
	cpp_bridge.command("dev_friend_births",{"births":births})
	cpp_bridge.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5})
	cpp_bridge.command("dev_debris_on_death",{"source_id":near,"count":1,"speed":0.0,"damage":0.0})
	params.length = 100.0
	params.damage = 10000.0
	cpp_bridge.command("dev_fire_light_lances",params)
	state = cpp_bridge.command("dev_light_lances_state",{}).value
	check(state.items.size()==3 and state.flying_count==220 and state.pending==0 and cpp_core.projectiles_snapshot().filter(func(s): return s.kind==1).size()==1,"未処理の槍2本も同時数へ数え、元の命中が作る破片を上限越えで複製しない")
	cpp_bridge.release_checkpoint(held.value)
	cpp_bridge.release_checkpoint(empty.value)
	lances_finished = true
	cpp_session.free()

func prepare_cpp_duplicator_attack(index_number: int,name: String) -> bool:
	var definition: TraitDef = load("res://data/traits/T37_duplicator.tres")
	var saved: Dictionary = definition.params.duplicate(true)
	definition.params.chance_by_level = [1.0,1.0,1.0,1.0,1.0]
	definition.params.angle_min = 0.0
	definition.params.angle_max = 0.0
	var ready: bool = await prepare_cpp_attack(index_number,name)
	definition.params = saved
	if not ready: return false
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	return cpp_bridge.command("dev_grant_equipment",{"kind":"trait","id":"T37","levels":5}).ok

func check_cpp_burst_debris() -> bool:
	if not await prepare_cpp_duplicator_attack(101,"burst_debris"): return false
	var source: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin}).value
	var emitted: Dictionary = cpp_bridge.command("dev_burst_debris",{"position":cpp_origin,"source_id":source,"count":2,"speed":100.0,"damage":2.0,"armor_count":1})
	check(emitted.ok,"破砕片の元をまとめて完成してから複製する")
	var state: Array = cpp_core.projectiles_snapshot()
	check(state.size()==6,"元の破砕片2件のあとで複製4件を生成する")
	if state.size()!=6: cpp_session.free(); return false
	check(state.map(func(p): return String(p.type))==["pump","drifter","pump","pump","drifter","drifter"],"完成した装甲と敵の種別を出生順に複製へ引き継ぐ")
	check(state.all(func(p): return p.hit_ids==[source]) and state[2].pos==state[0].pos and state[4].pos==state[1].pos and is_equal_approx(state[2].damage,1.6),"複製へ元ID・位置・T37の威力を引き継ぐ")
	var events: Array = cpp_bridge.latest_frame().value.events
	check(events.size()==3 and events[0].type==&"hull_scatter" and events[1].type==&"duplicate" and events[1].payload.pos==state[0].pos and events[2].payload.pos==state[1].pos,"全生成後の破砕通知から元ごとの分裂通知へ順に進む")
	check(cpp_core.attack_budget_snapshot().groups.is_empty(),"味方の破砕片は敵の攻撃予算を使わない")
	cpp_session.free()
	return true

func check_cpp_scatter_hull() -> bool:
	if not await prepare_cpp_attack(102,"scatter_hull"): return false
	for kind in [2,3]:
		cpp_bridge.command("dev_add_rock",{"position":cpp_origin+Vector2(0,kind*100),"kind":kind,"size":20.0,"manual":true})
	cpp_bridge.command("dev_stream_rocks",{"center":cpp_origin,"half":Vector2(640,480),"dt":0.1})
	var rocks: Array = cpp_bridge.command("dev_field_query",{"action":"rocks"}).value
	for rock: Dictionary in rocks:
		var scattered: Dictionary = cpp_bridge.command("dev_scatter_hull",{"source_id":rock.enemy_id,"direction":Vector2.RIGHT,"speed":100.0,"damage":1.0})
		check(not scattered.ok and cpp_core.projectiles_snapshot().is_empty(),"フィールド由来の岩を船体の破片へ変えない: %d" % rock.kind)
	var raw: int = cpp_bridge.command("dev_spawn",{"definition_id":"meteor","position":cpp_origin-Vector2(100,0)}).value
	check(cpp_bridge.command("dev_scatter_hull",{"source_id":raw,"direction":Vector2.RIGHT,"speed":100.0,"damage":1.0}).ok,"フィールド番号のない生成個体は定義名だけで除外しない")
	cpp_session.free()
	return true

func check_cpp_fling_corpse() -> bool:
	if not await prepare_cpp_duplicator_attack(103,"fling_corpse"): return false
	var source: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin}).value
	var corpse: Dictionary = cpp_core.enemies_snapshot().filter(func(e): return e.id==source)[0]
	cpp_bridge.command("dev_kill",{"entity_id":source,"cause":"debug"})
	var near: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin+Vector2(100,0)}).value
	var far: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin+Vector2(200,0)}).value
	var fired: Dictionary = cpp_bridge.command("dev_fling_corpse",{"source_id":source,"velocity":Vector2(1000,0),"damage":2.0,"radius_mult":1.5,"knock_mult":0.0,"life_mult":0.5})
	check(fired.ok,"開発用の登録入口から死体を投射する")
	if not fired.ok: cpp_session.free(); return false
	var shots: Array = cpp_core.projectiles_snapshot()
	check(shots.size()==3 and shots.all(func(p): return p.cause==&"corpse" and p.pos==cpp_origin and p.hit_ids==[source] and is_equal_approx(p.life,0.45) and is_equal_approx(p.radius,maxf(10.0,corpse.radius*0.6)*1.5) and p.knock==0.0),"元と複製へ死体の位置・半径・元IDと投射倍率を写す")
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	check(frame.shapes.size()==3 and frame.shapes.all(func(s): return s.debris_style==ENUMS.DebrisStyle.Stardust) and presentation.frame_view.apply_frame(frame),"投射した死体と複製を星屑の形で通常画面へ渡す")
	await get_tree().process_frame
	cpp_core.step_projectiles(0.25)
	var events: Array = cpp_bridge.read_frame().value.events
	var hits: Array = events.filter(func(e): return e.type==&"combat_damage" and e.payload.cause==&"corpse")
	check(hits.size()==6 and hits[0].payload.target_id==near and hits[1].payload.target_id==far and events.all(func(e): return e.type!=&"duplicate"),"死体は距離順に貫通し、命中から再複製しない")
	cpp_bridge.command("dev_remove",{"entity_id":source})
	var state: Array = cpp_core.projectiles_snapshot()
	var held: Dictionary = cpp_bridge.checkpoint()
	check(held.ok and state.all(func(p): return p.hit_ids.has(near) and p.hit_ids.has(far)),"元の敵を消しても投射と命中済みIDを保持する")
	cpp_core.step_projectiles(1.0)
	check(cpp_core.projectiles_snapshot().is_empty(),"投射した死体と複製は寿命で消える")
	check(cpp_bridge.restore(held.value).ok and cpp_core.projectiles_snapshot()==state,"死体投射の位置・速度・角度・命中ID・寿命を復元する")
	cpp_bridge.release_checkpoint(held.value)
	cpp_session.free()
	return true

func check_cpp_saw() -> bool:
	if not await prepare_cpp_duplicator_attack(104,"saw"): return false
	cpp_bridge.command("dev_add_rock",{"position":cpp_origin,"kind":3,"size":20.0,"manual":true})
	cpp_bridge.command("dev_stream_rocks",{"center":cpp_origin,"half":Vector2(640,480),"dt":0.1})
	var rocks: Array = cpp_bridge.command("dev_field_query",{"action":"rocks"}).value
	var source: int = rocks[0].enemy_id
	var actor: Dictionary = cpp_core.enemies_snapshot().filter(func(e): return e.id==source)[0]
	var edge: float = actor.radius+cpp_config.ship_radius+2.0
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(edge,0),"velocity":Vector2(800,0)})
	cpp_core.collide_ship(cpp_origin-Vector2(edge,0),cpp_config.ship_radius)
	var shots: Array = cpp_core.projectiles_snapshot()
	check(shots.size()==3 and shots.all(func(p): return p.saw and p.type==&"saw" and p.cause==&"saw" and p.source_id==-1 and p.source_definition==0 and p.pierce and p.vel.x>0 and is_equal_approx(p.radius,actor.radius) and is_equal_approx(p.life,cpp_config.saw_life)),"接触した丸鋸から同じ半径と寿命の元1本・複製2本を生成する")
	if shots.size()!=3: cpp_session.free(); return false
	check(is_equal_approx(shots[0].vel.x,cpp_config.saw_speed),"接触の速度が遅くても丸鋸の指定速度で投射する")
	cpp_bridge.command("dev_stream_rocks",{"center":cpp_origin,"half":Vector2(640,480),"dt":0.1})
	rocks = cpp_bridge.command("dev_field_query",{"action":"rocks"}).value
	check(rocks[0].destroyed and rocks[0].enemy_id==0,"投射元のフィールド丸鋸を再出現させない")
	var near: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin+Vector2(250,0)}).value
	var far: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin+Vector2(350,0)}).value
	cpp_core.step_projectiles(0.1)
	var moving: Array = cpp_core.projectiles_snapshot()
	check(moving.all(func(p): return is_equal_approx(p.angle,1.4)) and moving[0].pos.distance_to(shots[0].pos+shots[0].vel*0.1)<0.001,"丸鋸の元と複製は14rad毎秒で回り連続した軌道を進む")
	var held: Dictionary = cpp_bridge.checkpoint()
	check(held.ok,"投射元が消えた丸鋸と複製の値を保持する")
	cpp_core.step_projectiles(0.2)
	var events: Array = cpp_bridge.read_frame().value.events
	var hits: Array = events.filter(func(e): return e.type==&"combat_damage" and e.payload.cause==&"saw")
	check(hits.size()>=2 and hits[0].payload.target_id==near and hits[1].payload.target_id==far and cpp_core.projectiles_snapshot().size()==3,"丸鋸は近い敵から貫通し命中から再複製しない")
	cpp_core.step_projectiles(2.0)
	check(cpp_core.projectiles_snapshot().is_empty(),"丸鋸の元と複製は指定の寿命で消える")
	check(cpp_bridge.restore(held.value).ok and cpp_core.projectiles_snapshot()==moving,"丸鋸の回転・軌道・寿命・元情報を復元する")
	cpp_bridge.release_checkpoint(held.value)
	cpp_session.free()
	return true

func check_cpp_cosmic_arrow() -> bool:
	if not await prepare_cpp_attack(105,"cosmic_arrow"): return false
	var fired: Dictionary = cpp_bridge.command("dev_fire_light_arrow",{"position":cpp_origin,"angle":0.0,"speed":100.0,"radius":12.0,"travel":400.0,"damage":8.0,"cosmic":true,"length":100.0})
	if not fired.ok: check(false,"コズミック矢を保持確認用に生成する"); cpp_session.free(); return false
	cpp_core.step_hostiles(0.1)
	var state: Array = cpp_core.hostiles_snapshot()
	var held: Dictionary = cpp_bridge.checkpoint()
	check(held.ok and state[0].kind==ENUMS.HostileKind.CosmicArrow,"コズミック矢の種類と長い尾を保持する")
	cpp_core.step_hostiles(0.15)
	check(cpp_bridge.restore(held.value).ok and cpp_core.hostiles_snapshot()==state,"コズミック矢の種類・尾・位置・速度・寿命へ復帰する")
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	check(frame.shapes.size()==1 and frame.shapes[0].cosmic and frame.shapes[0].cosmic_color_a!=frame.shapes[0].cosmic_color_b and frame.shapes[0].cosmic_star_count>0,"復帰後もコズミック専用の配色と星を使う")
	cpp_bridge.release_checkpoint(held.value)
	cpp_session.free()
	return true

func check_cpp_rings() -> bool:
	if not await prepare_cpp_attack(106,"rings"): return false
	var params := {"position":cpp_origin,"angle":0.0,"arc":PI,"radius":500.0,"speed":100.0,"width":12.0,"delay":0.2,"damage":7.0,"layers":3,"interval":0.15,"gap":0.2,"gap_arc":0.1,"gap_step":0.4}
	var emitted: Dictionary = cpp_bridge.command("dev_fire_wave",params)
	if not emitted.ok: check(false,"複数輪の保持確認を生成する"); cpp_session.free(); return false
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin-Vector2(45,0),"velocity":Vector2.ZERO})
	cpp_core.step_hazards(0.8)
	var state: Array = cpp_core.hazards_snapshot()
	check(state.size()==3 and state.all(func(h): return h.hit),"重なった3層の輪がそれぞれ独立した一回の接触を持つ")
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-700,1500,1400)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	check(frame.shapes.size()==3 and presentation.frame_view.apply_frame(frame) and presentation.frame_view._wave_displays.size()==3,"3層の輪を独立した表示として通常画面へ渡す")
	await get_tree().process_frame
	var held: Dictionary = cpp_bridge.checkpoint()
	cpp_core.step_hazards(4.5)
	check(cpp_core.hazards_snapshot().size()==2,"遅延の小さい最初の輪から消える")
	cpp_core.step_hazards(0.1)
	check(cpp_core.hazards_snapshot().size()==1,"2番目の輪は自身の時刻で消える")
	cpp_core.step_hazards(0.2)
	check(cpp_core.hazards_snapshot().is_empty(),"最後の輪も自身の時刻で消える")
	check(cpp_bridge.restore(held.value).ok and cpp_core.hazards_snapshot()==state,"複数輪の時刻・切れ目・独立した命中状態をまとめて復元する")
	cpp_bridge.release_checkpoint(held.value)
	cpp_session.free()
	return true

func check_cpp_shell() -> bool:
	if not await prepare_cpp_attack(107,"shell"): return false
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	var owner: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin}).value
	var token: int = cpp_core.passive_attack("shell_owner",owner)
	var empty: Dictionary = cpp_bridge.checkpoint()
	var params := {"source_id":owner,"angle":0.0,"speed":100.0,"radius":12.0,"range":100.0,"burst":90.0,"damage":8.0,"budget":token,"contents":PackedStringArray(["drifter","meteor","drifter"])}
	var fired: Dictionary = cpp_bridge.command("dev_fire_shell",params)
	check(fired.ok,"発生元から収納内容を持つ圧縮弾を生成する")
	if not fired.ok: cpp_session.free(); return false
	var initial: Dictionary = cpp_core.hostiles_snapshot()[0]
	cpp_core.step_hostiles(0.2)
	var state: Array = cpp_core.hostiles_snapshot()
	check(state[0].pos.distance_to(initial.pos+Vector2(20,0))<0.001 and state[0].contents.size()==3 and state[0].full==1.0,"圧縮弾が直進し収納順と満杯の値を保つ")
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-500,1500,1000)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	check(frame.shapes.size()==1 and frame.shapes[0].kind==ENUMS.RenderShapeKind.Shell and presentation.frame_view.apply_frame(frame),"収納物を持つ圧縮弾を通常画面で描く")
	await get_tree().process_frame
	var display: Node = presentation.frame_view._shell_displays.values()[0]
	check(display._mesh.material.get_shader_parameter("contents_count")>=2.0,"収納物の種類を制作済みの圧縮弾shaderへ渡す")
	cpp_bridge.command("dev_remove",{"entity_id":owner})
	cpp_core.advance_attack_budget(1.0)
	check(cpp_core.attack_budget_snapshot().groups.size()==1,"発射元の退場後も圧縮弾の残留枠を保つ")
	var held: Dictionary = cpp_bridge.checkpoint()
	cpp_core.step_hostiles(1.0)
	check(cpp_core.hostiles_snapshot().is_empty() and cpp_core.hazards_snapshot().size()==1,"距離を飛びきると一度だけ破裂へ移す")
	var burst: Dictionary = cpp_core.hazards_snapshot()[0]
	check(burst.pos.distance_to(state[0].pos+Vector2(100,0))<0.001 and burst.style==ENUMS.ZoneStyle.Pump and burst.token==token,"破裂位置・ポンプの見た目・予算を引き継ぐ")
	cpp_bridge.command("dev_ship_motion",{"position":burst.pos,"velocity":Vector2.ZERO})
	check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp),"圧縮弾そのものは機体へ直接ダメージを与えない")
	cpp_core.step_hazards(0.01)
	check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-8.0),"破裂した円だけが機体へダメージを与える")
	var events: Array = cpp_bridge.read_frame().value.events
	check(events.any(func(e): return e.type==&"combat_player_damage" and e.payload.source=="drifter" and e.payload.cause==&"blast"),"発射元の退場後も破裂の発生元と原因名を記録する")
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	check(presentation.frame_view._zone_bursts.has(ENUMS.ZoneStyle.Pump),"破裂を独立したポンプの爆発として通常画面で描く")
	await get_tree().process_frame
	cpp_core.step_hostiles(0.05)
	check(cpp_core.hazards_snapshot().size()==1,"消えた圧縮弾から二度目の破裂を作らない")
	cpp_core.step_hazards(0.3)
	cpp_core.advance_attack_budget(2.0)
	check(cpp_core.hazards_snapshot().is_empty() and cpp_core.attack_budget_snapshot().groups.is_empty(),"破裂の終了で最後の残留枠を解放する")
	check(cpp_bridge.restore(held.value).ok and cpp_core.hostiles_snapshot()==state,"収納内容・満杯値・口の位置・飛行状態を復元する")
	cpp_bridge.restore(empty.value)
	params.speed = 1000.0
	params.range = 1000.0
	cpp_bridge.command("dev_fire_shell",params)
	var start: Vector2 = cpp_core.hostiles_snapshot()[0].pos
	cpp_bridge.command("dev_ship_motion",{"position":start+Vector2(180,0),"velocity":Vector2.ZERO})
	cpp_core.step_hostiles(0.3)
	check(cpp_core.hostiles_snapshot().is_empty() and cpp_core.hazards_snapshot().size()==1 and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp),"機体への衝突でも直接傷つけず一度だけ破裂する")
	cpp_bridge.restore(empty.value)
	cpp_bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W05","levels":1})
	cpp_bridge.command("dev_fire_shell",params)
	cpp_bridge.command("dev_ship_motion",{"position":start+Vector2(180,0),"velocity":Vector2.ZERO})
	cpp_core.step_hostiles(0.3)
	check(cpp_core.hostiles_snapshot().is_empty() and cpp_core.hazards_snapshot().is_empty() and cpp_bridge.read_frame().value.events.any(func(e): return e.type==&"barrier_hit"),"バリアに消された圧縮弾は破裂しない")
	cpp_bridge.restore(empty.value)
	cpp_bridge.command("dev_fire_shell",params)
	cpp_bridge.command("dev_clear_hostile",{})
	check(cpp_core.hostiles_snapshot().is_empty() and cpp_core.hazards_snapshot().is_empty(),"一括消去では圧縮弾と収納情報だけを消す")
	cpp_bridge.release_checkpoint(held.value)
	cpp_bridge.release_checkpoint(empty.value)
	cpp_session.free()
	return true

func cpp_motion_for(id: int) -> Dictionary:
	var rows: Array = cpp_core.enemy_motion_snapshot().filter(func(e): return e.id==id)
	return rows[0] if not rows.is_empty() else {}

func check_cpp_aquarius() -> bool:
	var tuning := {"aquarius":{"speed":0.0,"params.beams":4,"params.telegraph":0.3,"params.beam_time":0.4,"params.beam_len":500.0,"params.beam_width":10.0,"params.beam_spread":0.2,"params.bullet_dmg":5.0,"params.rest":0.2,"params.fire_interval":0.6,"params.approach":300.0}}
	if not await prepare_cpp_attack(108,"aquarius",PackedStringArray(["aquarius","drifter"]),tuning): return false
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(220,0),"velocity":Vector2.ZERO})
	cpp_core.set_attack_formation_mode(true)
	var actor: int = cpp_bridge.command("dev_spawn",{"definition_id":"aquarius","position":cpp_origin}).value
	var initial: Dictionary = cpp_bridge.checkpoint()
	cpp_core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	cpp_core.step(0.7)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.MOVE and cpp_core.hazards_snapshot().is_empty(),"予算がなければみずがめ座は予告を始めない")
	cpp_core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	cpp_core.step(0.7)
	var hazards: Array = cpp_core.hazards_snapshot()
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.WINDUP and hazards.size()==4 and is_equal_approx(cpp_motion_for(actor).timer,0.7),"編集した4方向と予告・照射時間で攻撃を始める")
	if hazards.size()!=4: cpp_session.free(); return false
	for k in 4:
		check(is_equal_approx(hazards[k].angle,k*PI/2.0) and is_equal_approx(hazards[k].length,500.0) and is_equal_approx(hazards[k].half_width,5.0) and is_equal_approx(hazards[k].arc,0.2),"水流%dの方向・長さ・片側幅・広がりを編集値から生成する" % k)
	var events: Array = cpp_bridge.read_frame().value.events
	check(events.any(func(e): return e.type==&"aquarius_aim" and e.payload.count==4 and e.payload.id==actor),"予告の演出値を個体IDとともに通知する")
	cpp_core.step(0.15)
	cpp_core.step_hazards(0.15)
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-700,1500,1400)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	check(frame.shapes.size()==4 and presentation.frame_view.apply_frame(frame) and presentation.frame_view._aquarius.size()==5,"広角の水の予告とみずがめ座の口の光を通常画面で描く")
	await get_tree().process_frame
	var pending: Dictionary = cpp_bridge.checkpoint()
	var before: Array = cpp_core.enemy_motion_snapshot()
	var warned: Array = cpp_core.hazards_snapshot()
	cpp_core.step(0.2)
	cpp_core.step_hazards(0.2)
	events = cpp_bridge.read_frame().value.events
	check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-5.0) and events.filter(func(e): return e.type==&"enemy_laser_fire" and e.payload.id==actor).size()==1,"予告を越えると一度だけ照射を通知して水流が当たる")
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	check(presentation.frame_view._flood_groups.size()==1 and presentation.pipeline._waves.size()==1,"一斉の4本を同じ表示グループにして衝撃演出を1回だけ出す")
	await get_tree().process_frame
	check(cpp_bridge.restore(pending.value).ok and cpp_core.enemy_motion_snapshot()==before and cpp_core.hazards_snapshot()==warned,"敵の時刻・向き・chargeと4本の予告・表示グループを復元する")
	cpp_core.step(0.2)
	cpp_core.step_hazards(0.2)
	var previous_waves: int = presentation.pipeline._waves.size()
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	check(presentation.frame_view._flood_groups.size()==1 and presentation.pipeline._waves.size()==previous_waves+1,"復帰後の一斉照射も演出を1回だけ再開する")
	cpp_core.step(0.4)
	cpp_core.step_hazards(0.4)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.RECOVER and cpp_core.hazards_snapshot().is_empty(),"照射を終えると水流を消して編集した休みに入る")
	cpp_core.step(0.25)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.MOVE,"休みを終えると接近へ戻る")
	cpp_bridge.restore(initial.value)
	cpp_core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	cpp_core.step(0.7)
	cpp_bridge.command("dev_kill",{"entity_id":actor,"cause":"debug"})
	check(cpp_core.hazards_snapshot().is_empty(),"予告中にみずがめ座を倒すと付いた水流をすべて消す")
	cpp_bridge.command("dev_remove",{"entity_id":actor})
	var replacement: int = cpp_bridge.command("dev_spawn",{"definition_id":"aquarius","position":cpp_origin}).value
	check(replacement!=actor and cpp_motion_for(replacement).mode==EnemyTable.Mode.MOVE and cpp_motion_for(replacement).timer==0.0 and cpp_motion_for(replacement).charge==0.0,"行を使い直した別個体へ予告やchargeを漏らさない")
	cpp_bridge.restore(pending.value)
	cpp_core.step(0.2)
	cpp_core.step_hazards(0.2)
	cpp_bridge.command("dev_kill",{"entity_id":actor,"cause":"debug"})
	check(cpp_core.hazards_snapshot().is_empty(),"照射中に発生元を先に消しても水流の所有参照を残さない")
	cpp_bridge.release_checkpoint(pending.value)
	cpp_bridge.release_checkpoint(initial.value)
	cpp_session.free()
	return true

func check_cpp_cross_enemy() -> bool:
	var tuning := {"cross":{"speed":0.0,"params.telegraph":0.2,"params.beam_time":0.3,"params.beam_len":500.0,"params.beam_width":20.0,"params.bullet_dmg":6.0,"params.rest":0.1,"params.fire_interval":0.5,"params.stand_off":180.0,"params.align_tol":8.0}}
	if not await prepare_cpp_attack(109,"cross_enemy",PackedStringArray(["cross","drifter"]),tuning): return false
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(160,160),"velocity":Vector2.ZERO})
	cpp_core.set_attack_formation_mode(true)
	var actor: int = cpp_bridge.command("dev_spawn",{"definition_id":"cross","position":cpp_origin}).value
	cpp_core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	cpp_core.step(0.6)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.MOVE and cpp_core.hazards_snapshot().is_empty(),"予算がなければ十字の予告を始めない")
	cpp_core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	cpp_core.step(0.6)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.MOVE and cpp_core.hazards_snapshot().is_empty(),"機体と縦横がそろう前は射撃へ進まない")
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(180,0),"velocity":Vector2.ZERO})
	cpp_core.step(0.01)
	var hazards: Array = cpp_core.hazards_snapshot()
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.WINDUP and hazards.size()==4,"機体とそろうと4辺の予告を生成する")
	if hazards.size()!=4: cpp_session.free(); return false
	for k in 4:
		check(is_equal_approx(hazards[k].angle,k*PI/2.0) and is_equal_approx(hazards[k].length,500.0) and is_equal_approx(hazards[k].half_width,10.0) and is_equal_approx(hazards[k].delay,0.2) and is_equal_approx(hazards[k].active,0.3),"辺%dは編集値を使って固定の縦横へ伸びる" % k)
	check(cpp_core.attack_budget_snapshot().groups.size()==1 and cpp_core.attack_budget_snapshot().used==1.0,"4辺は同じ攻撃予算の枠を共有する")
	cpp_core.step(0.1)
	cpp_core.step_hazards(0.1)
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-700,1500,1400)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	check(presentation.frame_view.apply_frame(frame) and presentation.frame_view._cross.size()==9,"十字の予告線と中心の光を通常画面で描く")
	await get_tree().process_frame
	var pending: Dictionary = cpp_bridge.checkpoint()
	var before: Array = cpp_core.enemy_motion_snapshot()
	var warned: Array = cpp_core.hazards_snapshot()
	cpp_core.step(0.11)
	cpp_core.step_hazards(0.11)
	var events: Array = cpp_bridge.read_frame().value.events
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.RECOVER and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-6.0) and events.filter(func(e): return e.type==&"enemy_laser_fire" and e.payload.id==actor).size()==1,"予告後に一度照射し攻撃中の休みに入る")
	frame = cpp_bridge.read_render(Rect2(-1700,-700,1500,1400)).value
	check(frame.shapes.size()==4 and frame.shapes.all(func(h): return h.kind==ENUMS.RenderShapeKind.Polyline) and presentation.frame_view.apply_frame(frame),"4辺のビームを通常画面で描く")
	await get_tree().process_frame
	check(cpp_bridge.restore(pending.value).ok and cpp_core.enemy_motion_snapshot()==before and cpp_core.hazards_snapshot()==warned,"十字の予告と個体の時刻・chargeを復元する")
	cpp_core.step(0.11)
	cpp_core.step_hazards(0.11)
	cpp_core.step(0.31)
	cpp_core.step_hazards(0.31)
	check(cpp_core.hazards_snapshot().is_empty() and cpp_motion_for(actor).mode==EnemyTable.Mode.RECOVER,"ビームの終了後も編集した休みの残りを保つ")
	cpp_core.step(0.1)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.MOVE and is_equal_approx(cpp_motion_for(actor).fire_t,0.5),"休みの終わりから編集した射撃間隔で再開する")
	cpp_bridge.restore(pending.value)
	cpp_bridge.command("dev_kill",{"entity_id":actor,"cause":"debug"})
	check(cpp_core.hazards_snapshot().is_empty(),"予告中に発生元を先に倒すと4辺を掃除する")
	cpp_bridge.command("dev_remove",{"entity_id":actor})
	var replacement: int = cpp_bridge.command("dev_spawn",{"definition_id":"cross","position":cpp_origin}).value
	check(replacement!=actor and cpp_motion_for(replacement).mode==EnemyTable.Mode.MOVE and cpp_motion_for(replacement).timer==0.0 and cpp_motion_for(replacement).charge==0.0,"行を再利用した別個体へ予告や攻撃状態を漏らさない")
	cpp_bridge.restore(pending.value)
	cpp_core.step(0.11)
	cpp_core.step_hazards(0.11)
	cpp_bridge.command("dev_kill",{"entity_id":actor,"cause":"debug"})
	check(cpp_core.hazards_snapshot().is_empty(),"照射中に発生元を消しても付いた4辺を残さない")
	cpp_bridge.release_checkpoint(pending.value)
	cpp_session.free()
	return true

func check_cpp_bomber() -> bool:
	var tuning := {"bomber":{"speed":80.0,"params.blast_delay":0.3,"params.blast_dmg":7.0,"params.blast_radius":150.0,"params.rush":2.0,"params.trigger":200.0}}
	if not await prepare_cpp_attack(110,"bomber",PackedStringArray(["bomber","drifter"]),tuning): return false
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(400,0),"velocity":Vector2.ZERO})
	cpp_core.set_attack_formation_mode(true)
	var actor: int = cpp_bridge.command("dev_spawn",{"definition_id":"bomber","position":cpp_origin}).value
	cpp_core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	cpp_core.step(0.05)
	var moving: Dictionary = cpp_motion_for(actor)
	check(moving.mode==EnemyTable.Mode.MOVE and Vector2(cpp_core.enemies_snapshot()[0].vel[0],cpp_core.enemies_snapshot()[0].vel[1]).length()>0.0,"遠い機体へ追跡し、投下型には変えない")
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-700,1500,1400)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	check(presentation.frame_view.apply_frame(frame) and presentation.frame_view._bomber.size()==5,"追跡中は導火線の火花を描く")
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(120,0),"velocity":Vector2.ZERO})
	cpp_core.step(0.05)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.MOVE,"予算がなければ近距離でも予告を始めない")
	cpp_core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	cpp_core.step(0.01)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.WINDUP and is_equal_approx(cpp_motion_for(actor).timer,0.3),"編集した近距離と待ち時間で自爆予告へ入る")
	cpp_core.step(0.05)
	var warning: Dictionary = cpp_motion_for(actor)
	check(Vector2(cpp_core.enemies_snapshot()[0].vel[0],cpp_core.enemies_snapshot()[0].vel[1]).length()>80.0 and warning.charge>0.0,"カウントダウン中もrush倍の速さへ加速して接近する")
	frame = cpp_bridge.read_render(Rect2(-1700,-700,1500,1400)).value
	check(frame.batches.any(func(b): return b.ids.has(actor) and b.colors[b.ids.find(actor)].g==1.0) and presentation.frame_view.apply_frame(frame) and presentation.frame_view._bomber.is_empty(),"予告は3回の赤い装甲明滅へ切り替える")
	await get_tree().process_frame
	var pending: Dictionary = cpp_bridge.checkpoint()
	var before: Array = cpp_core.enemy_motion_snapshot()
	cpp_core.step(0.26)
	var hazards: Array = cpp_core.hazards_snapshot()
	var events: Array = cpp_bridge.read_frame().value.events
	check(hazards.size()==1 and hazards[0].radius==150.0 and hazards[0].damage==7.0 and hazards[0].style==ENUMS.ZoneStyle.Bomber,"カウントダウンの終わりに編集した自爆範囲を1つ生成する")
	check(events.filter(func(e): return e.type==&"bomber_explode").size()==1 and not events.any(func(e): return e.type==&"kill" or e.type==&"xp_drop"),"自爆通知は1回で撃破報酬を出さない")
	if hazards.size()!=1: cpp_session.free(); return false
	var center: Vector2 = hazards[0].pos
	cpp_bridge.command("dev_remove",{"entity_id":actor})
	var replacement: int = cpp_bridge.command("dev_spawn",{"definition_id":"bomber","position":cpp_origin+Vector2(500,300)}).value
	check(replacement!=actor and cpp_motion_for(replacement).mode==EnemyTable.Mode.MOVE and cpp_motion_for(replacement).timer==0.0 and cpp_motion_for(replacement).charge==0.0 and cpp_core.hazards_snapshot().size()==1,"発生元を先に解放し同じ行を使い直しても爆風は独立して残る")
	cpp_bridge.command("dev_ship_motion",{"position":center,"velocity":Vector2.ZERO})
	cpp_core.step_hazards(0.01)
	check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-7.0),"発生元の退場後も自爆の当たりを1回だけ処理する")
	frame = cpp_bridge.read_render(Rect2(-1700,-700,1500,1400)).value
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	check(presentation.frame_view.apply_frame(frame) and frame.shapes.any(func(shape): return shape.kind==ENUMS.RenderShapeKind.Zone and shape.zone_style==ENUMS.ZoneStyle.Bomber),"通常画面でBomber専用の爆風を描く")
	await get_tree().process_frame
	cpp_core.step_hazards(0.4)
	check(cpp_core.hazards_snapshot().is_empty(),"単体の自爆範囲が寿命で終了する")
	check(cpp_bridge.restore(pending.value).ok and cpp_core.enemy_motion_snapshot()==before,"自爆途中の時間・向き・加速・chargeを保持から復元する")
	cpp_bridge.command("dev_kill",{"entity_id":actor,"cause":"debug"})
	cpp_core.step(0.4)
	events = cpp_bridge.read_frame().value.events
	check(cpp_core.hazards_snapshot().is_empty() and not events.any(func(e): return e.type==&"bomber_explode"),"予告中に倒すと自爆と自爆通知を出さない")
	cpp_bridge.restore(pending.value)
	cpp_bridge.command("dev_remove",{"entity_id":actor})
	cpp_core.step(0.4)
	check(cpp_core.hazards_snapshot().is_empty(),"予告中に発生元を先に消しても古い参照から自爆しない")
	cpp_session.free()
	return true

func check_cpp_phoenix() -> bool:
	var retry3 := "--cpp-phoenix-fix3" in OS.get_cmdline_user_args()
	var retry2 := retry3 or "--cpp-phoenix-fix2" in OS.get_cmdline_user_args()
	var retry := retry2 or "--cpp-phoenix-fix" in OS.get_cmdline_user_args()
	mute_checks = retry
	var tuning := {"phoenix":{"params.retreat_distance":1000.0,"params.retreat_time":0.2,"params.telegraph":0.3,"params.dive_time":0.2,"params.impact_radius":150.0,"params.impact_time":0.5,"params.impact_dmg":9.0,"params.recover_time":0.2}}
	if not await prepare_cpp_attack(111,"phoenix",PackedStringArray(["phoenix","drifter"]),tuning): return false
	mute_checks = retry3
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	var aim := cpp_origin+Vector2(200,0)
	cpp_bridge.command("dev_ship_motion",{"position":aim,"velocity":Vector2.ZERO})
	cpp_core.set_motion_context(aim,cpp_origin,Vector2(3000,3000))
	cpp_core.set_attack_formation_mode(true)
	var actor: int = cpp_bridge.command("dev_spawn",{"definition_id":"phoenix","position":cpp_origin}).value
	cpp_core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	cpp_core.step(0.05)
	if not retry: check(cpp_core.enemies_snapshot()[0].pos==[cpp_origin.x,cpp_origin.y] and cpp_motion_for(actor).mode==EnemyTable.Mode.MOVE and cpp_motion_for(actor).timer==0.0,"予算を待つほうおう座は位置を保つ")
	cpp_core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	cpp_core.step(0.1)
	if not retry2: check(cpp_motion_for(actor).mode==EnemyTable.Mode.MOVE and is_equal_approx(Vector2(cpp_core.enemies_snapshot()[0].pos[0],cpp_core.enemies_snapshot()[0].pos[1]).distance_to(cpp_origin),500.0) and cpp_core.enemies_snapshot()[0].vel==[0.0,0.0],"編集した離脱距離を残り時間の補間で進み、速度加算しない")
	if not retry: check(cpp_core.attack_budget_snapshot().groups.size()==1 and cpp_core.attack_budget_snapshot().used==1.0,"離脱中も同じ攻撃枠を保持する")
	cpp_core.step(0.1)
	var warning: Dictionary = cpp_motion_for(actor)
	if not retry2: check(warning.mode==EnemyTable.Mode.WINDUP and warning.anchor.is_finite() and warning.anchor.distance_to(aim)>0.01 and is_equal_approx(warning.timer,0.3),"離脱を終えると遅れた照準の着地点を固定して予告する")
	var fixed: Vector2 = warning.anchor
	var retreated := Vector2(cpp_core.enemies_snapshot()[0].pos[0],cpp_core.enemies_snapshot()[0].pos[1])
	var pending: Dictionary = cpp_bridge.checkpoint()
	var before: Array = cpp_core.enemy_motion_snapshot()
	cpp_bridge.command("dev_ship_motion",{"position":aim+Vector2(300,100),"velocity":Vector2.ZERO})
	cpp_core.step(0.15)
	check(cpp_motion_for(actor).anchor==fixed and is_equal_approx(cpp_motion_for(actor).charge,0.5),"予告中に相手が移動しても着地点を追い直さない")
	var frame: Dictionary = cpp_bridge.read_render(Rect2(fixed-Vector2(250,250),Vector2(500,500))).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	if not retry: check(frame.batches.all(func(b): return not b.ids.has(actor)) and frame.phoenix.size()==7 and presentation.frame_view.apply_frame(frame) and presentation.frame_view._phoenix_visual._frame_values==frame.phoenix,"本体が画面外でも着地点の影と専用shaderの火の粉を描く")
	await get_tree().process_frame
	cpp_core.step(0.16)
	if not retry: check(cpp_motion_for(actor).mode==EnemyTable.Mode.DASH and is_equal_approx(cpp_motion_for(actor).timer,0.2),"編集した予告が終わると突入へ切り替える")
	cpp_core.step(0.1)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.DASH and Vector2(cpp_core.enemies_snapshot()[0].pos[0],cpp_core.enemies_snapshot()[0].pos[1]).is_equal_approx(retreated.lerp(fixed,0.5)),"突入も固定点まで残り時間に合わせて補間する")
	cpp_core.step(0.1)
	var hazards: Array = cpp_core.hazards_snapshot()
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.RECOVER and hazards.size()==1 and hazards[0].pos==fixed and hazards[0].radius==150.0 and is_equal_approx(hazards[0].active,0.5),"着地で編集した範囲と有効時間の炎を生成して停止する")
	if hazards.size()!=1: cpp_session.free(); return false
	cpp_bridge.command("dev_ship_motion",{"position":fixed,"velocity":Vector2.ZERO})
	cpp_core.step_hazards(0.01)
	check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-9.0),"着地炎の共通被弾を発動時に1回だけ処理する")
	frame = cpp_bridge.read_render(Rect2(fixed-Vector2(300,300),Vector2(600,600))).value
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	check(presentation.frame_view.apply_frame(frame) and frame.shapes.any(func(shape): return shape.kind==ENUMS.RenderShapeKind.Zone and shape.zone_style==ENUMS.ZoneStyle.Phoenix),"着地の炎を通常画面で表示する")
	await get_tree().process_frame
	cpp_core.step(0.21)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.MOVE,"休みが終わると次の離脱へ戻る")
	cpp_bridge.command("dev_kill",{"entity_id":actor,"cause":"debug"})
	cpp_bridge.command("dev_remove",{"entity_id":actor})
	var replacement: int = cpp_bridge.command("dev_spawn",{"definition_id":"phoenix","position":cpp_origin+Vector2(300,300)}).value
	check(replacement!=actor and cpp_motion_for(replacement).mode==EnemyTable.Mode.MOVE and cpp_motion_for(replacement).anchor==Vector2.ZERO and cpp_motion_for(replacement).timer==0.0 and cpp_motion_for(replacement).charge==0.0 and cpp_core.hazards_snapshot().size()==1,"着地後の元個体を先に消し行を再利用しても炎は独立し着地点を漏らさない")
	cpp_core.step_hazards(0.5)
	check(cpp_core.hazards_snapshot().is_empty() and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-9.0),"余韻は追加命中せず指定した有効時間で終了する")
	check(cpp_bridge.restore(pending.value).ok and cpp_core.enemy_motion_snapshot()==before,"離脱先・固定着地点・段階・残り時間を保持から復元する")
	mute_checks = false
	cpp_bridge.command("dev_kill",{"entity_id":actor,"cause":"debug"})
	cpp_core.step(0.6)
	cpp_core.advance_attack_budget(1.0)
	check(cpp_core.hazards_snapshot().is_empty() and cpp_motion_for(actor).charge==0.0 and cpp_core.attack_budget_snapshot().used==0.0,"予告中の撃破で突入と炎を取り消し、chargeと攻撃枠を終了する")
	cpp_bridge.restore(pending.value)
	cpp_bridge.command("dev_remove",{"entity_id":actor})
	cpp_core.step(0.6)
	cpp_core.advance_attack_budget(1.0)
	check(cpp_core.hazards_snapshot().is_empty() and cpp_core.attack_budget_snapshot().used==0.0,"突入前に元個体を解放しても古い参照で炎を生成しない")
	cpp_session.free()
	return true

func check_cpp_aquila() -> bool:
	var tuning := {"aquila":{"speed":80.0,"turn":0.8,"params.fire_interval":0.3,"params.aim_time":0.2,"params.lock_time":0.2,"params.dash_speed":500.0,"params.dash_time":0.4,"params.drop_step":0.1,"params.blast_delay":0.2,"params.blast_radius":80.0,"params.bullet_dmg":6.0,"params.recover":0.2,"params.keep":300.0}}
	if not await prepare_cpp_attack(112,"aquila",PackedStringArray(["aquila","drifter"]),tuning): return false
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	var target := cpp_origin+Vector2(500,0)
	cpp_bridge.command("dev_ship_motion",{"position":target,"velocity":Vector2.ZERO})
	cpp_core.set_motion_context(target,cpp_origin,Vector2(1000,1000))
	cpp_core.set_attack_formation_mode(true)
	var actor: int = cpp_bridge.command("dev_spawn",{"definition_id":"aquila","position":cpp_origin}).value
	cpp_core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	cpp_core.step(0.4)
	var waiting: Dictionary = cpp_motion_for(actor)
	var cruising: Dictionary = cpp_core.enemies_snapshot()[0]
	check(waiting.mode==EnemyTable.Mode.MOVE and cruising.vel!=[0.0,0.0] and absf(cruising.facing)>0.01,"予算待ちも現在の機体へ直進せず旋回巡航する")
	cpp_bridge.command("dev_relocate",{"entity_id":actor,"position":cpp_origin})
	cpp_core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	cpp_core.step(0.31)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.WINDUP and is_equal_approx(cpp_motion_for(actor).timer,0.4),"編集した間隔の後に照準と固定待ちの予告へ入る")
	cpp_core.step(0.1)
	check(cpp_motion_for(actor).charge==0.0,"照準中はまだ進路を固定しない")
	cpp_core.step(0.11)
	var warning: Dictionary = cpp_motion_for(actor)
	var anchor := cpp_origin+Vector2(200,0)
	check(warning.anchor.is_equal_approx(anchor) and warning.charge>0.0,"現在の機体へ向く進路を編集した最大走行距離で固定する")
	var frame: Dictionary = cpp_bridge.read_render(Rect2(cpp_origin-Vector2(200,300),Vector2(1000,600))).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	check(frame.aquila.values.size()==9 and is_equal_approx(frame.aquila.values[6],50.0) and is_equal_approx(frame.aquila.values[7],80.0) and presentation.frame_view.apply_frame(frame) and presentation.frame_view._aquila==frame.aquila.values,"固定した終点までの線と編集した雷の間隔・半径を通常画面で描く")
	await get_tree().process_frame
	var pending: Dictionary = cpp_bridge.checkpoint()
	var before: Array = cpp_core.enemy_motion_snapshot()
	cpp_bridge.command("dev_ship_motion",{"position":target+Vector2(0,250),"velocity":Vector2.ZERO})
	cpp_core.step(0.1)
	check(cpp_motion_for(actor).anchor.is_equal_approx(anchor),"進路固定後に相手が動いても追い直さない")
	cpp_core.step(0.1)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.DASH and is_equal_approx(cpp_core.enemies_snapshot()[0].pos[0],cpp_origin.x+50.0) and cpp_core.hazards_snapshot().size()==2,"突入に入ったフレームから実dtだけ進み始点と50先へ雷を置く")
	cpp_core.step(0.3)
	var hazards: Array = cpp_core.hazards_snapshot()
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.RECOVER and is_equal_approx(cpp_core.enemies_snapshot()[0].pos[0],anchor.x) and hazards.size()==5,"固定終点で止まり50間隔で5個の雷を置く")
	if hazards.size()!=5: cpp_session.free(); return false
	for k in 5:
		check(hazards[k].pos.is_equal_approx(cpp_origin+Vector2(k*50,0)) and is_equal_approx(hazards[k].delay,0.2) and hazards[k].radius==80.0 and hazards[k].damage==6.0 and hazards[k].style==ENUMS.ZoneStyle.Aquila,"雷%dの実位置・予告時間・半径・威力を編集値から生成する" % k)
	cpp_core.step(0.21)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.MOVE and is_equal_approx(cpp_motion_for(actor).fire_t,0.3),"休止を終えると編集した間隔で巡航へ戻る")
	cpp_bridge.command("dev_kill",{"entity_id":actor,"cause":"debug"})
	cpp_bridge.command("dev_remove",{"entity_id":actor})
	var replacement: int = cpp_bridge.command("dev_spawn",{"definition_id":"aquila","position":cpp_origin+Vector2(600,300)}).value
	check(replacement!=actor and cpp_motion_for(replacement).anchor==Vector2.ZERO and cpp_motion_for(replacement).bud_t==0.0 and cpp_motion_for(replacement).charge==0.0 and cpp_core.hazards_snapshot().size()==5,"元個体を先に消し行を使い直しても雷は残り、固定終点や生成時刻を漏らさない")
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin,"velocity":Vector2.ZERO})
	cpp_core.step_hazards(0.21)
	check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-6.0),"発生元の退場後も遅延した雷が共通被弾へ通る")
	frame = cpp_bridge.read_render(Rect2(cpp_origin-Vector2(200,300),Vector2(1000,600))).value
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	check(presentation.frame_view.apply_frame(frame) and frame.shapes.filter(func(shape): return shape.kind==ENUMS.RenderShapeKind.Zone and shape.zone_style==ENUMS.ZoneStyle.Aquila).size()==5,"独立した5個の雷を通常画面で描く")
	await get_tree().process_frame
	cpp_core.step_hazards(0.4)
	check(cpp_core.hazards_snapshot().is_empty(),"置いた雷は攻撃寿命で終了する")
	check(cpp_bridge.restore(pending.value).ok and cpp_core.enemy_motion_snapshot()==before,"固定進路・段階・残り時間・次の雷時刻を保持から復元する")
	cpp_bridge.command("dev_kill",{"entity_id":actor,"cause":"debug"})
	cpp_core.step(0.6)
	check(cpp_core.hazards_snapshot().is_empty(),"予告中に倒すと突入と未生成の雷を取り消す")
	cpp_bridge.restore(pending.value)
	cpp_bridge.command("dev_remove",{"entity_id":actor})
	cpp_core.step(0.6)
	check(cpp_core.hazards_snapshot().is_empty(),"突入前に元個体を先に解放しても古い参照から雷を生成しない")
	cpp_bridge.restore(pending.value)
	cpp_bridge.command("dev_relocate",{"entity_id":actor,"position":Vector2(-260,0)})
	cpp_bridge.command("dev_ship_motion",{"position":Vector2(500,0),"velocity":Vector2.ZERO})
	cpp_core.set_motion_context(Vector2(500,0),Vector2(-3000,0),Vector2(320,180))
	cpp_core.step(0.31)
	cpp_core.step(0.21)
	var blocked: Vector2 = cpp_motion_for(actor).anchor
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.WINDUP and is_equal_approx(cpp_motion_for(actor).timer,0.19) and blocked.x> -260.0 and blocked.x< -100.0,"画面外でも実時間で予告し天体に当たる手前へ終点を切る")
	cpp_core.step(0.2)
	var stopped: Dictionary = cpp_core.enemies_snapshot()[0]
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.RECOVER and is_equal_approx(stopped.pos[0],blocked.x) and cpp_core.hazards_snapshot().all(func(h): return h.pos.x<=blocked.x+0.01),"天体で切った予告と実走行・最後の雷を同じ終点へそろえる")
	cpp_session.free()
	return true

func check_cpp_crab() -> bool:
	var tuning := {"crab":{"speed":40.0,"params.reach":300.0,"params.approach":400.0,"params.telegraph":0.2,"params.open_time":0.15,"params.bullet_dmg":5.0,"params.turn_angle":20.0}}
	if not await prepare_cpp_attack(113,"crab",PackedStringArray(["crab","drifter"]),tuning): return false
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(600,0),"velocity":Vector2.ZERO})
	cpp_core.set_attack_formation_mode(true)
	var actor: int = cpp_bridge.command("dev_spawn",{"definition_id":"crab","position":cpp_origin}).value
	cpp_core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	cpp_core.step(0.1)
	var walking: Dictionary = cpp_core.enemies_snapshot()[0]
	check(is_equal_approx(walking.facing,-PI/2.0) and walking.vel==[40.0,0.0] and cpp_motion_for(actor).buds==1,"出現時に横腹を向け、体に直交する方向へ編集した速さで歩く")
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(300,0),"velocity":Vector2.ZERO})
	cpp_core.step(0.1)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.MOVE and cpp_core.enemies_snapshot()[0].vel==[0.0,0.0],"薙ぎが届く近距離でも予算がなければ止まって待つ")
	cpp_core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	cpp_core.step(0.01)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.WINDUP and is_equal_approx(cpp_motion_for(actor).timer,0.2),"枠を取ると編集した予告時間で構える")
	cpp_core.step(0.1)
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-700,1500,1400)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	check(is_equal_approx(cpp_motion_for(actor).charge,0.5) and presentation.frame_view.apply_frame(frame) and presentation.frame_view._crab.size()==14,"本体と装甲を保ち、薙ぎの円と爪の予告を通常画面で描く")
	await get_tree().process_frame
	var pending: Dictionary = cpp_bridge.checkpoint()
	var before: Array = cpp_core.enemy_motion_snapshot()
	cpp_core.step(0.11)
	var hazards: Array = cpp_core.hazards_snapshot()
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.RECOVER and hazards.size()==1 and hazards[0].radius==180.0 and hazards[0].damage==5.0 and cpp_core.attack_snapshot()[0].attached,"予告を終えると横歩き方向へ本体に付いた薙ぎ払いを生成する")
	if hazards.size()!=1: cpp_session.free(); return false
	cpp_core.step_hazards(0.01)
	check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-5.0),"薙ぎ払いの円が共通の被弾を処理する")
	frame = cpp_bridge.read_render(Rect2(-1700,-700,1500,1400)).value
	check(presentation.frame_view.apply_frame(frame) and presentation.frame_view._crab[4]==EnemyTable.Mode.RECOVER,"薙ぎの振りと攻撃範囲を通常画面で描く")
	await get_tree().process_frame
	cpp_core.step(0.16)
	check(cpp_motion_for(actor).mode==EnemyTable.Mode.MOVE and cpp_core.hazards_snapshot().is_empty(),"開いた時間が終わると薙ぎを解放して横歩きへ戻る")
	check(cpp_bridge.restore(pending.value).ok and cpp_core.enemy_motion_snapshot()==before,"左右の歩行方向・段階・残り時間・薙ぎHandleを保持から復元する")
	cpp_bridge.command("dev_kill",{"entity_id":actor,"cause":"debug"})
	cpp_core.step(0.3)
	check(cpp_core.hazards_snapshot().is_empty(),"予告中に倒すと未発動の薙ぎを生成しない")
	cpp_bridge.restore(pending.value)
	cpp_core.step(0.11)
	cpp_bridge.command("dev_kill",{"entity_id":actor,"cause":"debug"})
	check(cpp_core.hazards_snapshot().is_empty(),"薙ぎの途中で倒すと付いた攻撃を終了する")
	cpp_bridge.command("dev_remove",{"entity_id":actor})
	var replacement: int = cpp_bridge.command("dev_spawn",{"definition_id":"crab","position":cpp_origin}).value
	check(replacement!=actor and cpp_motion_for(replacement).buds==1 and cpp_motion_for(replacement).sweep==0 and cpp_motion_for(replacement).timer==0.0 and cpp_motion_for(replacement).charge==0.0,"行を再利用した別個体へ薙ぎや予告を漏らさない")
	cpp_bridge.restore(pending.value)
	cpp_core.step(0.11)
	cpp_bridge.command("dev_remove",{"entity_id":actor})
	check(cpp_core.hazards_snapshot().is_empty(),"参照する発生元を先に解放しても薙ぎを残さない")
	cpp_session.free()
	return true

func check_cpp_gates() -> bool:
	var cases := {"drifter":"none","bomber":"solid","crab":"membrane","aquila":"ghost","phoenix":"immortal","cross":"claw","aquarius":"back","reticle":"guard"}
	var definitions := {}
	var tuning := {}
	var ids := PackedStringArray()
	for id: String in cases:
		var definition := (load("res://data/enemies/%s.tres" % id) as EnemyDef).duplicate(true) as EnemyDef
		definition.gate = StringName(cases[id])
		definitions[StringName(id)] = definition
		tuning[id] = {"hp":100.0,"armor":0.0,"speed":0.0,"weak_arc":0.0}
		ids.append(id)
	ids.append("shield")
	tuning.shield = {"hp":100.0,"armor":0.0,"speed":0.0}
	if not await prepare_cpp_attack(114,"gates",ids,tuning,definitions): return false
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	var empty: Dictionary = cpp_bridge.checkpoint()
	for id: String in cases:
		cpp_bridge.restore(empty.value)
		var actor: int = cpp_bridge.command("dev_spawn",{"definition_id":id,"position":cpp_origin}).value
		var spawned: Dictionary = cpp_bridge.checkpoint()
		var hp: float = cpp_core.enemies_snapshot()[0].hp
		var gate_name: String = cases[id]
		var shot_allowed := gate_name in ["none","solid","claw","back"]
		check(cpp_core.fire_shot(cpp_origin-Vector2(100,0),0.0,5.0,{"speed":1000.0,"r":2.0,"life":1.0,"knock":0.0}),"%sの射撃を生成する" % gate_name)
		cpp_core.step_projectiles(0.2)
		check(is_equal_approx(cpp_core.enemies_snapshot()[0].hp,hp-(5.0 if shot_allowed else 0.0)) and cpp_core.hostiles_snapshot().is_empty(),"%sは射撃の可否を守り、盾以外では反射しない" % gate_name)
		cpp_bridge.restore(spawned.value)
		cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(80,0),"velocity":Vector2(3000,0)})
		var bounced: bool = cpp_core.collide_ship(cpp_origin-Vector2(80,0),cpp_config.ship_radius)
		var after: Dictionary = cpp_core.enemies_snapshot()[0]
		var ram_allowed := gate_name in ["none","immortal","claw","back"]
		check(bounced==(gate_name=="solid") and (after.hp<hp)==ram_allowed,"%sは高速接触の貫通・すり抜け・反発を区別する" % gate_name)
		if gate_name=="immortal": check(after.dead==1,"不死ゲートは通った体当たりで残りHP以上を与える")
		cpp_bridge.restore(spawned.value)
		cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(80,0),"velocity":Vector2(50,0)})
		check(not cpp_core.collide_ship(cpp_origin-Vector2(80,0),cpp_config.ship_radius) and (cpp_core.enemies_snapshot()[0].hp<hp)==shot_allowed,"%sは低速接触を通常攻撃と同じ可否で扱う" % gate_name)
		if gate_name in ["claw","back"]:
			cpp_bridge.restore(spawned.value)
			var front: Dictionary = cpp_bridge.command("dev_damage",{"entity_id":actor,"amount":5.0,"cause":"shot","direction":Vector2.LEFT}).value
			check(front.reason=="damage_gate","%sの閉じた正面は射撃が通らない" % gate_name)
			cpp_bridge.command("dev_ship_motion",{"position":cpp_origin-Vector2(80,0),"velocity":Vector2(-3000,0)})
			check(cpp_core.collide_ship(cpp_origin+Vector2(80,0),cpp_config.ship_radius) and cpp_core.enemies_snapshot()[0].hp==hp,"%sの閉じた正面の体当たりは弾く" % gate_name)
		if gate_name in ["membrane","claw"]:
			cpp_bridge.restore(spawned.value)
			check(cpp_bridge.command("dev_enemy_combat",{"entity_id":actor,"mode":EnemyTable.Mode.RECOVER}).ok,"%sの開いた状態を構成する" % gate_name)
			var opened: Dictionary = cpp_bridge.command("dev_damage",{"entity_id":actor,"amount":5.0,"cause":"shot","direction":Vector2.LEFT}).value
			check(opened.reason=="applied" and opened.applied==5.0,"%sは開いている間に正面からも攻撃が通る" % gate_name)
	cpp_bridge.restore(empty.value)
	var normal: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin}).value
	cpp_bridge.command("dev_enemy_combat",{"entity_id":normal,"guard":1.0})
	check(cpp_bridge.command("dev_damage",{"entity_id":normal,"amount":5.0,"cause":"shot"}).value.reason=="guard" and cpp_bridge.command("dev_damage",{"entity_id":normal,"amount":5.0,"cause":"ram"}).value.reason=="guard","個体の無敵は射撃と体当たりの両方を拒否する")
	cpp_bridge.restore(empty.value)
	var shield: int = cpp_bridge.command("dev_spawn",{"definition_id":"shield","position":cpp_origin}).value
	var point: Dictionary = cpp_bridge.checkpoint()
	var shield_hp: float = cpp_core.enemies_snapshot()[0].hp
	var front: Dictionary = cpp_bridge.command("dev_damage",{"entity_id":shield,"amount":5.0,"cause":"shot","impact":cpp_origin+Vector2(30,0),"direction":Vector2.LEFT}).value
	var rear: Dictionary = cpp_bridge.command("dev_damage",{"entity_id":shield,"amount":5.0,"cause":"shot","impact":cpp_origin-Vector2(30,0),"direction":Vector2.RIGHT}).value
	check(front.reason=="damage_gate" and rear.applied==5.0,"盾の前面拒否と背面許可を共通判定へ接続する")
	cpp_bridge.restore(point.value)
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin-Vector2(80,0),"velocity":Vector2(-3000,0)})
	check(cpp_core.collide_ship(cpp_origin+Vector2(80,0),cpp_config.ship_radius) and cpp_core.enemies_snapshot()[0].hp==shield_hp,"盾の正面の高速接触を弾く")
	cpp_bridge.restore(point.value)
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin-Vector2(80,0),"velocity":Vector2(-50,0)})
	check(cpp_core.collide_ship(cpp_origin+Vector2(80,0),cpp_config.ship_radius) and cpp_core.enemies_snapshot()[0].hp==shield_hp,"盾の正面の低速接触も押し戻す")
	cpp_bridge.restore(point.value)
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(80,0),"velocity":Vector2(3000,0)})
	check(not cpp_core.collide_ship(cpp_origin-Vector2(80,0),cpp_config.ship_radius) and cpp_core.enemies_snapshot()[0].dead==1,"盾の背後の高速接触は盾を奪って倒す")
	cpp_session.free()
	return true

func cpp_enemy_for(id: int) -> Dictionary:
	var rows: Array = cpp_core.enemies_snapshot().filter(func(row): return row.id==id)
	return rows[0] if not rows.is_empty() else {}

func check_cpp_pump() -> bool:
	var final_only := "--cpp-pump-final" in OS.get_cmdline_user_args()
	var retry := final_only or "--cpp-pump-fix2" in OS.get_cmdline_user_args()
	mute_checks = retry
	var edible := (load("res://data/enemies/drifter.tres") as EnemyDef).duplicate(true) as EnemyDef
	edible.rank = 1
	var tuning := {"pump":{"hp":5.0,"speed":0.0,"turn":100.0,"params.store_max":2,"params.pull_radius":300.0,"params.pull":200.0,"params.swallow_reach":0.0,"params.swallow_interval":0.1,"params.telegraph":0.3,"params.lock_time":0.1,"params.shell_speed":300.0,"params.shell_r":12.0,"params.shell_range":600.0,"params.burst_radius":80.0,"params.bullet_dmg":7.0,"params.recover":0.2,"params.release_base":2,"params.release_per":1.0,"params.release_speed":100.0,"params.release_dmg":0.5,"params.release_radius":50.0},"drifter":{"speed":0.0},"splitling":{"speed":0.0},"swarm":{"speed":0.0},"bomber":{"hp":100.0,"speed":0.0}}
	var prepared := await prepare_cpp_attack(115,"pump",PackedStringArray(["pump","drifter","splitling","swarm","hydra_bite","bomber"]),tuning,{&"drifter":edible})
	mute_checks = final_only
	if not prepared: mute_checks = false; return false
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(500,0),"velocity":Vector2.ZERO})
	cpp_core.set_attack_formation_mode(true)
	cpp_core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	var owner: int = cpp_bridge.command("dev_spawn",{"definition_id":"pump","position":cpp_origin}).value
	var base_radius: float = cpp_enemy_for(owner).radius
	var target: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin+Vector2(200,0)}).value
	var exclusions: Array[int] = []
	for flags: Dictionary in [{"held":true},{"stone":1.0},{"shove_time":1.0},{"landmark":true},{"is_boss":true}]:
		var id: int = cpp_bridge.command("dev_spawn",{"definition_id":"drifter","position":cpp_origin+Vector2(10,30)}).value
		if flags.has("landmark") or flags.has("is_boss"):
			var command := flags.duplicate(); command.entity_id = id
			cpp_bridge.command("dev_enemy_combat",command)
		else: cpp_core.set_enemy_motion(id,flags)
		exclusions.append(id)
	exclusions.append(cpp_bridge.command("dev_spawn",{"definition_id":"swarm","position":cpp_origin+Vector2(10,30)}).value)
	exclusions.append(cpp_bridge.command("dev_spawn_part",{"parent_id":owner,"definition_id":"hydra_bite","position":cpp_origin+Vector2(10,30)}).value)
	var rival: int = cpp_bridge.command("dev_spawn",{"definition_id":"pump","position":cpp_origin-Vector2(50,0)}).value
	cpp_bridge.command("dev_add_rock",{"kind":0,"position":cpp_origin+Vector2(10,-50),"size":10.0,"manual":true})
	cpp_bridge.command("dev_stream_rocks",{"center":cpp_origin,"half":Vector2(640,360),"dt":0.01})
	cpp_core.step(0.05)
	check(cpp_motion_for(target).pump_owner_id==owner and cpp_enemy_for(target).pos[0]<cpp_origin.x+200.0 and cpp_enemy_for(target).vel==[0.0,0.0],"吸引口へ位置を直接1度進め、速度を0へ戻して所有者IDを結ぶ")
	if not retry: check(cpp_motion_for(rival).buds==0 and cpp_motion_for(owner).buds==0 and exclusions.all(func(id): return cpp_motion_for(id).pump_owner_id==0 and cpp_enemy_for(id).dead==0),"held・石化・shove・目印・ボス・rank0・部位・別Pumpと他所有の敵を吸い込まない")
	cpp_bridge.command("dev_remove",{"entity_id":rival})
	var owned: Dictionary = cpp_bridge.checkpoint()
	for flag: String in ["held","stone","shove_time"]:
		cpp_bridge.restore(owned.value)
		cpp_core.set_enemy_motion(target,{flag:true if flag=="held" else 1.0})
		cpp_core.step(0.01)
		if not retry: check(cpp_motion_for(target).pump_owner_id==0,"所有中の相手が%sになると吸引所有を解除する" % flag)
	cpp_bridge.restore(owned.value)
	cpp_core.set_enemy_motion(owner,{"held":true})
	cpp_core.step(0.01)
	if not retry: check(cpp_motion_for(target).pump_owner_id==0,"発生元が保持されて吸引できなくなると相手を解放する")
	cpp_bridge.restore(owned.value)
	cpp_bridge.command("dev_remove",{"entity_id":target})
	var replacement: int = cpp_bridge.command("dev_spawn",{"definition_id":"splitling","position":cpp_origin+Vector2(500,0)}).value
	cpp_core.step(0.01)
	if not retry: check(replacement!=target and cpp_motion_for(replacement).pump_owner_id==0 and cpp_motion_for(owner).buds==0,"吸引相手を先に解放し行を使い直しても古い対象を飲み込まない")
	cpp_bridge.restore(owned.value)
	var first: int = cpp_bridge.command("dev_spawn",{"definition_id":"splitling","position":cpp_origin+Vector2(10,0)}).value
	cpp_core.step(0.05)
	if not retry: check(cpp_motion_for(owner).stored_types==PackedStringArray(["splitling"]) and cpp_enemy_for(first).dead==1 and cpp_core.combat_snapshot().kills==0,"口に届いた種類だけを個体在庫へ入れ、撃破報酬なしで退場させる")
	var half: Dictionary = cpp_bridge.checkpoint()
	var half_state: Array = cpp_core.enemy_motion_snapshot()
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	cpp_bridge.collect_frame()
	presentation._present_cpp(0.0)
	var pump_displays: Array = presentation.frame_view.enemy_frames.values().filter(func(display): return display._pump!=null)
	check(pump_displays.size()==1 and pump_displays[0]._pump._bodies.size()==1 and is_equal_approx(pump_displays[0]._pump._bodies[0].material.get_shader_parameter("stored_full"),0.5) and pump_displays[0]._pump._winds[0].visible and pump_displays[0]._pump.swallows.size()==1,"既存の本体・塗装・法線と吸引風・飲み込みの表示を通常画面へつなぐ")
	await get_tree().process_frame
	cpp_bridge.command("dev_relocate",{"entity_id":owner,"position":cpp_origin+Vector2(0,100)})
	if not retry: check(cpp_motion_for(owner).stored_types==PackedStringArray(["splitling"]) and cpp_motion_for(target).pump_owner_id==0,"同じ個体の再配置は収納種類を保ち、吸引中の相手を解放する")
	cpp_bridge.command("dev_relocate",{"entity_id":owner,"position":cpp_origin})
	cpp_bridge.command("dev_relocate",{"entity_id":target,"position":cpp_origin+Vector2(10,0)})
	cpp_core.step(0.11)
	check(cpp_motion_for(owner).stored_types==PackedStringArray(["splitling","drifter"]) and cpp_motion_for(owner).mode==EnemyTable.Mode.WINDUP,"編集した収納上限で種類の順番を保って発射予告へ入る")
	cpp_core.step(0.05)
	check(is_equal_approx(cpp_motion_for(owner).timer,0.3) and cpp_core.hostiles_snapshot().is_empty(),"満杯でも攻撃枠がなければ予告時間と圧縮弾を進めない")
	cpp_core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(0,500),"velocity":Vector2.ZERO})
	cpp_core.step(0.1)
	var facing: float = cpp_enemy_for(owner).facing
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-700,1500,1400)).value
	mute_checks = false
	check(presentation.frame_view.apply_frame(frame) and pump_displays[0]._pump._bodies[0].material.get_shader_parameter("full")==1.0 and not pump_displays[0]._pump._winds[0].visible and cpp_enemy_for(owner).radius>base_radius,"満杯の予告では後部を膨らませて吸引風を止める")
	mute_checks = final_only
	await get_tree().process_frame
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(-500,0),"velocity":Vector2.ZERO})
	cpp_core.step(0.15)
	check(is_equal_approx(cpp_enemy_for(owner).facing,facing),"lock_timeに入ると向きを固定する")
	var loaded: Dictionary = cpp_bridge.checkpoint()
	var loaded_state: Array = cpp_core.enemy_motion_snapshot()
	cpp_core.step(0.06)
	var shells: Array = cpp_core.hostiles_snapshot()
	check(shells.size()==1 and shells[0].contents.size()==2 and shells[0].full==1.0 and shells[0].radius==12.0 and shells[0].burst==80.0 and cpp_motion_for(owner).buds==0 and cpp_motion_for(owner).mode==EnemyTable.Mode.RECOVER,"圧縮弾へ収納列・充填率・口位置を値コピーし、在庫を空にして反動を受ける")
	if shells.size()!=1: cpp_session.free(); return false
	cpp_core.step(0.21)
	mute_checks = false
	check(cpp_motion_for(owner).mode==EnemyTable.Mode.MOVE and is_equal_approx(cpp_enemy_for(owner).radius,base_radius),"発射後にしぼみ、編集した休止を終えて吸引へ戻る")
	mute_checks = final_only
	check(cpp_bridge.restore(loaded.value).ok and cpp_core.enemy_motion_snapshot()==loaded_state,"収納種類・所有参照・残り時間・固定方向を保持から復元する")
	cpp_bridge.command("dev_remove",{"entity_id":owner})
	cpp_core.step(0.4)
	check(cpp_core.hostiles_snapshot().is_empty(),"満杯の発生元を先に解放しても未発射の圧縮弾を生成しない")
	check(cpp_bridge.restore(half.value).ok and cpp_core.enemy_motion_snapshot()==half_state,"半分収納した状態も元の種類列と所有参照で復元する")
	var victim: int = cpp_bridge.command("dev_spawn",{"definition_id":"bomber","position":cpp_origin+Vector2(0,60)}).value
	var killed: Dictionary = cpp_bridge.command("dev_damage",{"entity_id":owner,"amount":10.0,"cause":"shot"}).value
	check(killed.killed and cpp_core.projectiles_snapshot().size()==3 and is_equal_approx(cpp_enemy_for(victim).hp,95.0) and cpp_motion_for(target).pump_owner_id==0 and cpp_motion_for(owner).buds==0,"途中撃破で収納量に応じた味方破片3個と円爆発を同期生成し、相手と在庫を解放する")
	cpp_bridge.command("dev_remove",{"entity_id":owner})
	var next_owner: int = cpp_bridge.command("dev_spawn",{"definition_id":"pump","position":cpp_origin}).value
	check(next_owner!=owner and cpp_motion_for(next_owner).buds==0 and cpp_motion_for(next_owner).stored_types.is_empty() and cpp_motion_for(next_owner).bud_t==0.0,"Pumpの行を使い直した別個体へ収納種類を漏らさない")
	cpp_session.free()
	mute_checks = false
	return true

func check_cpp_corona() -> bool:
	var gated := (load("res://data/enemies/drifter.tres") as EnemyDef).duplicate(true) as EnemyDef
	gated.gate = &"solid"
	var tuning := {"corona":{"speed":0.0,"params.capture_max":2,"params.capture_interval":0.05,"params.pull_radius":300.0,"params.pull":100.0,"params.ring":80.0,"params.spin":1.0,"params.fire_interval":100.0,"params.throw_weight_biter":0.0,"params.throw_effect_scale":1.4},"drifter":{"speed":0.0},"swarm":{"speed":0.0},"splitling":{"speed":0.0},"biter":{"speed":0.0}}
	if not await prepare_cpp_attack(116,"corona",PackedStringArray(["corona","drifter","swarm","splitling","biter","hydra_bite"]),tuning,{&"drifter":gated}): return false
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(500,0),"velocity":Vector2.ZERO})
	var owner: int = cpp_bridge.command("dev_spawn",{"definition_id":"corona","position":cpp_origin}).value
	cpp_core.set_enemy_motion(owner,{"fire_t":100.0})
	var first: int = cpp_bridge.command("dev_spawn",{"definition_id":"swarm","position":cpp_origin+Vector2(80,0)}).value
	var second: int = cpp_bridge.command("dev_spawn",{"definition_id":"splitling","position":cpp_origin+Vector2(0,100)}).value
	var original: Dictionary = cpp_enemy_for(first).duplicate()
	var excluded: Array[int] = []
	for id: String in ["drifter","biter"]: excluded.append(cpp_bridge.command("dev_spawn",{"definition_id":id,"position":cpp_origin+Vector2(-80,-20)}).value)
	for flag: String in ["stone","knock_t","shove_time"]:
		var id: int = cpp_bridge.command("dev_spawn",{"definition_id":"swarm","position":cpp_origin+Vector2(-80,-20)}).value
		cpp_core.set_enemy_motion(id,{flag:1.0})
		excluded.append(id)
	var boss: int = cpp_core.spawn_enemy(&"swarm",cpp_origin+Vector2(-80,-20),{"is_boss":true})
	excluded.append(boss)
	excluded.append(cpp_bridge.command("dev_spawn_part",{"parent_id":owner,"definition_id":"hydra_bite","position":cpp_origin+Vector2(-80,-20)}).value)
	cpp_core.step(0.1)
	check(cpp_motion_for(owner).corona_count==2 and cpp_motion_for(first).held==1 and cpp_motion_for(second).held==1 and cpp_motion_for(first).corona_owner==owner and excluded.all(func(id): return not cpp_motion_for(id).has("corona_owner")),"上限2体を同じ敵の個体IDで捕捉し、gate・重み0・石化・外力・ボス・部位を除外する")
	check(cpp_enemy_for(first).hp==original.hp and cpp_enemy_for(first).armor==original.armor and cpp_enemy_for(first).type==original.type,"捕捉しても種類・HP・装甲・元の行を保つ")
	var age: float = cpp_motion_for(first).age
	cpp_core.step(0.1)
	check(is_equal_approx(cpp_motion_for(first).corona_radius,80.0) and is_equal_approx(cpp_motion_for(second).corona_radius,80.0) and is_equal_approx(cpp_motion_for(first).age-age,0.1) and Vector2(cpp_enemy_for(first).pos[0],cpp_enemy_for(first).pos[1]).is_equal_approx(cpp_origin+Vector2.from_angle(0.2)*80.0),"保持中は通常AIを止め、編集した半径・回転・世界時間で周回する")
	var held: Dictionary = cpp_bridge.checkpoint()
	var state: Array = cpp_core.enemy_motion_snapshot()
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-700,1500,1400)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	check(frame.corona.size()==7 and frame.corona_members.size()==20 and presentation.frame_view.apply_frame(frame) and presentation.frame_view._corona_members==frame.corona_members,"冠の渦と同じ個体の周回を通常画面で描く")
	await get_tree().process_frame
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(200,0),"velocity":Vector2.ZERO})
	cpp_core.step(0.1)
	check(cpp_core.ship_snapshot().ship_vel.x<0.0,"低速の機体へ敵更新内で距離減衰した吸引を加える")
	cpp_bridge.command("dev_ship_motion",{"position":cpp_origin+Vector2(200,0),"velocity":Vector2(3000,0)})
	cpp_core.step(0.1)
	check(cpp_core.ship_snapshot().ship_vel==Vector2(3000,0),"高速の機体には吸引を加えない")
	cpp_bridge.restore(held.value)
	var frozen: Array = cpp_core.enemies_snapshot()
	cpp_core.set_enemy_motion(owner,{"stone":1.0})
	cpp_core.step(0.05)
	check(cpp_motion_for(first).held==1 and cpp_enemy_for(first).pos==frozen.filter(func(e): return e.id==first)[0].pos and cpp_motion_for(owner).charge==0.0,"冠が石になる間は周回を止めて予告を取消し所属は保つ")
	for flag: String in ["stone","shove_time","knock_t"]:
		cpp_bridge.restore(held.value)
		cpp_core.set_enemy_motion(first,{flag:1.0})
		cpp_core.step(0.01)
		check(cpp_motion_for(first).held==0 and not cpp_motion_for(first).has("corona_owner") and cpp_motion_for(owner).corona_count==1,"捕捉相手の%sで所属を解除し通常の敵へ戻す" % flag)
	check(cpp_bridge.restore(held.value).ok and cpp_core.enemy_motion_snapshot()==state,"種類別の所属列・周回角・半径・通し番号・所有参照を保持から復元する")
	cpp_bridge.command("dev_kill",{"entity_id":first,"cause":"debug"})
	cpp_bridge.command("dev_remove",{"entity_id":first})
	var replacement: int = cpp_bridge.command("dev_spawn",{"definition_id":"swarm","position":cpp_origin+Vector2(500,0)}).value
	check(replacement!=first and not cpp_motion_for(replacement).has("corona_owner") and cpp_motion_for(replacement).held==0 and cpp_motion_for(owner).corona_count==1,"相手を先に解放し行を使い直しても別個体へ所属を漏らさない")
	cpp_bridge.restore(held.value)
	cpp_bridge.command("dev_relocate",{"entity_id":owner,"position":cpp_origin+Vector2(-100,0)})
	check(cpp_motion_for(first).held==0 and cpp_motion_for(second).held==0 and cpp_motion_for(owner).corona_count==0,"冠の再配置は捕捉した相手をすべて解放する")
	cpp_bridge.restore(held.value)
	cpp_bridge.command("dev_kill",{"entity_id":owner,"cause":"debug"})
	check(cpp_motion_for(first).held==0 and cpp_motion_for(second).held==0 and cpp_motion_for(first).timer==0.0 and cpp_motion_for(first).mode==EnemyTable.Mode.MOVE,"冠の途中撃破で相手の保持と攻撃状態を解除する")
	cpp_bridge.command("dev_remove",{"entity_id":owner})
	var next_owner: int = cpp_bridge.command("dev_spawn",{"definition_id":"corona","position":cpp_origin}).value
	check(next_owner!=owner and cpp_motion_for(next_owner).corona_count==0 and cpp_motion_for(next_owner).corona_selected==0,"冠の行を使い直した別個体へ所属と選択を漏らさない")
	cpp_bridge.restore(held.value)
	cpp_bridge.step(1.0/120.0,cpp_bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var delivered: Dictionary = cpp_bridge.collect_frame()
	check(delivered.ok and cpp_bridge.delivery_error.get("ok",false) and cpp_bridge.read_frame().ok,"通常固定更新の通知配信と状態読取まで成功する")
	cpp_session.free()
	return true

func spawn_cpp_corona_throw(at: Vector2) -> PackedInt64Array:
	cpp_bridge.command("dev_ship_motion",{"position":at+Vector2(500,0),"velocity":Vector2.ZERO})
	cpp_core.set_motion_context(at+Vector2(500,0),at,Vector2(1000,1000))
	var owner: int = cpp_bridge.command("dev_spawn",{"definition_id":"corona","position":at}).value
	var ammo: int = cpp_bridge.command("dev_spawn",{"definition_id":"swarm","position":at-Vector2(0,80)}).value
	cpp_core.set_enemy_motion(owner,{"fire_t":0.0})
	cpp_core.step(0.05)
	cpp_core.step(0.06)
	return PackedInt64Array([owner,ammo])

func check_cpp_corona_throw() -> bool:
	var order_only := "--cpp-corona-throw-order" in OS.get_cmdline_user_args() or "--cpp-corona-throw-order-fix" in OS.get_cmdline_user_args()
	mute_checks = order_only
	var tuning := {"corona":{"speed":0.0,"params.capture_max":1,"params.capture_interval":0.05,"params.pull_radius":300.0,"params.pull":1000.0,"params.ring":80.0,"params.spin":1.0,"params.telegraph":0.1,"params.align_angle":PI,"params.fire_interval":0.3,"params.throw_speed":300.0,"params.throw_life":1.0,"params.throw_damage_swarm":8.0,"params.throw_effect_scale":1.6},"swarm":{"speed":0.0,"hp":1000.0}}
	var prepared := await prepare_cpp_attack(117,"corona_throw",PackedStringArray(["corona","swarm"]),tuning)
	if not prepared: mute_checks = false; return false
	cpp_bridge.command("dev_remove_weapon",{"id":"W01"})
	cpp_core.set_attack_formation_mode(true)
	cpp_core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	var empty: Dictionary = cpp_bridge.checkpoint()
	var ids := spawn_cpp_corona_throw(cpp_origin)
	var owner: int = ids[0]
	var ammo: int = ids[1]
	var thrown: Dictionary = cpp_motion_for(ammo)
	check(thrown.get("corona_thrown",false) and thrown.held==1 and cpp_core.enemies_snapshot().size()==2 and cpp_core.hostiles_snapshot().is_empty() and cpp_motion_for(owner).corona_count==0,"同じ敵の行を接線方向へ投げ、個体や敵弾を複製しない")
	if not thrown.get("corona_thrown",false): cpp_session.free(); return false
	check(is_equal_approx(thrown.corona_life,1.0) and thrown.corona_damage==8.0 and is_equal_approx(thrown.corona_effect,1.6) and is_equal_approx(Vector2(cpp_enemy_for(ammo).vel[0],cpp_enemy_for(ammo).vel[1]).length(),300.0),"投射の速度・寿命・種類別固定威力・表示倍率を編集値から受け取る")
	cpp_core.advance_attack_budget(cpp_core.inspect().world_time)
	check(thrown.corona_token>0 and cpp_core.attack_budget_snapshot().used==1.0,"投射中の外部参照で元の攻撃枠を残す")
	var launched: Dictionary = cpp_bridge.checkpoint()
	if order_only:
		mute_checks = false
		return check_cpp_corona_throw_order(ammo)
	var before: Array = cpp_core.enemy_motion_snapshot()
	var frame: Dictionary = cpp_bridge.read_render(Rect2(-1700,-700,1500,1400)).value
	var presentation: RunPresentation = cpp_session.view.get_node("RunPresentation")
	check(frame.corona_members.size()==10 and frame.corona_members[3]==1.0 and presentation.frame_view.apply_frame(frame),"投射の赤い円と飾りの尾を通常画面で描く")
	await get_tree().process_frame
	cpp_core.set_enemy_motion(owner,{"fire_t":100.0})
	cpp_core.step(1.01)
	cpp_core.advance_attack_budget(cpp_core.inspect().world_time)
	check(cpp_motion_for(ammo).held==0 and not cpp_motion_for(ammo).has("corona_owner") and cpp_enemy_for(ammo).vel==[0.0,0.0] and cpp_core.attack_budget_snapshot().used==0.0,"単体の投射が寿命で終わると通常AIの速さへ戻し攻撃枠を解放する")
	cpp_core.step(1.02)
	check(cpp_motion_for(ammo).held==1 and not cpp_motion_for(ammo).corona_thrown and cpp_motion_for(ammo).corona_serial>thrown.corona_serial and cpp_motion_for(owner).corona_count==1,"寿命後の同じ生存個体を新しい捕捉番号で再捕捉する")
	check(cpp_bridge.restore(launched.value).ok and cpp_core.enemy_motion_snapshot()==before,"飛行中の位置・速度・寿命・相対判定の開始点・予算外部参照を復元する")
	var position := Vector2(cpp_enemy_for(ammo).pos[0],cpp_enemy_for(ammo).pos[1])
	var velocity := Vector2(cpp_enemy_for(ammo).vel[0],cpp_enemy_for(ammo).vel[1])
	var side := Vector2(-velocity.y,velocity.x).normalized()
	cpp_bridge.command("dev_ship_motion",{"position":position+side*90.0,"velocity":Vector2.ZERO})
	cpp_core.step(0.1)
	var finish := Vector2(cpp_enemy_for(ammo).pos[0],cpp_enemy_for(ammo).pos[1])
	cpp_bridge.command("dev_ship_motion",{"position":finish-side*90.0,"velocity":Vector2.ZERO})
	check(cpp_bridge.command("dev_corona_after_combat",{}).ok and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-8.0) and cpp_motion_for(ammo).held==0,"両端で頭の円に触れないすれ違いも相対線分で拾い、atk_scaleを掛けず固定8を与えて投射を終了する")
	cpp_bridge.command("dev_corona_after_combat",{})
	check(is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp-8.0),"1投で機体へ繰り返し命中させない")
	cpp_bridge.restore(launched.value)
	cpp_core.set_enemy_motion(ammo,{"stone":1.0})
	cpp_core.step(0.01)
	check(cpp_motion_for(ammo).held==0 and cpp_motion_for(ammo).stone>0.0 and not cpp_motion_for(ammo).has("corona_owner"),"飛行中の石化は投射を解除して石化した元の敵を残す")
	cpp_bridge.restore(launched.value)
	cpp_bridge.command("dev_kill",{"entity_id":ammo,"cause":"debug"})
	cpp_bridge.command("dev_corona_after_combat",{})
	check(cpp_enemy_for(ammo).dead==1 and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp),"途中で倒された弾薬は後段の機体判定へ当たらない")
	cpp_bridge.command("dev_remove",{"entity_id":ammo})
	var replacement: int = cpp_bridge.command("dev_spawn",{"definition_id":"swarm","position":cpp_origin+Vector2(500,0)}).value
	check(replacement!=ammo and cpp_motion_for(replacement).held==0 and not cpp_motion_for(replacement).has("corona_owner"),"投射していた行の別個体へ所属や攻撃を漏らさない")
	cpp_bridge.restore(launched.value)
	cpp_bridge.command("dev_remove",{"entity_id":owner})
	cpp_bridge.command("dev_corona_after_combat",{})
	cpp_core.advance_attack_budget(cpp_core.inspect().world_time+0.01)
	check(cpp_motion_for(ammo).held==0 and not cpp_motion_for(ammo).has("corona_owner") and cpp_core.attack_budget_snapshot().used==0.0,"元の冠を先に消すと投射済みも解除し外部参照を回収する")
	cpp_bridge.restore(empty.value)
	var terrain := spawn_cpp_corona_throw(Vector2(-260,0))
	check(cpp_motion_for(terrain[1]).get("corona_thrown",false),"天体へ向かう投射を通常の捕捉と予告から始める")
	cpp_core.step(0.7)
	var struck: Dictionary = cpp_enemy_for(terrain[1])
	check(cpp_motion_for(terrain[1]).held==0 and not cpp_motion_for(terrain[1]).has("corona_owner") and Vector2(struck.pos[0],struck.pos[1]).length()>=cpp_config.planet_radius+struck.radius-0.1,"投射が天体へ当たったら既存の押し戻しを使って解除する")
	cpp_bridge.restore(launched.value)
	cpp_bridge.step(1.0/120.0,cpp_bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var delivered: Dictionary = cpp_bridge.collect_frame()
	check(delivered.ok and cpp_bridge.delivery_error.get("ok",false) and cpp_bridge.read_frame().ok,"投射を含む固定更新の通知配信と状態読取まで成功する")
	check(cpp_bridge.dispose().ok and cpp_core.inspect().closed and cpp_core.enemies_snapshot().is_empty() and cpp_core.attack_budget_snapshot().groups.is_empty(),"ラン終了で周回・投射・所属・予算の外部参照を残さず掃除する")
	cpp_session.free()
	return true

func check_cpp_corona_throw_order(ammo: int) -> bool:
	var retry := "--cpp-corona-throw-order-fix" in OS.get_cmdline_user_args()
	var body: Dictionary = cpp_enemy_for(ammo)
	var position := Vector2(body.pos[0],body.pos[1])
	var velocity := Vector2(body.vel[0],body.vel[1])
	var side := Vector2(-velocity.y,velocity.x).normalized()
	var reach: float = body.radius*1.3+cpp_config.ship_radius
	cpp_bridge.command("dev_ship_motion",{"position":position+side*reach,"velocity":Vector2.ZERO})
	mute_checks = retry
	check(cpp_core.fire_shot(position,0.0,1500.0,{"speed":0.0,"r":2.0,"life":1.0,"knock":0.0}),"同じ更新で弾薬を撃ち落とす味方弾を配置する")
	mute_checks = false
	cpp_bridge.step(1.0/120.0,cpp_bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var delivered: Dictionary = cpp_bridge.collect_frame()
	check(cpp_enemy_for(ammo).is_empty() and is_equal_approx(cpp_core.ship_snapshot().ship_hp,cpp_config.base_hp),"味方弾で同じ更新に撃破した弾薬は後段の投射判定へ当たらない")
	if not retry: check(delivered.ok and cpp_bridge.delivery_error.get("ok",false) and cpp_bridge.read_frame().ok,"同時撃破を含む固定更新の通知配信まで成功する")
	cpp_session.free()
	return true
