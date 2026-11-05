extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var failed := 0
var source: HeroAuraAssets
func _ready() -> void:
	if "--cpp-hercules" in OS.get_cmdline_user_args():
		await cpp_hercules_display()
		print("[cpp_H_hercules_view] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-gemini" in OS.get_cmdline_user_args():
		await cpp_gemini_display()
		print("[cpp_H_gemini_view] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-leo" in OS.get_cmdline_user_args():
		await cpp_leo_display()
		print("[cpp_H_leo_view] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	if DisplayServer.get_name()=="headless":
		push_error("hero_aura_gpu requires a real GPU")
		get_tree().quit(1)
		return
	source=load("res://.content/hero_aura.res")
	for j in [0,2,5,11]:
		await compare(j)
	await cpp_perseus_display()
	print("[hero_aura_gpu] cases=4 failed=",failed)
	get_tree().quit(1 if failed else 0)
func viewport() -> SubViewport:
	var v:=SubViewport.new()
	v.size=Vector2i(1024,768)
	v.world_2d=World2D.new()
	v.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	v.use_hdr_2d=true
	add_child(v)
	var bg:=ColorRect.new()
	bg.size=v.size
	bg.color=Color(0.08,0.03,0.12)
	v.add_child(bg)
	return v
func compare(j: int) -> void:
	var zoom:float=[0.28,0.7,1.0,1.4][j%4]
	var center:Vector2=[Vector2(1234.3,-2300.5),Vector2(-5300.7,300.2),Vector2(0.2,-0.5)][j/4]
	var radii:=Vector2(240+j*2.51,190+j*3.31)+Vector2.ONE*(72.0/zoom)
	var step:=4.0/zoom
	var counts:=Vector2(ceili(radii.x*2.0/step),ceili(radii.y*2.0/step))
	var breath:=0.95+0.05*sin(j*0.7)
	var views: Array[SubViewport]=[]
	for legacy in [true,false]:
		var v:=viewport()
		views.append(v)
		var parent:=Node2D.new()
		parent.position=Vector2(v.size)*0.5-center*zoom
		parent.scale=Vector2.ONE*zoom
		v.add_child(parent)
		if legacy:
			var draw:=DrawLayer.new()
			draw.draw_fn=func(c: CanvasItem):
				for row in int(counts.y):
					for col in int(counts.x):
						var at:=center-radii+Vector2(col,row)*step
						var q:Vector2=(at-center)/radii
						var cloud:=0.78+0.22*sin(q.x*4.0+q.y*2.0)*cos(q.y*5.0-q.x)
						var density:=exp(-q.length_squared()*2.8)*cloud
						var alpha:=floorf(density*24.0)/24.0*0.25*breath
						if alpha>0.0:c.draw_rect(Rect2(at.snapped(Vector2.ONE*step),Vector2.ONE*step),Color(Color("#ffe8a0"),alpha))
			parent.add_child(draw)
		else:
			var mesh:=MeshInstance2D.new()
			mesh.mesh=source.mesh
			var mat:=source.material.duplicate() as ShaderMaterial
			mat.set_shader_parameter("cell_count",counts)
			mat.set_shader_parameter("radii",radii)
			mat.set_shader_parameter("aura_center",center)
			mat.set_shader_parameter("cell_size",step)
			mat.set_shader_parameter("breath",breath)
			mesh.material=mat
			mesh.position=(center-radii).snapped(Vector2.ONE*step)
			mesh.scale=counts*step
			parent.add_child(mesh)
	for _i in 4:await RenderingServer.frame_post_draw
	var images:Array[Image]=[]
	for v in views:
		var im:=v.get_texture().get_image()
		im.convert(Image.FORMAT_RGBA8)
		images.append(im)
	var n:=0
	var peak:=0
	var sum:=0
	var a:=images[0].get_data()
	var b:=images[1].get_data()
	for i in a.size():
		var d:=absi(int(a[i])-int(b[i]))
		if d:n+=1
		sum+=d
		peak=maxi(peak,d)
	if peak!=0:
		failed+=1
		push_error("光雲の画素差 case=%d max=%d channels=%d" % [j,peak,n])
	for v in views:v.queue_free()
	await get_tree().process_frame

func check(ok: bool, label: String) -> void:
	if not ok:
		failed+=1
		push_error(label)
func settle() -> void:
	for _i in 4:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
func cpp_perseus_display() -> void:
	var guide = load("res://tests/integration/hero_guidance.gd").new()
	var behavior = load("res://tests/runtime/hero_behaviors.gd").new()
	var bridge = guide._cpp_fixture(true)
	behavior._cpp_rescue(bridge,"perseus")
	bridge.command("dev_ship_motion",{"position":Vector2.ZERO,"velocity":Vector2.ZERO})
	var enemy: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(120,0)}).value
	bridge.command("dev_fire_enemy",{"source_id":enemy,"angle":0.0,"speed":100.0})
	var intent := Intent.new()
	intent.hero_press = true
	var frame: Dictionary = behavior._cpp_step(bridge,intent)
	bridge.command("dev_tick_heroes",{"dt":2.0,"run_time":2.0})
	frame = behavior._cpp_read(bridge)
	var held: Dictionary = bridge.checkpoint()
	var v := viewport()
	var camera := Camera2D.new()
	v.add_child(camera)
	var scope := ContentResourceScope.new()
	for path in ["res://.content/hero_aura.res","res://.content/meteor_pieces.res","res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png","res://assets/pixel/airship_armor.png","res://assets/pixel/airship_mine.png"]: scope.provide(path,load(path))
	for visual: Dictionary in guide._cpp_visuals:
		if not String(visual.get("path","")).is_empty(): scope.provide(visual.path,load(visual.path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	v.add_child(view)
	view.setup(scope,guide._cpp_visuals,frame.ui.character_scale)
	view.update_effects(frame,0.0)
	var rect := Rect2(-512,-384,1024,768)
	check(view.apply_frame(bridge.read_render(rect,1.0).value) and view._hero_power_visual.petrified.size()==3,"目が開ききった敵の石化表示を受け取る")
	var layer := CanvasLayer.new()
	layer.layer = 100
	v.add_child(layer)
	var hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = bridge
	hud.size = v.size
	layer.add_child(hud)
	hud.apply_snapshot(frame.ui)
	await settle()
	bridge._core.step(6.0)
	bridge.command("dev_tick_heroes",{"dt":6.0,"run_time":6.0})
	frame = behavior._cpp_read(bridge)
	view.update_effects(frame,0.0)
	check(view.apply_frame(bridge.read_render(rect,1.0).value) and view._hero_power_visual.petrified.is_empty(),"効果終了後に石の表示を残さない")
	check(bridge.restore(held.value).ok,"石化表示の途中保持へ戻す")
	frame = behavior._cpp_read(bridge)
	view.update_effects(frame,0.0)
	hud.apply_snapshot(frame.ui)
	check(view.apply_frame(bridge.read_render(rect,1.0).value) and view._hero_power_visual.petrified.size()==3 and frame.ui.hero.active>1.0,"復帰で残り時間・石の表示・使用中の枠が戻る")
	await settle()
	check(v.get_texture().get_image().save_png("/tmp/speed-heroes-perseus.png")==OK,"ペルセウスの実表示を保存する")
	v.queue_free()
	await get_tree().process_frame
	bridge.dispose()
	failed += guide.failed+behavior.failed
	guide.free()
	behavior.free()

func cpp_leo_display() -> void:
	var guide = load("res://tests/integration/hero_guidance.gd").new()
	var behavior = load("res://tests/runtime/hero_behaviors.gd").new()
	var bridge = guide._cpp_fixture(true)
	behavior._cpp_rescue(bridge,"leo")
	bridge.command("dev_ship_motion",{"position":Vector2.ZERO,"velocity":Vector2.ZERO})
	var intent := Intent.new()
	intent.hero_press = true
	behavior._cpp_step(bridge,intent)
	behavior._cpp_draw(bridge,false)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
	var frame: Dictionary = behavior._cpp_read(bridge)
	var held: Dictionary = bridge.checkpoint()
	var v := viewport()
	var camera := Camera2D.new()
	v.add_child(camera)
	var scope := ContentResourceScope.new()
	for path in ["res://.content/hero_aura.res","res://.content/meteor_pieces.res","res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png","res://assets/pixel/airship_armor.png","res://assets/pixel/airship_mine.png"]: scope.provide(path,load(path))
	for visual: Dictionary in guide._cpp_visuals:
		if not String(visual.get("path","")).is_empty(): scope.provide(visual.path,load(visual.path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	v.add_child(view)
	view.setup(scope,guide._cpp_visuals,frame.ui.character_scale)
	view.update_effects(frame,0.0)
	var rect := Rect2(-512,-384,1024,768)
	var render: Dictionary = bridge.read_render(rect,1.0)
	var band: Dictionary = render.value.shapes.filter(func(shape): return shape.layer==3 and shape.kind==0)[0]
	check(view.apply_frame(render.value) and band.widths[0]==360.0 and band.colors[0]==Color(1.0,0.85,0.45),"しし座のなぞりを定義と同じ幅の金色の帯で描く")
	bridge.command("dev_tick_heroes",{"dt":14.0,"run_time":14.0})
	frame = behavior._cpp_read(bridge)
	view.update_effects(frame,0.0)
	render = bridge.read_render(rect,1.0)
	band = render.value.shapes.filter(func(shape): return shape.layer==3 and shape.kind==0)[0]
	check(view.apply_frame(render.value) and band.widths[0]==90.0 and band.colors[0]==Color(0.55,0.9,1.0),"効果終了で元の幅と青い帯へ戻す")
	check(bridge.restore(held.value).ok,"描き途中のしし座へ復帰する")
	frame = behavior._cpp_read(bridge)
	view.update_effects(frame,0.0)
	render = bridge.read_render(rect,1.0)
	check(view.apply_frame(render.value) and frame.ui.hero.trace_width==4.0 and frame.ui.hero.active>13.0,"復帰で金色の帯と残り時間を出し直す")
	await settle()
	check(v.get_texture().get_image().save_png("/tmp/speed-heroes-leo.png")==OK,"しし座の表示を保存する")
	v.queue_free()
	await get_tree().process_frame
	bridge.dispose()
	failed += guide.failed+behavior.failed
	guide.free()
	behavior.free()

func cpp_gemini_display() -> void:
	var guide = load("res://tests/integration/hero_guidance.gd").new()
	var behavior = load("res://tests/runtime/hero_behaviors.gd").new()
	var bridge = guide._cpp_fixture(true)
	behavior._cpp_rescue(bridge,"gemini")
	bridge.command("dev_ship_motion",{"position":Vector2(-300,0),"velocity":Vector2.ZERO})
	var intent := Intent.new()
	intent.hero_press = true
	behavior._cpp_step(bridge,intent)
	behavior._cpp_draw(bridge)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
	var rect := Rect2(-512,-384,1024,768)
	var captured: Dictionary = bridge.read_render(rect,1.0)
	check(captured.ok and captured.value.shapes.any(func(shape): return shape.layer==3 and shape.order==2 and shape.points[0]==Vector2(-300,0)),"保存した一本目を薄い青の線で出す")
	behavior._cpp_second_line(bridge)
	bridge._core.step_draw(0.01)
	bridge.command("dev_tick_heroes",{"dt":0.0,"run_time":0.0})
	var frame: Dictionary = behavior._cpp_read(bridge)
	var held: Dictionary = bridge.checkpoint()
	var v := viewport()
	var camera := Camera2D.new()
	v.add_child(camera)
	var scope := ContentResourceScope.new()
	for path in ["res://.content/hero_aura.res","res://.content/meteor_pieces.res","res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png","res://assets/pixel/airship_armor.png","res://assets/pixel/airship_mine.png"]: scope.provide(path,load(path))
	for visual: Dictionary in guide._cpp_visuals:
		if not String(visual.get("path","")).is_empty(): scope.provide(visual.path,load(visual.path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	v.add_child(view)
	view.setup(scope,guide._cpp_visuals,frame.ui.character_scale)
	view.update_effects(frame,0.0)
	var render: Dictionary = bridge.read_render(rect,1.0)
	check(view.apply_frame(render.value) and render.value.shapes.any(func(shape): return shape.layer==3 and shape.order==3 and shape.points[0]==frame.ui.hero.twin.position),"二本目の線と双子の機体を進んだ位置で描く")
	bridge.command("dev_tick_heroes",{"dt":10.0,"run_time":10.0})
	frame = behavior._cpp_read(bridge)
	check(frame.ui.hero.active==0.0 and bridge.read_render(rect,1.0).value.shapes.any(func(shape): return shape.order==3),"効果の期限でも走行中の双子の表示を消さない")
	check(bridge.restore(held.value).ok,"双子の表示途中へ戻す")
	frame = behavior._cpp_read(bridge)
	view.update_effects(frame,0.0)
	render = bridge.read_render(rect,1.0)
	check(view.apply_frame(render.value) and frame.ui.hero.active>9.0,"復帰で双子の線・位置と残り時間を出し直す")
	await settle()
	check(v.get_texture().get_image().save_png("/tmp/speed-heroes-gemini.png")==OK,"ふたご座の表示を保存する")
	v.queue_free()
	await get_tree().process_frame
	bridge.dispose()
	failed += guide.failed+behavior.failed
	guide.free()
	behavior.free()

func cpp_hercules_display() -> void:
	var guide = load("res://tests/integration/hero_guidance.gd").new()
	var behavior = load("res://tests/runtime/hero_behaviors.gd").new()
	var bridge = guide._cpp_fixture(true,100000.0,100000.0)
	behavior._cpp_rescue(bridge,"hercules")
	bridge.command("dev_ship_motion",{"position":Vector2.ZERO,"velocity":Vector2.ZERO})
	bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(120,0)})
	var intent := Intent.new()
	intent.hero_press = true
	behavior._cpp_step(bridge,intent)
	behavior._cpp_hero_tick(bridge,0.3,0.3)
	var frame: Dictionary = behavior._cpp_hero_tick(bridge,0.3,0.6)
	var held: Dictionary = bridge.checkpoint()
	var v := viewport()
	var camera := Camera2D.new()
	v.add_child(camera)
	var scope := ContentResourceScope.new()
	for path in ["res://.content/hero_aura.res","res://.content/meteor_pieces.res","res://assets/pixel/airship_flame.png","res://assets/pixel/airship_spark.png","res://assets/pixel/airship_armor.png","res://assets/pixel/airship_mine.png"]: scope.provide(path,load(path))
	for visual: Dictionary in guide._cpp_visuals:
		if not String(visual.get("path","")).is_empty(): scope.provide(visual.path,load(visual.path))
	var view = load("res://scripts/render/run_frame_view.gd").new()
	v.add_child(view)
	view.setup(scope,guide._cpp_visuals,frame.ui.character_scale)
	view.update_effects(frame,0.0)
	var rect := Rect2(-512,-384,1024,768)
	check(view.apply_frame(bridge.read_render(rect,1.0).value) and view._hero_power_visual.fire.falls.size()==3 and view._hero_power_visual.fire.burns.size()==3,"次の隕石の影・本体と燃える跡を同じ状態から描く")
	var before: Dictionary = view._hero_power_visual.fire.duplicate(true)
	behavior._cpp_hero_tick(bridge,10.0,10.6)
	frame = behavior._cpp_read(bridge)
	view.update_effects(frame,0.0)
	check(view._hero_power_visual.fire.falls.is_empty() and view._hero_power_visual.fire.burns.is_empty(),"効果と炎の寿命後に前の火を残さない")
	check(bridge.restore(held.value).ok,"火の表示途中へ戻す")
	frame = behavior._cpp_read(bridge)
	view.update_effects(frame,0.0)
	check(view.apply_frame(bridge.read_render(rect,1.0).value) and view._hero_power_visual.fire==before and frame.ui.hero.active>9.0,"復帰で落下・燃焼・力の残り時間を出し直す")
	await settle()
	check(v.get_texture().get_image().save_png("/tmp/speed-heroes-hercules.png")==OK,"ヘルクレスの表示を保存する")
	v.queue_free()
	await get_tree().process_frame
	bridge.dispose()
	failed += guide.failed+behavior.failed
	guide.free()
	behavior.free()
