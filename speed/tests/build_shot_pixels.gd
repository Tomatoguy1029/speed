## 描画ありで、射撃の輪郭と白い芯を試作のドット配置に照合する。
extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")

func put(pixels: Dictionary, angle: float, k: int, side: int, color: Color) -> void:
	var point := -Vector2.from_angle(angle)*k+Vector2.from_angle(angle).orthogonal()*side
	# Canvas の Math.round と同じく、負の半端も +0.5 して切り下げる。
	pixels[Vector2i(floori(point.x+0.5),floori(point.y+0.5))] = color

func reference(angle: float, length: int, wide: int) -> Dictionary:
	var pixels := {}
	var glow := 3 if wide>=2 else 2
	if wide>0:
		for k in range(1,length):
			if k>length*0.6 and k%2==1: continue
			for side in [glow,-glow]: put(pixels,angle,k,side,Color("#2a7fd0"))
	for k in length:
		if k>=length*0.75 and k%2==1: continue
		put(pixels,angle,k,0,Color.WHITE if k<length*0.4 else Color("#7fd8ff") if k<length*0.75 else Color("#3a9cf0"))
		if wide>0 and k<length*0.75:
			var color := (Color.WHITE if wide>=2 else Color("#d8f6ff")) if k<length*0.35 else Color("#7fd8ff")
			for side in [1,-1]: put(pixels,angle,k,side,color)
		if wide>=2 and k>=1 and k<length*0.6:
			for side in [2,-2]: put(pixels,angle,k,side,Color("#d8f6ff") if k<length*0.3 else Color("#7fd8ff"))
	put(pixels,angle,-1,0,Color.WHITE)
	if wide>=2:
		for side in [1,-1]: put(pixels,angle,-1,side,Color("#d8f6ff"))
		put(pixels,angle,-2,0,Color.WHITE)
	return pixels

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("この検査は描画ありで実行する")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(192,192)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var batch := InstanceBatch.new()
	batch.setup_shader_quad()
	var material := ShaderMaterial.new()
	material.shader=load("res://shaders/build_shot.gdshader")
	batch.material=material
	viewport.add_child(batch)
	var cases := 0
	for variant in 4:
		material.set_shader_parameter("style",0 if variant==0 else 2 if variant==3 else 1)
		for degrees in [0.0,15.0,30.0,45.0,75.0,90.0,135.0,180.0,225.0,270.0,315.0]:
			var angle := deg_to_rad(degrees)
			var expected := reference(angle,17 if variant==0 else 6 if variant==1 else 3,2 if variant==0 else 1 if variant==1 else 0)
			if variant==3:
				expected.clear()
				for k in range(1,4):
					for side in [1,-1]: put(expected,angle,k,side,Color("#8fffe2"))
				for k in range(1,5): put(expected,angle,k,0,Color("#8fffe2"))
				put(expected,angle,0,0,Color.WHITE)
			batch.begin()
			batch.add_upright(Vector2(96,96),72.0,Color(angle/TAU,1.0 if variant==2 else 0.0,0,1))
			batch.end()
			await process_frame
			await RenderingServer.frame_post_draw
			var actual := viewport.get_texture().get_image()
			var mismatch := 0
			for y in range(-18,18):
				for x in range(-18,18):
					var dot := Vector2i(x,y)
					var color := actual.get_pixel(96+x*4,96+y*4)
					if (color.a>0.1)!=expected.has(dot): mismatch+=1
					elif expected.has(dot):
						var white: bool = expected[dot]==Color.WHITE
						if white!=(color.r>0.98 and color.g>0.98 and color.b>0.98): mismatch+=1
			if mismatch>0:
				failures+=1
				push_error("射撃ドット不一致: 種類%d 角度%d 差分%d" % [variant,degrees,mismatch])
			cases+=1
	print("[build_shot_pixels] cases=%d failures=%d" % [cases,failures])
	quit(1 if failures else 0)
