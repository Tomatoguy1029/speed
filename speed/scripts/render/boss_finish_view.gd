## ボス撃破（ステージ1〜4）の演出。承認済みの試作 `.local/boss-defeat` と同じ見た目で描く。
## ボスの表示を撃破の瞬間に引き取って別の画面へ写し、その絵をひび・崩壊・光の粒へ変える。
## 試作の長さの単位「ボスの絵の1ドット」は、世界のキャラクター倍率（cs）にあたる。
extends Node2D

const BODY := preload("res://shaders/boss_finish_body.gdshader")
const BODY_GLOW := preload("res://shaders/boss_finish_body_glow.gdshader")
const DOTS := preload("res://shaders/boss_finish_dots.gdshader")
const MODULE := preload("res://shaders/boss_finish_module.gdshader")
const UNDER := preload("res://shaders/boss_finish_under.gdshader")
const LIGHT := preload("res://shaders/boss_finish_light.gdshader")
const NOISE := preload("res://assets/effects/build/boss_finish_noise.png")
const SHIP := preload("res://assets/pixel/airship.png")
## ボスの絵の中心から最も遠い画素までの距離（ドット）と、光の粒を拾う間隔（ドット）。
## 試作の絵から測った値。粒の間隔は、試作が画素を間引いた割合に合わせる。
const SHAPES := {0: [177.0, 2.24], 1: [135.3, 2.24], 2: [132.4, 2.24], 3: [340.0, 2.95]}
## 試作の画面の幅。画面に対する大きさ（揺れ・ぼかし・粒の最小の大きさ）を合わせる。
const PROTOTYPE_WIDTH := 960.0
## 切り口が通る範囲（中心からのドット）。試作と同じく中心のボス（うみへび座は不死の蛇）だけを通す。
const CUT_RADIUS := 95.0
## 光の粒を拾う格子の一辺の上限。広いボスは間隔を広げ、粒の数を試作の上限に近づける。
const MAX_GRID := 220.0
const Z_BODY := 15
const Z_STOP_BACK := 35
const Z_STOP := 36
const Z_UNDER := 37
const Z_MODULE := 38
const Z_LIGHT := 40
const Z_FLASH := 41

## 揺れ（画面の点）。run_presentation が毎フレーム読む。
var shake := 0.0
var _display: Node2D
var _kind := 0
var _capture: SubViewport
var _fx_port: SubViewport
var _fine_port: SubViewport
var _body: Node2D
var _body_stop: Node2D
var _boss_layer: CanvasLayer
var _over_layer: CanvasLayer
var _fx_body: Node2D
var _fx_draw: Node2D
var _fine_draw: Node2D
var _fine_dots: MultiMeshInstance2D
var _fx_dots: MultiMeshInstance2D
var _stop_back: Node2D
var _stop_top: Node2D
var _under: Node2D
var _module: Node2D
var _light: Node2D
var _flash: Node2D
var _soft: GradientTexture2D
var _module_art: Texture2D
var _pipeline: Node
var _waved := false
var _mooks: Array[Dictionary] = []
# 1フレーム分の値
var f := {}
var t := 0.0
var cs := 1.0
var at := {}
var view_rect := Rect2()
var _logical := Vector2.ONE
var _zoom := 1.0
var _dir := Vector2.UP
var _impact := Vector2.ZERO
var _origin := Vector2.ZERO
var _relic := Vector2.ZERO
var _ship := Vector2.ZERO
var _ship_angle := 0.0
var _shift := Vector2.ZERO
var _cut_in := 0.0
var _cut_out := 0.0
var _max_r := 140.0

func _ready() -> void:
	visible = false
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.25,0.5,0.75,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,1),Color(1,1,1,0.5625),Color(1,1,1,0.25),Color(1,1,1,0.0625),Color(1,1,1,0)])
	_soft = GradientTexture2D.new()
	_soft.gradient = gradient
	_soft.width = 128
	_soft.height = 128
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5,0.5)
	_soft.fill_to = Vector2(1.0,0.5)

## 撃破したボスの表示を引き取る。以後この演出が持ち、世界の時計が止まった姿のまま写す。
func adopt(display: Node2D, kind: int) -> void:
	if _display!=null: return
	_build()
	_kind = kind
	_display = display
	display.process_mode = Node.PROCESS_MODE_DISABLED
	var keep := display.global_transform
	display.get_parent().remove_child(display)
	_capture.add_child(display)
	display.global_transform = keep
	display.show()
	# 試作と同じくボスの絵だけを写す。足し算・掛け算で重ねる光の部品は、透明度を埋めるので隠す。
	for child in display.find_children("*","CanvasItem",true,false):
		if _overlay_light(child as CanvasItem): (child as CanvasItem).hide()

