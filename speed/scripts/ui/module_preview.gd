## 300×170の実演を投影する。静止サムネイルは描画結果を保持し、選択・タブ切替で再生成しない。
class_name ModulePreview
extends Control
const HOLO := preload("res://shaders/codex_hologram.gdshader")
const WARP := preload("res://assets/effects/build/codex_warp.png")
const ICONS := preload("res://scripts/ui/module_icons.gd")
var definition: Resource
var known := false
var animated := false
var _clock := 0.0
var _accum := 0.0
var _viewport: SubViewport
var _image: TextureRect
var _demo: Node2D
var _icon: Sprite2D
var _holo: ShaderMaterial
var _selected_age := 0.0
var _generation := 0

func setup(def: Resource, acquired: bool, animate := false) -> void:
	definition = def
	known = acquired
	animated = animate
	_clock = 0.0
	_selected_age = 0.0
	if is_node_ready(): _build()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_layout)
	if definition != null: _build()

func _build() -> void:
	_generation+=1
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_demo = null
	_icon = null
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(300,170)
	_viewport.disable_3d = true
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	var background := ColorRect.new()
	background.size = Vector2(300,170)
	background.color = Color.BLACK
	_viewport.add_child(background)
	if known:
		if definition.preview_texture != null:
			_icon = Sprite2D.new()
			_icon.texture = definition.preview_texture
			_icon.position = Vector2(150,74)
			_icon.scale = Vector2.ONE*minf(220.0/_icon.texture.get_width(),130.0/_icon.texture.get_height())
			_viewport.add_child(_icon)
		elif definition is LegendaryModuleDef or (definition is ContentEntry and definition.category==&"legendary_modules"):
			var legend: Control = preload("res://scripts/ui/legendary_module_icon.gd").new()
			legend.module_id = definition.id
			legend.position = Vector2(60,0)
			legend.size = Vector2(180,150)
			_viewport.add_child(legend)
		elif ResourceLoader.exists("res://data/codex/%s.res" % definition.code_id):
			_demo = preload("res://scripts/ui/codex_demonstration.gd").new()
			_viewport.add_child(_demo)
			_demo.setup(definition)
			if not animated: _clock = _demo.animation.period*0.42
			_demo.sample(_clock)
		else:
			_icon = Sprite2D.new()
			_icon.position = Vector2(150,74)
			if definition.id in [&"T34",&"T35"]:
				var placeholder := Label.new()
				placeholder.text = "◇\n？"
				placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				placeholder.add_theme_font_size_override("font_size",32)
				placeholder.position = Vector2(120,30)
				_viewport.add_child(placeholder)
			else: _icon.texture = ICONS.texture_for(definition)
			_icon.scale = Vector2.ONE*2.0
			_viewport.add_child(_icon)
	_holo = ShaderMaterial.new()
	_holo.shader = HOLO
	_holo.set_shader_parameter("warp",WARP)
	_holo.set_shader_parameter("source_tex",_viewport.get_texture())
	_holo.set_shader_parameter("locked",not known)
	_holo.set_shader_parameter("rare",bool(definition.comet_only) if "comet_only" in definition else false)
	_image = TextureRect.new()
	_image.texture = _viewport.get_texture()
	_image.material = _holo
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)
	_update_hologram(0.5 if not animated else 0.0)
	_layout()
	set_process(animated)
	if not animated and DisplayServer.get_name()!="headless": _freeze.call_deferred(_generation)

func _freeze(generation: int) -> void:
	await RenderingServer.frame_post_draw
	if generation!=_generation or animated or not is_instance_valid(_viewport): return
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(_demo):
		_demo.queue_free()
		_demo = null

func _layout() -> void:
	queue_redraw()
	if _image != null:
		_image.position = Vector2.ZERO
		_image.size = size

func _process(dt: float) -> void:
	_accum += dt
	if _accum < 1.0/30.0: return
	_clock += _accum
	_selected_age += _accum
	_accum = 0.0
	if is_instance_valid(_demo): _demo.sample(_clock)
	if _icon != null and definition.preview_texture==null:
		var cosine := cos(_clock*1.1)
		_icon.scale = Vector2((1.0 if cosine>=0.0 else -1.0)*maxf(0.12,absf(cosine))*2.0,2.0)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_hologram(_clock)

static func _hash(n: float) -> float:
	return fposmod(sin(n*127.1+311.7)*43758.5453,1.0)

func _update_hologram(time: float) -> void:
	_holo.set_shader_parameter("clock",time)
	_holo.set_shader_parameter("reveal",minf(1.0,_selected_age/0.38) if animated else 1.0)
	var start := 0.0
	var scan := -99.0
	for n in 4001:
		var gap := 1.0+_hash(n)*2.4
		var duration := 190.0/(120.0+_hash(n+0.5)*120.0)
		if time < start+gap: break
		if time < start+gap+duration:
			scan = (time-start-gap)/duration*190.0-10.0
			break
		start += gap+duration
	_holo.set_shader_parameter("scan_y",scan)
	var slot := 0
	for j in range(floori(time*5.0)-2,floori(time*5.0)+1):
		var glitch := Vector4(-99,0,0,0)
		var at := j/5.0+_hash(j+0.9)*0.18
		var duration := 0.03+_hash(j+0.5)*0.1
		if _hash(j)<=0.22 and time>=at and time<=at+duration:
			var offset := roundf((_hash(j+0.2)-0.5)*10.0)
			if offset==0.0: offset=2.0
			glitch=Vector4(floor(_hash(j+0.3)*156.0),1+floor(_hash(j+0.7)*3.0),offset,1.25)
		_holo.set_shader_parameter("glitch%d" % slot,glitch)
		slot += 1

func _draw() -> void:
	if definition==null:return
	var ratio:=minf(size.x/300.0,size.y/170.0)
	var image_size:=Vector2(300,170)*ratio
	var lo:Vector2=(size-image_size)*0.5-Vector2.ONE*6.0
	var hi:Vector2=(size+image_size)*0.5+Vector2.ONE*6.0
	var rare:=bool(definition.comet_only) if "comet_only" in definition else false
	var color:=Color("#ffd27a") if rare else Color("#7fe8ff")
	for corner in [Vector2(lo.x,lo.y),Vector2(hi.x,lo.y),Vector2(lo.x,hi.y),hi]:
		var direction:=Vector2(1.0 if corner.x==lo.x else -1.0,1.0 if corner.y==lo.y else -1.0)
		draw_line(corner,corner+Vector2(direction.x*14,0),color,2.0,false)
		draw_line(corner,corner+Vector2(0,direction.y*14),color,2.0,false)
