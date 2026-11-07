## 三本爪の裂け目。画面の写しを読むので、体やエフェクトより手前の層で描く。
extends CanvasLayer
const SHADER := preload("res://shaders/draco_rift_post.gdshader")
const NOISE := preload("res://assets/fx/water_noise.png")
const LIMIT := 12
var _copy: BackBufferCopy
var _image: ColorRect
var _material: ShaderMaterial

func _ready() -> void:
	_copy = BackBufferCopy.new()
	_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_copy)
	_image = ColorRect.new()
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("noise_tex",NOISE)
	_image.material = _material
	add_child(_image)
	hide()

func apply_frame(bodies: Array, size: Vector2, camera: Vector2, zoom: float) -> void:
	hide()
	if size.x<=0.0 or size.y<=0.0: return
	for body: Dictionary in bodies:
		var tears: Array = body.get("rift_tears",[])
		if tears.is_empty(): continue
		var pixel := size.y/225.0
		var half := Vector2(roundf(size.x/pixel)*pixel,size.y)*0.5
		var ends := PackedVector4Array()
		var shape := PackedVector4Array()
		var open_time := float(body.rift_open)
		var close_time := float(body.rift_close)
		for tear: Dictionary in tears:
			var age := float(tear.age)
			var hold := float(tear.hold)
			if age<0.0 or age>=hold+close_time or ends.size()>=LIMIT: continue
			var closing := smoothstep(0.0,1.0,(age-hold)/close_time)
			var tip := (1.0-pow(1.0-clampf(age/open_time,0.0,1.0),3.0))*(1.0-closing)
			var a: Vector2 = ((Vector2(tear.from)-camera)*zoom+half)/pixel
			var b: Vector2 = ((Vector2(tear.to)-camera)*zoom+half)/pixel
			ends.append(Vector4(a.x,a.y,b.x,b.y))
			shape.append(Vector4(float(tear.width)*zoom/pixel,tip,tip*(1.0-closing*0.5),float(tear.seed)))
		if ends.is_empty(): continue
		_image.size = size
		var count := ends.size()
		while ends.size()<LIMIT:
			ends.append(Vector4.ZERO)
			shape.append(Vector4.ZERO)
		_material.set_shader_parameter("linear_target",get_viewport().use_hdr_2d)
		_material.set_shader_parameter("viewport_size",size)
		_material.set_shader_parameter("time",float(body.clock))
		_material.set_shader_parameter("count",count)
		_material.set_shader_parameter("ends",ends)
		_material.set_shader_parameter("shape",shape)
		show()
		return