static func _overlay_light(item: CanvasItem) -> bool:
	var material_ := item.material
	if material_ is CanvasItemMaterial: return (material_ as CanvasItemMaterial).blend_mode!=CanvasItemMaterial.BLEND_MODE_MIX
	if material_ is ShaderMaterial and (material_ as ShaderMaterial).shader!=null:
		var code := (material_ as ShaderMaterial).shader.code
		return code.contains("blend_add") or code.contains("blend_mul") or code.contains("blend_sub") or code.contains("blend_premul_alpha")
	return false

## 撃破演出で消える敵。衝撃の輪が届いた順に光の粒へ変える。
func mook_burst(pos: Vector2, id: int) -> void:
	_mooks.append({"pos":pos,"at":t,"seed":id})

## ボスの絵は敵より手前・機体より奥の層、静止画面と光の合成は機体より手前・HUDより奥の層に置く。
func set_layers(pipeline: Node, boss_layer: int) -> void:
	_pipeline = pipeline
	_build()
	_boss_layer.layer = boss_layer
	if pipeline!=null and pipeline.has_method("add_screen_layer"): pipeline.add_screen_layer(_over_layer,2)
	else:
		_over_layer.layer = boss_layer+4
		add_child(_over_layer)

func set_module_art(texture: Texture2D) -> void:
	_module_art = texture

func hide_view() -> void:
	if not visible: return
	visible = false
	for layer: CanvasLayer in [_boss_layer,_over_layer]: if layer!=null: layer.visible = false
	for port: SubViewport in [_capture,_fx_port,_fine_port]:
		if port!=null: port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	shake = 0.0

func _build() -> void:
	if _capture!=null: return
	_capture = _port(false)
	_fx_port = _port(false)
	_fine_port = _port(false)
	_boss_layer = CanvasLayer.new()
	_boss_layer.follow_viewport_enabled = true
	add_child(_boss_layer)
	_over_layer = CanvasLayer.new()
	_over_layer.follow_viewport_enabled = true
	var body_material := _material(BODY)
	_body = _node(Z_BODY,_draw_cover,_boss_layer,body_material)
	_stop_back = _node(Z_STOP_BACK,_draw_stop_back,_over_layer)
	_body_stop = _node(Z_STOP,_draw_cover,_over_layer,body_material)
	_stop_top = _node(Z_STOP,_draw_stop_top,_over_layer)
	_fx_body = _node(0,_draw_cover,_fx_port,_material(BODY_GLOW))
	_fx_body.set_meta("cover",true)
	_fx_dots = _dots(_fx_port,true)
	_fx_draw = _node(0,_draw_fx,_fx_port,_add())
	_fine_dots = _dots(_fine_port,false)
	_fine_draw = _node(0,_draw_fine,_fine_port,_add())
	_copy(Z_UNDER)
	_under = _node(Z_UNDER,_draw_cover,_over_layer,_material(UNDER))
	_module = _node(Z_MODULE,_draw_module,_over_layer,_material(MODULE))
	_node(Z_MODULE,_draw_ship_pop,_over_layer)
	_copy(Z_LIGHT)
	_light = _node(Z_LIGHT,_draw_cover,_over_layer,_material(LIGHT))
	_flash = _node(Z_FLASH,_draw_flash,_over_layer)
	for material_: ShaderMaterial in [_body.material,_fx_body.material,_fx_dots.material,_fine_dots.material]:
		material_.set_shader_parameter("noise",NOISE)
		material_.set_shader_parameter("capture",_capture.get_texture())
	(_under.material as ShaderMaterial).set_shader_parameter("fine_light",_fine_port.get_texture())
	(_light.material as ShaderMaterial).set_shader_parameter("glow",_fx_port.get_texture())

func _port(_hdr: bool) -> SubViewport:
	var port := SubViewport.new()
	port.transparent_bg = true
	port.disable_3d = true
	port.world_2d = World2D.new()
	port.render_target_update_mode = SubViewport.UPDATE_DISABLED
	port.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	port.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	port.snap_2d_transforms_to_pixel = false
	add_child(port)
	return port

func _material(shader: Shader) -> ShaderMaterial:
	var material_ := ShaderMaterial.new()
	material_.shader = shader
	return material_

func _add() -> CanvasItemMaterial:
	var material_ := CanvasItemMaterial.new()
	material_.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material_

func _node(z: int, painter: Callable, parent: Node = null, material_: Material = null) -> Node2D:
	var node := Node2D.new()
	node.z_as_relative = false
	node.z_index = z
	node.material = material_
	node.draw.connect(painter.bind(node) if painter.get_argument_count()>0 else painter)
	(parent if parent!=null else self).add_child(node)
	return node

func _copy(z: int) -> void:
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	copy.z_as_relative = false
	copy.z_index = z
	_over_layer.add_child(copy)

