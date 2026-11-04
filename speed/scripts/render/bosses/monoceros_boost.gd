## 一角獣の尾の噴射。元 mono_boost.js の密度・3色の面・発光を使う表示部品。
## 戦闘の時刻・速度・技段階と、呼出側が求めた尾の根元を受け取る。
extends PixelFire

var _length := -1.0
var _width := 0.0
var _run_at := -1.0
var _last_clock := -1.0
var _glow_view: SubViewport
var _reference_glow: ShaderMaterial

func _ready() -> void:
	manual = true
	emitting = false
	super()
	_shape_material.set_shader_parameter("pixel_size", 1.0)
	_shape_material.set_shader_parameter("deformation", 0.35)
	_shape_material.set_shader_parameter("threshold", 0.32)
	_shape_material.set_shader_parameter("edge_softness", 0.04)
	# 発光も先に論理画素へ焼き、その結果をNearestで拡大する。
	_glow_view = _viewport("MonocerosGlow")
	var glow_source := Sprite2D.new()
	glow_source.centered = false
	glow_source.texture = color_view.get_texture()
	glow_source.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_reference_glow = ShaderMaterial.new()
	_reference_glow.shader = preload("res://shaders/monoceros_boost_glow.gdshader")
	glow_source.material = _reference_glow
	_glow_view.add_child(glow_source)
	glow.texture = _glow_view.get_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## stage は元の run / approach / brake / stop / end 等。移動値はC++出力から渡す。
## anchor は親のローカル座標、tail_angle は親に対する尾の向き。
func apply_reference_frame(clock: float, radius: float, technique: String, stage: String,
		velocity: Vector2, travel: float, run_speed: float, approach_speed_max: float,
		params: Dictionary, world_scale: float, anchor: Vector2, tail_angle: float) -> void:
	if _last_clock > clock:
		_length = -1.0
		_run_at = -1.0
	var dt := maxf(0.0, clock - _last_clock) if _last_clock >= 0.0 else 0.0
	_last_clock = clock
	var k := radius / 96.0
	var running := stage == "run" or (technique == "sweep" and stage == "approach")
	if running and _run_at < 0.0: _run_at = clock
	if not running: _run_at = -1.0
	var burst := 1.0 + 0.5 * (1.0 - smoothstep(0.0, 0.18, clock - _run_at)) if running else 1.0
	var move := clampf(velocity.length() / maxf(approach_speed_max, 1.0), 0.0, 1.2) if technique == "sweep" else clampf((travel if travel > 0.0 else 700.0) / 700.0, 0.4, 2.0)
	var idle := 50.0 * 0.8 * k
	var braking := stage in ["brake", "stop", "end"]
	var ratio := clampf(velocity.length() / maxf(1.0, run_speed), 0.0, 1.0) if braking else 0.0
	var drive := 1.0 if running else ratio
	var length_scale := float(params.tailJet) * float(params.size)
	var width_scale := float(params.tailJetWidth) * float(params.size)
	var target := lerpf(idle, radius * 2.6 * burst * move, drive) * length_scale
	var target_width := lerpf(12.0 * k, 16.0 * k * burst * sqrt(maxf(0.2, move)), drive) * width_scale
	if _length < 0.0:
		_length = idle * length_scale
		_width = 12.0 * k * width_scale
	var response := 1.0 - exp(-dt / (0.045 / float(params.tailJetResponse) if target > _length else 0.22))
	_length = lerpf(_length, target, response)
	_width = lerpf(_width, target_width, response)
	visible = float(params.intensity) > 0.0 and length_scale > 0.0 and width_scale > 0.0 and world_scale > 0.0
	if not visible: return
	position = anchor
	rotation = tail_angle + PI * 1.5
	scale = Vector2.ONE / world_scale
	modulate.a = minf(1.0, float(params.intensity))
	_draw_density(clock, radius, world_scale, params)

func _draw_density(clock: float, radius: float, world_scale: float, params: Dictionary) -> void:
	var overlap := 24.0 * radius / 96.0
	var length := (_length + overlap) * world_scale
	var width := _width * world_scale
	var samples: Array[Vector3] = []
	var max_radius := 0.0
	var x := 0.0
	while x < length:
		var u := x / length
		var flow := 0.88 + 0.12 * sin(x * 0.55 - clock * 39.0)
		var w := maxf(0.12, width * pow(1.0-u, 0.62) * flow * (0.94 + 0.06 * sin(x * 0.9 - clock * 24.0)))
		var taper := smoothstep(0.0, minf(2.0, length*0.1), x) * (1.0-smoothstep(0.84,1.0,u))
		for layer in 3:
			var r: float = w * [1.5, 0.85, 0.32][layer] * taper
			if r > 0.1:
				samples.append(Vector3(x,r,layer))
				max_radius = maxf(max_radius,r)
		x += 0.55
	var size := Vector2i(maxi(192,ceili(max_radius*2.0+16.0)), maxi(512,ceili(_length*world_scale+80.0)))
	if density_view.size != size:
		density_view.size = size
		color_view.size = size
		_glow_view.size = size
	var origin := Vector2(size.x*0.5,size.y-40.0)
	for sprite: Sprite2D in [body,glow]:
		sprite.position = Vector2(size)*0.5-origin
		sprite.scale = Vector2.ONE
	_shape_material.set_shader_parameter("field_size", Vector2(size))
	_shape_material.set_shader_parameter("clock", clock)
	_shape_material.set_shader_parameter("outer_color", Color(params.tailOuterColor))
	_shape_material.set_shader_parameter("inner_color", Color(params.tailJetColor))
	_shape_material.set_shader_parameter("core_color", Color(params.tailCoreColor))
	_reference_glow.set_shader_parameter("field_size", Vector2(size))
	_batch.begin()
	for sample in samples:
		var channel := Color(1,0,0,1) if sample.z == 0.0 else (Color(0,1,0,1) if sample.z == 1.0 else Color(0,0,1,1))
		_batch.add_rect(Vector2(origin.x,origin.y-sample.x),Vector2(sample.y,1.5),0.0,channel)
	_batch.end()
	density_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	color_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_glow_view.render_target_update_mode = SubViewport.UPDATE_ONCE
