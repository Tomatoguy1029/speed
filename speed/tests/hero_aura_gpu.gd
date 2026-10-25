extends Node
var failed := 0
var source: HeroAuraAssets
func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("hero_aura_gpu requires a real GPU")
		get_tree().quit(1)
		return
	source=load("res://.content/hero_aura.res")
	for j in [0,2,5,11]:
		await compare(j)
	await lifecycle()
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
func lifecycle() -> void:
	var session:=RunManager.create_session(self,{"lab":true,"stage_index":4,"seed":401},true)
	session.auto_step=false
	var view:RunPresentation=session.view.get_node("RunPresentation")
	var hero:=session.sim.heroes
	view.view_override={"center":hero.center,"zoom":0.7}
	await settle()
	check(view._hero_aura.visible,"画面内の英雄の光雲を表示する")
	check(view._hero_aura.mesh==source.mesh and view._hero_aura_material!=source.material,"形状を共有し、materialは表示ごとに所有する")
	var before:Vector2=view._hero_aura_material.get_shader_parameter("radii")
	view.view_override.zoom=1.0
	await settle()
	check(view._hero_aura_material.get_shader_parameter("radii")!=before,"倍率のライブ変更で同じ星座の格子を更新する")
	session.sim.state.world_time=3.0
	await settle()
	var breath:float=view._hero_aura_material.get_shader_parameter("breath")
	check(is_equal_approx(breath,0.95+0.05*sin(3.0*0.8)),"呼吸は元と同じ世界時刻から計算する")
	session.sim.set_phase(RunState.Phase.PAUSED)
	await settle()
	check(view._hero_aura_material.get_shader_parameter("breath")==breath,"ポーズ中は光雲の呼吸を保持する")
	view._layers.field.hide()
	check(not view._hero_aura.is_visible_in_tree(),"地形の非表示に光雲も従う")
	view._layers.field.show()
	hero.hero=null
	await settle()
	check(not view._hero_aura.visible,"英雄がなくなったら前の光雲を残さない")
	var weak:WeakRef=weakref(view._hero_aura_material)
	session.free()
	await get_tree().process_frame
	check(weak.get_ref()==null,"終了時にラン固有materialを解放する")