func _dots(parent: Node, glow_layer: bool) -> MultiMeshInstance2D:
	var node := MultiMeshInstance2D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.mesh = mesh
	multimesh.custom_aabb = AABB(Vector3(-1e7,-1e7,-1),Vector3(2e7,2e7,2))
	node.multimesh = multimesh
	node.material = _material(DOTS)
	(node.material as ShaderMaterial).set_shader_parameter("glow_layer",glow_layer)
	parent.add_child(node)
	return node

func _shape_dots(node: MultiMeshInstance2D, grid: int) -> void:
	if node.multimesh.instance_count==grid*grid: return
	node.multimesh.instance_count = grid*grid
	for i in grid*grid: node.multimesh.set_instance_transform_2d(i,Transform2D.IDENTITY)

# ===== 時間割 =====
func _start(stage: String) -> float:
	return 0.0 if stage=="stop" else float(at.get(stage,0.0))

func _length(stage: String) -> float:
	var next := {"stop":"slow","slow":"crack","crack":"hold","hold":"burst","burst":"settle","settle":"cool","cool":"show","show":"take","take":"clear","clear":"end"}
	return maxf(0.0001,float(at[next[stage]])-_start(stage))

func pr(stage: String) -> float:
	return clampf((t-_start(stage))/_length(stage),0.0,1.0)

static func smooth(v: float) -> float:
	v = clampf(v,0.0,1.0)
	return v*v*(3.0-2.0*v)

static func ease_out(v: float) -> float:
	return 1.0-pow(1.0-clampf(v,0.0,1.0),3.0)

static func hash1(n: float) -> float:
	return fposmod(sin(n*127.1+311.7)*43758.5453,1.0)

func _crack_pulse() -> float:
	var p := pr("crack")
	return 0.5+0.5*sin(TAU*(2.5*p+4.5*p*p)-1.2)

func _silhouette() -> int:
	if t>=_start("slow"): return 0
	return 1 if pr("stop")<0.32 else 2

func _since_burst() -> float:
	return t-_start("burst")

## 切り口が今どこまで伸びたか（当たった点からのドット）。
func _cut_end() -> float:
	if t<_start("slow"): return _cut_in+6.0
	return minf(_cut_out,lerpf(_cut_in,_cut_out+45.0,pr("slow")))

func _cut_point(u: float) -> Vector2:
	return _impact+_dir*u*cs

# ===== 1フレーム =====
func apply(finish: Dictionary, character_scale: float, ship_heading: Vector2) -> void:
	if _display==null and not finish.get("blasted",false):
		hide_view()
		return
	_build()
	f = finish
	t = float(finish.elapsed)
	at = finish.times
	cs = character_scale
	_origin = finish.origin
	_impact = finish.impact
	_dir = (finish.direction as Vector2).normalized()
	_relic = finish.relic
	_ship = finish.ship
	_ship_angle = ship_heading.angle()+PI/2.0
	var shape: Array = SHAPES.get(_kind,SHAPES[0]).duplicate()
	# うみへび座は、不死の蛇から残った蛇の先までをC++が測って渡す。
	if float(finish.get("reach",0.0))>0.0: shape[0] = float(finish.reach)/cs
	_max_r = shape[0]
	shape[1] = maxf(float(shape[1]),2.0*_max_r/MAX_GRID)
	var cut_r := CUT_RADIUS
	var to_center := (_origin-_impact)/cs
	var u0 := to_center.dot(_dir)
	var d0 := to_center.x*_dir.y-to_center.y*_dir.x
	var half := sqrt(maxf(0.0,cut_r*cut_r-d0*d0))
	_cut_in = u0-half-8.0
	_cut_out = u0+half+8.0
	if not visible:
		visible = true
		for layer: CanvasLayer in [_boss_layer,_over_layer]: layer.visible = true
		for port: SubViewport in [_capture,_fx_port,_fine_port]: port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_place()
	_boss_motion()
	_update_body(shape)
	_update_shake()
	if not _waved and _since_burst()>=0.0:
		_waved = true
		if _pipeline!=null: _pipeline.add_wave(_origin,1600.0,0.8)
	for node: Node2D in [_body,_body_stop,_fx_body,_fx_draw,_fine_draw,_stop_back,_stop_top,_under,_module,_light,_flash]: node.queue_redraw()
	for child in _over_layer.get_children(): if child is Node2D: child.queue_redraw()

