## roar.js: postCanisRoar。6層の拡大写し、屈折、筋、むらと揺れを同じ順に重ねる。
extends CanvasLayer
const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const SHADER := preload("res://shaders/roar_post.gdshader")
const LEVELS := {1:{"life":0.24,"blur":0.028,"mix":0.55},2:{"life":0.36,"blur":0.075,"mix":0.8},3:{"life":0.52,"blur":0.17,"mix":1.0}}
var _copy: BackBufferCopy
var _image: ColorRect
var _material: ShaderMaterial
var _band_used := false

func _ready() -> void:
	_copy = BackBufferCopy.new()
	_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_copy)
	_image = ColorRect.new()
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("streaks",preload("res://assets/effects/reference/roar/streaks.png"))
	_material.set_shader_parameter("lumps",preload("res://assets/effects/reference/roar/lumps.png"))
	_image.material = _material
	add_child(_image)
	hide()

func apply_frame(bodies: Array, size: Vector2, camera: Vector2, zoom: float) -> void:
	hide()
	for body: Dictionary in bodies:
		var roar: Dictionary = body.get("roar",{})
		if roar.is_empty(): continue
		var params: Dictionary = SETTINGS.for_id(str(roar.id))
		if params.is_empty() or float(params.roarPost)<=0.0 or float(params.intensity)<=0.0: continue
		var level := clampi(int(params.roarLevel),1,3)
		var age := float(roar.age)
		var life := float(LEVELS[level].life)*float(params.roarTime)
		if age<0.0 or age>=life: continue
		var u := age/life
		var envelope := smoothstep(0.0,0.08,u)*(1.0-smoothstep(0.35,1.0,u))
		if envelope<=0.001: continue
		var center: Vector2 = (Vector2(roar.mouth)-camera)*zoom+size*0.5
		var unit := float(roar.radius)*zoom*float(params.size)*float(params.roarSize)
		var clear := unit*float(params.roarClear)
		var outer := maxf(clear*1.8,unit*float(params.roarRange)*(0.7+0.3*level/3.0))
		var strength := minf(1.0,float(LEVELS[level].mix)*float(params.roarPost)*float(params.intensity))
		var shake_amount := float([0.0,0.5,1.0][level-1])*float(params.roarShake)*envelope*unit*0.06
		var shake := Vector2.ZERO
		if shake_amount>0.3: shake = Vector2(sin(age*91.0+float(roar.seed)),cos(age*73.0+float(roar.seed)))*shake_amount
		_image.size = size
		var values := {"viewport_size":size,"center":center,"shake":shake,"clear_radius":clear,"outer_radius":outer,
			"zoom_amount":float(LEVELS[level].blur)*float(params.roarBlur)*envelope*2.2,"strength":strength,"envelope":envelope,
			"band_radius":lerpf(clear,outer,1.0-pow(1.0-clampf(u*1.4,0.0,1.0),2.0)),"band_width":unit*0.45,
			"displacement":0.035*(0.6+0.4*level/3.0)*float(params.roarLines),"seed":float(roar.seed),"age":age,"level":float(level),
			"tint":Color(params.roarColor),"first_band":not _band_used}
		for key in values: _material.set_shader_parameter(key,values[key])
		# 元のband canvasはdestination-inが次のコマにも残る。この合成順も保持する。
		if float(values.displacement)>0.0 and float(values.band_radius)>1.0: _band_used = true
		show()
