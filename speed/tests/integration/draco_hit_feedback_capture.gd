## 本体・遠景・分身の被弾表示を、C++の実ダメージ通知から撮影する。
extends "res://tests/runtime/draco.gd"
var output := "/tmp/draco-qa-evidence/feedback-variety/render"
var metadata: Array[Dictionary] = []
var viewport: SubViewport

func _ready() -> void:
	get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	if DisplayServer.get_name()=="headless":
		push_error("被弾表示の撮影はgodot-bgで描画付き起動してください")
		get_tree().quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):output=argument.trim_prefix("--capture-output=")
	DirAccess.make_dir_recursive_absolute(output)
	var identity_start:=_identity()
	viewport=SubViewport.new()
	viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.size=Vector2i(1280,720)
	add_child(viewport)
	for form in ["normal","depth","copy"]:
		await _capture_form(form)
	var file:=FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"identity_start":identity_start,"identity_end":_identity(),"frames":metadata},"\t"))
	print("[draco_hit_feedback_capture] frames=",metadata.size()," failed=",failed)
	get_tree().quit(1 if failed else 0)

func _capture_form(form: String) -> void:
	var f:=breath_fixture(load("res://data/bosses/draco_moves/clones.tres"))
	if f.is_empty():return
	var bridge=f.bridge
	bridge._core.step(0.101)
	var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
	var target: int=f.boss
	var hit_row: int=body.segments[mini(6,body.segments.size()-1)].id
	if form=="depth":
		check(bridge.command("dev_draco_pose",{"entity_id":f.boss,"operation":"depth","depth":0.35,"alpha":0.55}).ok,"遠景の姿へ移す")
		check(bridge.command("dev_enemy_combat",{"entity_id":target,"guard":1.0}).ok,"遠景の無敵を同じ戦闘経路へ設定する")
	if form=="copy":
		check(bridge.command("dev_boss_technique",{"entity_id":f.boss,"definition":1}).ok,"全身分身を始める")
		var units: Array=bridge.command("dev_boss_state").value[0].clones
		if units.size()<2:check(false,"撮影対象の分身を作る");bridge.dispose();return
		target=int(units[1].id)
		hit_row=int(units[1].parts[mini(6,units[1].parts.size()-1)])
	var receiver=load("res://scripts/render/run_frame_view.gd").new()
	bridge.subscribe("被弾表示の撮影",receiver.receive_frame)
	var display=load("res://scripts/render/bosses/draco.gd").new()
	viewport.add_child(display)
	display.hit_feedback=receiver.boss_hit_feedback
	var camera:=Camera2D.new()
	viewport.add_child(camera)
	await _snapshot(f,display,camera,form,"before",0.0,target)
	check(bridge.command("dev_damage",{"entity_id":hit_row,"amount":10.0,"cause":"shot"}).ok,"本体または分身の胴へ命中する")
	await _snapshot(f,display,camera,form,"hit",0.0,target)
	receiver.boss_hit_feedback.tick(0.045)
	await _snapshot(f,display,camera,form,"later",0.045,target)
	receiver.boss_hit_feedback.tick(0.13)
	await _snapshot(f,display,camera,form,"reset",0.175,target)
	check(bridge.command("dev_enemy_combat",{"entity_id":target,"guard":1.0}).ok,"無敵の撮影条件を設定する")
	check(bridge.command("dev_damage",{"entity_id":hit_row,"amount":10.0,"cause":"shot"}).ok,"無敵の胴へ同じ攻撃を通す")
	await _snapshot(f,display,camera,form,"blocked",0.175,target)
	bridge.dispose()
	display.free();camera.free();receiver.free()

func _snapshot(f: Dictionary, display: Node2D, camera: Camera2D, form: String, label: String, elapsed: float, target: int) -> void:
	var body: Dictionary=f.bridge.command("dev_boss_body_state").value[-1]
	var attacks: Array=f.bridge.command("dev_boss_state").value
	display.apply_frame(body,attacks[0] if not attacks.is_empty() else {},{})
	var points: PackedVector2Array=body.body_points
	if form=="copy":
		display._parts.hide()
		for id in display._clones:display._clones[id].visible=int(id)==target
		for unit: Dictionary in body.clones:
			if int(unit.id)==target:points=unit.points
	var bounds:=Rect2(points[0],Vector2.ZERO)
	for point: Vector2 in points:bounds=bounds.expand(point)
	bounds=bounds.grow(250.0)
	camera.position=bounds.get_center()
	camera.zoom=Vector2.ONE*minf(1280.0/bounds.size.x,720.0/bounds.size.y)*0.85
	camera.make_current()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var filename:=form+"_"+label+".png"
	check(viewport.get_texture().get_image().save_png(output.path_join(filename))==OK,"被弾表示を保存する")
	var hp:=0.0
	for enemy: Dictionary in f.bridge._core.enemies_snapshot():
		if int(enemy.id)==target:hp=float(enemy.hp)
	metadata.append({"form":form,"phase":label,"seconds":elapsed,"file":filename,"target_id":target,"target_hp":hp,"feedback":display.hit_feedback.sample(target)})

func _identity() -> Dictionary:
	var result: Dictionary={"engine":Engine.get_version_info(),"source":ContentManager.source_hashes}
	for path in ["res://scripts/bosses/boss_hit_feedback.gd","res://scripts/render/bosses/draco.gd","res://scripts/render/run_frame_view.gd","res://scripts/runtime/run_bridge.gd","res://shaders/boss_hit_feedback.gdshader","res://shaders/picaro.gdshader"]:
		result[path]=FileAccess.get_sha256(path)
	return result