func _place() -> void:
	var canvas := get_viewport().get_canvas_transform()
	_logical = get_viewport().get_visible_rect().size
	var physical := Vector2(get_viewport().size)
	if physical.x<1.0: physical = _logical
	_zoom = canvas.x.length()
	var inverse := canvas.affine_inverse()
	view_rect = Rect2(inverse*Vector2.ZERO,_logical/_zoom).grow(64.0/_zoom)
	var linear := get_viewport().use_hdr_2d
	var fx_size := Vector2i(maxi(1,roundi(_logical.x/4.0)),maxi(1,roundi(_logical.y/4.0)))
	_capture.use_hdr_2d = linear
	_capture.canvas_item_default_texture_filter = get_viewport().canvas_item_default_texture_filter
	for pair in [[_capture,Vector2i(physical)],[_fine_port,Vector2i(physical)],[_fx_port,fx_size]]:
		var port: SubViewport = pair[0]
		if port.size!=pair[1]: port.size = pair[1]
		port.canvas_transform = Transform2D(0.0,Vector2(port.size)/_logical,0.0,Vector2.ZERO)*canvas
	var capture_form := _capture.canvas_transform
	var fx_inverse := _fx_port.canvas_transform.affine_inverse()
	for material_: ShaderMaterial in [_body.material,_fx_body.material,_fx_dots.material,_fine_dots.material]:
		material_.set_shader_parameter("capture_size",Vector2(_capture.size))
		material_.set_shader_parameter("cap_x",capture_form.x)
		material_.set_shader_parameter("cap_y",capture_form.y)
		material_.set_shader_parameter("cap_o",capture_form.origin)
		material_.set_shader_parameter("linear_input",linear)
	var body: ShaderMaterial = _body.material
	body.set_shader_parameter("scr_x",inverse.x)
	body.set_shader_parameter("scr_y",inverse.y)
	body.set_shader_parameter("scr_o",inverse.origin)
	body.set_shader_parameter("target_size",_logical)
	body.set_shader_parameter("linear_output",linear)
	var glow: ShaderMaterial = _fx_body.material
	glow.set_shader_parameter("scr_x",fx_inverse.x)
	glow.set_shader_parameter("scr_y",fx_inverse.y)
	glow.set_shader_parameter("scr_o",fx_inverse.origin)
	glow.set_shader_parameter("target_size",Vector2(fx_size))
	for node: Node2D in [_under,_module,_light]: (node.material as ShaderMaterial).set_shader_parameter("linear_output",linear)
	(_light.material as ShaderMaterial).set_shader_parameter("blur_radius",Vector2(6.0/PROTOTYPE_WIDTH,6.0/(PROTOTYPE_WIDTH*_logical.y/_logical.x)))

## のけぞり・震え・ためで縮む動き。試作のボス本体の動き。
func _boss_motion() -> void:
	var th := _dir.angle()
	var ts := t-_start("slow")
	var frame := floorf(t*60.0)
	var shift := Vector2.ZERO
	var turn := 0.0
	var squash := 1.0
	var k := 0.35
	if ts>=0.0: k = exp(-ts*2.6)*(1.0-exp(-ts*30.0))+0.35*exp(-ts*30.0)
	shift += Vector2.from_angle(th)*13.0*k
	turn = 0.055*k
	var jitter := 0.0
	if t>=_start("slow") and t<_start("crack"): jitter = 2.6*exp(-ts*5.0)
	elif t>=_start("crack") and t<_start("hold"): jitter = 0.3+1.5*pr("crack")*_crack_pulse()
	elif t>=_start("burst"): jitter = 2.0*maxf(0.0,1.0-_since_burst()*4.0)
	shift += Vector2(hash1(frame*3.1)-0.5,hash1(frame*5.9+3.0)-0.5)*2.0*jitter
	if t>=_start("hold") and t<_start("burst"): squash = 1.0-0.045*ease_out(pr("hold"))
	elif t>=_start("burst"): squash = 0.955+0.075*ease_out(_since_burst()/0.12)
	_shift = shift*cs
	for material_: ShaderMaterial in [_body.material,_fx_body.material]:
		material_.set_shader_parameter("shift",_shift)
		material_.set_shader_parameter("turn",turn)
		material_.set_shader_parameter("squash",squash)

