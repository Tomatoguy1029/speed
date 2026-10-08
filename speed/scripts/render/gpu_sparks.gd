## GPU の火花（設計書 10：コンピュートの演出）。撃破の飛び散りなどの大量の火花を、
## コンピュートシェーダーで動かし、画面の大きさの絵に点として描いて重ねる。
##
## メインの RenderingDevice を使うので、Forward+ と Mobile だけで動く。Compatibility（ブラウザ）では
## available() が false になり、RenderManager は CPU の粒で代える。
class_name GpuSparks
extends TextureRect

const MAX_SPARKS := 16384
const FLOATS := 12  # pos2 vel2 life max size pad color4

var rd: RenderingDevice
var _sim_shader: RID
var _raster_shader: RID
var _sim_pipeline: RID
var _raster_pipeline: RID
var _buffer: RID
var _image: RID
var _sim_set: RID
var _raster_set: RID
var _image_size := Vector2i.ZERO
var _cursor := 0
var _pending: Array = []
var _tex := Texture2DRD.new()

func available() -> bool:
	return rd != null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stretch_mode = TextureRect.STRETCH_SCALE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	# Godot 4.6 / D3D12では現在のrgba16f読み書きパイプラインを作れない。
	# このバックエンドは既存のCPU火花を使う。VulkanのGPU経路は保つ。
	if RenderingServer.get_current_rendering_driver_name() == "d3d12":
		return
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		return
	_sim_shader = _load_shader("res://shaders/compute/sparks_sim.glsl")
	_raster_shader = _load_shader("res://shaders/compute/sparks_raster.glsl")
	if not _sim_shader.is_valid() or not _raster_shader.is_valid():
		rd = null
		return
	_sim_pipeline = rd.compute_pipeline_create(_sim_shader)
	_raster_pipeline = rd.compute_pipeline_create(_raster_shader)
	var zeros := PackedFloat32Array()
	zeros.resize(MAX_SPARKS * FLOATS)
	_buffer = rd.storage_buffer_create(zeros.size() * 4, zeros.to_byte_array())
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = 0
	u.add_id(_buffer)
	_sim_set = rd.uniform_set_create([u], _sim_shader, 0)
	texture = _tex

func _load_shader(path: String) -> RID:
	var file := load(path) as RDShaderFile
	if file == null:
		return RID()
	var spirv := file.get_spirv()
	if spirv.compile_error_compute != "":
		push_warning("GpuSparks: %s" % spirv.compile_error_compute)
		return RID()
	return rd.shader_create_from_spirv(spirv)

## 画面の大きさが変わったら、描く絵を作り直す。
func _ensure_image(size_px: Vector2i) -> void:
	if size_px == _image_size or size_px.x <= 0 or size_px.y <= 0:
		return
	if _image.is_valid():
		rd.free_rid(_image)
	_image_size = size_px
	var fmt := RDTextureFormat.new()
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.width = size_px.x
	fmt.height = size_px.y
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	_image = rd.texture_create(fmt, RDTextureView.new())
	var u0 := RDUniform.new()
	u0.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u0.binding = 0
	u0.add_id(_buffer)
	var u1 := RDUniform.new()
	u1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u1.binding = 1
	u1.add_id(_image)
	_raster_set = rd.uniform_set_create([u0, u1], _raster_shader, 0)
	_tex.texture_rd_rid = _image

## 火花を出す（次の step でまとめて GPU に送る）。
func burst(pos: Vector2, color: Color, n: int, dir: Vector2, speed: float, life := 0.7, size := 4.0) -> void:
	if rd == null:
		return
	for i in n:
		var a := randf() * TAU
		var s := speed * (0.3 + randf())
		var v := Vector2.from_angle(a) * s * 0.6 + dir * s * 0.8
		var l := life * (0.6 + randf() * 0.6)
		_pending.append([_cursor, PackedFloat32Array([pos.x, pos.y, v.x, v.y, l, l, size * (0.6 + randf() * 0.8), 0.0,
			color.r * 1.6, color.g * 1.6, color.b * 1.6, 1.0])])
		_cursor = (_cursor + 1) % MAX_SPARKS

## 1フレームぶん進めて描く。dt は演出の時間（ポーズ中は 0）。
func step(dt: float, view_center: Vector2, zoom: float) -> void:
	if rd == null:
		return
	var size_px := Vector2i(get_viewport_rect().size)
	var pending := _pending
	_pending = []
	RenderingServer.call_on_render_thread(_dispatch.bind(dt, view_center, zoom, size_px, pending))

func _dispatch(dt: float, view_center: Vector2, zoom: float, size_px: Vector2i, pending: Array) -> void:
	_ensure_image(size_px)
	if not _raster_set.is_valid():
		return
	for p in pending:
		rd.buffer_update(_buffer, p[0] * FLOATS * 4, FLOATS * 4, p[1].to_byte_array())
	var sim_pc := PackedByteArray()
	sim_pc.resize(16)
	sim_pc.encode_float(0, dt)
	sim_pc.encode_float(4, 2.5)
	sim_pc.encode_u32(8, MAX_SPARKS)
	var raster_pc := PackedByteArray()
	raster_pc.resize(32)
	raster_pc.encode_float(0, view_center.x)
	raster_pc.encode_float(4, view_center.y)
	raster_pc.encode_float(8, size_px.x)
	raster_pc.encode_float(12, size_px.y)
	raster_pc.encode_float(16, zoom)
	raster_pc.encode_u32(20, MAX_SPARKS)
	var groups := ceili(MAX_SPARKS / 64.0)
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, _sim_pipeline)
	rd.compute_list_bind_uniform_set(list, _sim_set, 0)
	rd.compute_list_set_push_constant(list, sim_pc, sim_pc.size())
	rd.compute_list_dispatch(list, groups, 1, 1)
	rd.compute_list_add_barrier(list)
	rd.compute_list_bind_compute_pipeline(list, _raster_pipeline)
	rd.compute_list_bind_uniform_set(list, _raster_set, 0)
	raster_pc.encode_u32(24, 0)
	rd.compute_list_set_push_constant(list, raster_pc, raster_pc.size())
	rd.compute_list_dispatch(list, 256, 1, 1)
	rd.compute_list_add_barrier(list)
	raster_pc.encode_u32(24, 1)
	rd.compute_list_set_push_constant(list, raster_pc, raster_pc.size())
	rd.compute_list_dispatch(list, groups, 1, 1)
	rd.compute_list_end()

func _exit_tree() -> void:
	if rd == null:
		return
	var rids := [_raster_set, _sim_set, _image, _buffer, _raster_pipeline, _sim_pipeline, _raster_shader, _sim_shader]
	RenderingServer.call_on_render_thread(func():
		for r in rids:
			if r.is_valid():
				rd.free_rid(r))