func _update_body(shape: Array) -> void:
	var boost: bool = f.get("boost",true)
	var sil := _silhouette()
	var tb := _since_burst()
	var front := 0.0
	if t<_start("crack"):
		if not boost and t>=_start("slow"): front = 0.16*ease_out(pr("slow"))*_max_r
	else: front = (ease_out(pr("crack"))*0.92+0.2*pr("hold")+0.3*pr("burst"))*_max_r*1.15
	var pulse := _crack_pulse() if t<_start("hold") else 0.25 if t<_start("burst") else 1.0
	var strength := 1.0 if sil>0 else 0.9
	if t>=_start("crack") and t<_start("burst")+0.3: strength += 0.3*(_crack_pulse() if t<_start("hold") else 0.1 if t<_start("burst") else 1.0)
	for material_: ShaderMaterial in [_body.material,_fx_body.material]:
		material_.set_shader_parameter("origin",_origin)
		material_.set_shader_parameter("impact",_impact)
		material_.set_shader_parameter("cut_dir",_dir)
		material_.set_shader_parameter("cs",cs)
		material_.set_shader_parameter("max_r",_max_r)
		material_.set_shader_parameter("boost",boost)
		material_.set_shader_parameter("cut_end",_cut_end() if t>=0.0 else -1e9)
		material_.set_shader_parameter("hit",maxf(0.0,1.0-(t-_start("slow"))/0.3) if t>=_start("slow") else 0.0)
		material_.set_shader_parameter("gray",0.0 if t<_start("slow") else smooth((t-_start("slow"))/(_length("slow")*0.7)))
		material_.set_shader_parameter("dark",0.55*smooth(pr("crack")))
		material_.set_shader_parameter("front",front)
		material_.set_shader_parameter("pulse",pulse)
		material_.set_shader_parameter("gold",smooth((t-_start("crack"))/0.35))
		material_.set_shader_parameter("cut_alpha",1.0 if tb<0.0 else maxf(0.0,1.0-tb*3.0))
		material_.set_shader_parameter("since_burst",tb)
		material_.set_shader_parameter("burst_time",_length("burst"))
		material_.set_shader_parameter("silhouette",sil)
	(_fx_body.material as ShaderMaterial).set_shader_parameter("strength",strength)
	_body.visible = sil==0 and tb<_length("burst")*0.95
	_body_stop.visible = sil>0
	var dot := maxf(1.6,1.4/maxf(0.001,_zoom*cs*PROTOTYPE_WIDTH/_logical.x))*cs
	var grid := ceili(2.0*_max_r/float(shape[1]))
	for node: MultiMeshInstance2D in [_fine_dots,_fx_dots]:
		_shape_dots(node,grid)
		var material_: ShaderMaterial = node.material
		material_.set_shader_parameter("origin",_origin)
		material_.set_shader_parameter("impact",_impact)
		material_.set_shader_parameter("cut_dir",_dir)
		material_.set_shader_parameter("cs",cs)
		material_.set_shader_parameter("max_r",_max_r)
		material_.set_shader_parameter("boost",boost)
		material_.set_shader_parameter("grid",grid)
		material_.set_shader_parameter("spacing",float(shape[1]))
		material_.set_shader_parameter("since_burst",tb)
		material_.set_shader_parameter("burst_time",_length("burst"))
		material_.set_shader_parameter("settle",pr("settle"))
		material_.set_shader_parameter("gather",f.get("reveal",false))
		material_.set_shader_parameter("relic",_relic)
		material_.set_shader_parameter("shift",_shift)
		material_.set_shader_parameter("dot_size",dot)
		node.visible = tb>0.0

func _update_shake() -> void:
	var sh := 0.0
	var tb := _since_burst()
	if tb>=0.0: sh = 10.0*exp(-tb*4.5)
	if f.get("reveal",false) and t>=_start("clear"): sh = maxf(sh,8.0*exp(-(t-_start("clear"))*6.0))
	shake = sh*_logical.x/PROTOTYPE_WIDTH

func _dim() -> float:
	var tb := _since_burst()
	if _silhouette()>0: return 0.0
	if f.get("reveal",false) and t>=_start("cool"): return 0.62*smooth(pr("cool")*2.0)*(1.0-smooth(pr("take")))
	if t<_start("slow"): return 0.0
	if t<_start("crack"): return 0.5*smooth(pr("slow")*2.0)
	if t<_start("burst"): return 0.5+0.22*pr("crack")
	return 0.72*maxf(0.0,1.0-tb*4.0)

# ===== 描く =====
func _draw_cover(node: Node2D) -> void:
	if node==_light:
		var d := _dim()
		(_light.material as ShaderMaterial).set_shader_parameter("dim",Vector3(1.0-d*0.55,1.0-d*0.5,1.0-d*0.3))
	node.draw_rect(view_rect,Color.WHITE)

func _blob(canvas: CanvasItem, at_: Vector2, radius: float, color: Color, alpha: float) -> void:
	if alpha<=0.005 or radius<=0.5: return
	canvas.draw_texture_rect(_soft,Rect2(at_-Vector2.ONE*radius,Vector2.ONE*radius*2.0),false,Color(color,color.a*minf(alpha,1.0)))

## 試作の streak：根元から先へ細くなり、白へ抜けて消える光の筋。
func _streak(canvas: CanvasItem, at_: Vector2, angle: float, length: float, width: float, color: Color, alpha: float) -> void:
	if alpha<=0.005 or length<1.0: return
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var steps := 6
	for side in [-1.0,1.0]:
		for i in steps+1:
			var s := float(i)/steps if side<0.0 else 1.0-float(i)/steps
			if side>0.0 and i==0: continue
			var x := length*s
			var y: float = (width*0.5*(1.0-s)*(1.0-s)+2.0*(1.0-s)*s*width*0.2)*side
			points.append(at_+Vector2(x,y).rotated(angle))
			colors.append(Color(color.lerp(Color.WHITE,s),alpha*(1.0-s)))
	canvas.draw_polygon(points,colors)

func _square(canvas: CanvasItem, at_: Vector2, size: float, color: Color, alpha: float) -> void:
	if alpha<=0.005: return
	canvas.draw_rect(Rect2(at_-Vector2.ONE*size*0.5,Vector2.ONE*size),Color(color,alpha))

func _draw_stop_back() -> void:
	var sil := _silhouette()
	if sil==0: return
	_stop_back.draw_rect(view_rect,Color("#f4f6ff") if sil==1 else Color.BLACK)

## 命中の静止：機体の影と、当たった点から後ろへ伸びる光の筋（黒の場面）。
func _draw_stop_top() -> void:
	var sil := _silhouette()
	if sil==0: return
	_stop_top.draw_set_transform(_ship,_ship_angle,Vector2.ONE*cs)
	_stop_top.draw_texture(SHIP,-SHIP.get_size()*0.5,Color.BLACK if sil==1 else Color.WHITE)
	_stop_top.draw_set_transform(Vector2.ZERO)
	if sil==1 and f.get("boost",true): _impact_streaks(_stop_top,Color.BLACK,false)

func _impact_streaks(canvas: CanvasItem, color: Color, glow: bool) -> void:
	var ip := _cut_point(_cut_in)+_shift
	var p := pr("stop")
	for i in 16:
		var a := _dir.angle()+PI+(hash1(i*2.3)-0.5)*2.6
		var length := (60.0+260.0*hash1(i*4.7))*(0.6+0.4*p)*cs
		if glow: _streak(canvas,ip,a,length,12.0*cs,Color(1,240.0/255.0,210.0/255.0),0.8)
		else: _streak(canvas,ip+Vector2.from_angle(a)*14.0*cs,a,length,(2.0+3.0*hash1(i*9.1))*cs,color,0.9)

## 画面へ直接足す光（試作の g へ lighter で描いたもの）。
func _draw_fine() -> void:
	var c := _fine_draw
	var tb := _since_burst()
	if _silhouette()==2 and f.get("boost",true): _impact_streaks(c,Color.WHITE,false)
	for mook: Dictionary in _mooks:
		var q: float = t-float(mook.at)
		var seed_: float = float(mook.seed)
		var out := (mook.pos as Vector2-_origin).normalized()
		for k in 26:
			var a := hash1(seed_*31.0+k*1.9)*TAU
			var v := 30.0+150.0*hash1(seed_*17.0+k*3.1)
			var e := (1.0-exp(-q*3.0))/3.0
			var al := maxf(0.0,1.0-q/(0.5+0.6*hash1(k*2.2+seed_)))
			_square(c,mook.pos+(Vector2.from_angle(a)*v*e+out*60.0*e)*cs,2.5*cs,Color("#ffd98a") if k%3 else Color("#bfe0ff"),al*al)
	if f.get("reveal",false) and t>=_start("cool") and t<_start("clear"): _draw_relic_fine(c)
	if f.get("reveal",false) and t>=_start("clear"):
		var a := t-_start("clear")
		for i in 40:
			var an := hash1(i*4.7)*TAU
			var v := 40.0+170.0*hash1(i*2.1)
			var e := (1.0-exp(-a*3.5))/3.5
			_square(c,_ship+Vector2.from_angle(an)*v*e*cs,2.0*cs,Color("#ffd98a") if i%3 else Color("#fff6dc"),maxf(0.0,1.0-a/(0.5+0.6*hash1(i*6.3))))

## 4分の1の光の絵（試作の gg）。
func _draw_fx() -> void:
	var c := _fx_draw
	var tb := _since_burst()
	var boost: bool = f.get("boost",true)
	var sil := _silhouette()
	var center := _origin+_shift
	if sil==2 and boost:
		_impact_streaks(c,Color.WHITE,true)
		_blob(c,_cut_point(_cut_in)+_shift,90.0*cs,Color.WHITE,1.0)
	for mook: Dictionary in _mooks:
		_blob(c,mook.pos,46.0*cs,Color(1,240.0/255.0,200.0/255.0),maxf(0.0,1.0-(t-float(mook.at))*7.0))
	# 切り口の光
	if boost and tb<0.35:
		var k := (1.0 if tb<0.0 else 1.0-tb/0.35)*(1.0 if t<_start("crack") else 0.6+0.4*_crack_pulse() if t<_start("hold") else 0.35 if t<_start("burst") else 1.0)
		var from := _cut_point(_cut_in)+_shift
		var to := _cut_point(_cut_end())+_shift
		if _cut_end()>_cut_in:
			c.draw_line(from,to,Color(Color("#ffffff") if t<_start("crack")+0.2 else Color("#ffd27a"),k),5.0*cs)
			c.draw_line(from,to,Color(Color("#ffb648"),k*0.55),13.0*cs)
	# 崩壊の光：芯・放射する光の筋
	if tb>0.0:
		var env := minf(1.0,tb/0.04)*exp(-tb*3.3)
		_blob(c,center,260.0*ease_out(tb/0.2)*cs,Color(1,250.0/255.0,235.0/255.0),minf(1.0,env*1.5))
		_blob(c,center,520.0*ease_out(tb/0.3)*cs,Color(1,170.0/255.0,70.0/255.0),env*0.6)
		_blob(c,center,700.0*ease_out(tb/0.4)*cs,Color(90.0/255.0,150.0/255.0,1),env*0.35)
		for i in 20:
			var a := hash1(i*6.1+2.0)*TAU+tb*0.18*(1.0 if i%2 else -1.0)
			var l := (170.0+470.0*hash1(i*3.7))*ease_out(tb/(0.18+0.25*hash1(i*8.3)))*cs
			var col := Color(150.0/255.0,200.0/255.0,1) if i%4==0 else Color.WHITE if i%3==0 else Color(1,214.0/255.0,130.0/255.0)
			_streak(c,center,a,l,(10.0+26.0*hash1(i*5.5))*cs,col,env*(0.6+0.4*hash1(i*1.1)))
	if not f.get("reveal",false): return
	# 集まった光
	if t>=_start("settle") and t<_start("cool"):
		var ps := pr("settle")
		var amount := smooth((ps-0.25)/0.6)*(1.0-0.85*smooth((ps-0.88)/0.12))
		var breath := 1.0+0.08*sin(t*5.0)
		_blob(c,_relic,70.0*amount*breath*cs,Color(1,225.0/255.0,150.0/255.0),amount)
		_blob(c,_relic,24.0*amount*breath*cs,Color.WHITE,amount)
		for i in 4: _streak(c,_relic,i*PI/2.0+t*0.35,(60.0+50.0*(i%2))*amount*breath*cs,9.0*cs,Color(1,240.0/255.0,200.0/255.0),amount*0.9)
	if t>=_start("cool") and t<_start("clear"):
		var m := _module_state()
		if m.te>0.0:
			for i in 14:
				var p0 := _take_point(m.te*(1.0-(i+1)/14.0*0.75))
				var p1 := _take_point(m.te*(1.0-i/14.0*0.75))
				c.draw_line(p0,p1,Color(Color("#ffd27a"),pow(1.0-i/14.0,1.5)),12.0*(1.0-i/14.0)*cs)
		var fa := t-_start("cool")
		_blob(c,_relic,230.0*ease_out(fa/0.18)*cs,Color(1,240.0/255.0,200.0/255.0),exp(-fa*7.0))
	if t>=_start("clear"):
		var a := t-_start("clear")
		var env := exp(-a*5.0)
		_blob(c,_ship,120.0*ease_out(a/0.15)*cs,Color(1,215.0/255.0,130.0/255.0),env)
		_blob(c,_ship,40.0*cs,Color.WHITE,env)
		for i in 16: _streak(c,_ship,hash1(i*3.3)*TAU,(60.0+150.0*hash1(i*7.1))*ease_out(a/0.2)*cs,8.0*cs,Color(1,225.0/255.0,150.0/255.0) if i%3 else Color.WHITE,env)

# ===== 獲得の場面 =====
func _take_point(b: float) -> Vector2:
	var middle := (_relic+_ship)*0.5+Vector2(_ship.y-_relic.y,-(_ship.x-_relic.x))*0.3
	var q := 1.0-b
	return _relic*q*q+middle*2.0*q*b+_ship*b*b

func _module_state() -> Dictionary:
	var pc := pr("cool")
	var pt := pr("take")
	var charge := smooth(pt/0.28)
	var fly := clampf((pt-0.28)/0.72,0.0,1.0)
	var te := pow(fly,2.6)
	var at_ := _take_point(te)
	if t<_start("take"): at_.y += sin(t*2.1)*2.0*cs
	var back := 1.0+2.70158*pow(pc-1.0,3.0)+1.70158*pow(pc-1.0,2.0)
	var sc := 1.9*back*(1.0-0.14*charge)*(1.0-0.72*te)
	var light := ease_out(pc*1.4)*(1.0-0.9*te)*(1.0+0.5*charge)*(0.92+0.08*sin(t*4.3))
	return {"at":at_,"sc":sc,"light":light,"charge":charge,"te":te}

## 後光・金の粉・回収の粉（モジュールより奥の光）。
func _draw_relic_fine(c: CanvasItem) -> void:
	var m := _module_state()
	var at_: Vector2 = m.at
	var k: float = m.sc/1.9
	var light: float = m.light
	_blob(c,at_,175.0*k*cs,Color(1,196.0/255.0,84.0/255.0),0.5*light)
	_blob(c,at_,70.0*k*cs,Color(1,246.0/255.0,214.0/255.0),0.55*light)
	for i in 30:
		var h1 := hash1(i*3.1+4.0)
		var a := h1*TAU+t*(0.22 if i%2 else -0.16)
		var length := (70.0+190.0*hash1(i*5.9))*(0.75+0.25*sin(t*(1.2+2.0*h1)+i))*light*k*cs
		_streak(c,at_,a,length,(2.5+5.0*hash1(i*8.7))*cs,Color(1,214.0/255.0,120.0/255.0) if i%4 else Color(1,250.0/255.0,230.0/255.0),(0.22+0.4*hash1(i*2.3))*light)
	for i in 4: _streak(c,at_,i*PI/2.0+0.12,(150.0 if i%2 else 250.0)*light*k*(0.92+0.08*sin(t*9.0+i))*cs,5.0*cs,Color.WHITE,0.8*light)
	for i in 54:
		var life := 1.3+hash1(i*2.9)*1.4
		var a := fposmod((t-_start("cool"))/life+hash1(i*6.1),1.0)
		var an := hash1(i*4.3)*TAU
		var rr := (26.0+95.0*hash1(i*9.7))*k
		var pos := at_+Vector2(cos(an)*rr+sin(a*5.0+i)*4.0,sin(an)*rr*0.8-a*34.0)*cs
		_square(c,pos,(1.4 if i%5 else 2.4)*cs,Color("#ffd98a") if i%3 else Color("#fff6dc"),sin(a*PI)*light*(0.5+0.5*sin(t*(14.0+9.0*hash1(i))+i)))
	var te: float = m.te
	if te>0.0:
		for i in 60:
			var b := te*hash1(i*3.7+1.0)
			var p := _take_point(b)+Vector2(hash1(i*5.1)-0.5,hash1(i*8.3)-0.5)*18.0*cs
			_square(c,p,2.0*cs,Color("#ffd98a") if i%3 else Color("#fff6dc"),maxf(0.0,1.0-(te-b)*1.8)*(0.5+0.5*sin(t*30.0+i)))

func _draw_module() -> void:
	if _module_art==null or not f.get("reveal",false) or t<_start("cool") or t>=_start("clear"): return
	var m := _module_state()
	var hot := 1.0-smooth((t-_start("cool")-0.3*_length("cool"))/(0.7*_length("cool")+0.25))
	var amount := minf(1.0,hot+float(m.charge)*0.7+float(m.te)) if hot>0.01 or float(m.charge)>0.0 else 0.0
	var material_: ShaderMaterial = _module.material
	material_.set_shader_parameter("hot",amount)
	material_.set_shader_parameter("gloss",(t-_start("show")-0.3)/0.45)
	material_.set_shader_parameter("art_size",_module_art.get_size())
	_module.draw_set_transform(m.at,sin(t*1.3)*0.035+float(m.te)*2.2,Vector2.ONE*float(m.sc)*cs)
	_module.draw_texture(_module_art,-_module_art.get_size()*0.5)
	_module.draw_set_transform(Vector2.ZERO)

## 機体に届いた瞬間、機体が一瞬大きくはじける。
func _draw_ship_pop(node: Node2D) -> void:
	if not f.get("reveal",false) or t<_start("clear"): return
	var scale_ := 1.0+0.3*exp(-(t-_start("clear"))*9.0)
	if scale_<1.01: return
	node.draw_set_transform(_ship,_ship_angle,Vector2.ONE*cs*scale_)
	node.draw_texture(SHIP,-SHIP.get_size()*0.5)
	node.draw_set_transform(Vector2.ZERO)

func _draw_flash() -> void:
	var fl := 0.0
	var slow := _start("slow")
	if t>=slow and t<slow+0.12: fl = 0.55*(1.0-(t-slow)/0.12)
	var tb := _since_burst()
	if tb>=0.0: fl = maxf(fl,0.9*exp(-tb*8.0))
	if fl>0.01: _flash.draw_rect(view_rect,Color(1,1,1,fl))

func _exit_tree() -> void:
	if _display!=null and is_instance_valid(_display): _display.queue_free()
	if _over_layer!=null and is_instance_valid(_over_layer) and _over_layer.get_parent()!=self: _over_layer.queue_free()
