## 承認された青い bomber_burst を、本番shaderとmeshで描く。
extends Node2D

const SETTINGS := preload("res://data/visuals/canis_burst.tres")
const SHADER := preload("res://shaders/bomber_burst.gdshader")
const NOISE := preload("res://assets/effects/build/burst_noise.tres")
const BURSTS := preload("res://scripts/render/fx/blast_bursts.gd")
const BODY_MESH := preload("res://scripts/render/fx/fire_bursts.gd")
const FX := preload("res://data/visuals/fx_reference.tres")
var _params := {}
var _items: Dictionary = {}

func _ready() -> void:
	_params = FX.for_id("O-blaze")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _start(id: int, at: Vector2, radius: float, started: float) -> void:
	if _params.is_empty(): _params = FX.for_id("O-blaze")
	var root := Node2D.new()
	root.position = at
	var px := float(SETTINGS.get_meta("reference_pixel_size"))
	var reference_radius := float(SETTINGS.get_meta("reference_radius"))
	var shader_radius := reference_radius/px*float(SETTINGS.get_meta("radius_scale"))
	var half := ceilf(shader_radius*(float(SETTINGS.get_meta("reference_reach"))+17.0/shader_radius))+3.0
	root.scale = Vector2.ONE*half*px*radius/reference_radius*float(_params.size)
	root.modulate.a = minf(1.0,float(_params.intensity))
	add_child(root)
	var materials: Array[ShaderMaterial] = []
	for mode in [1,0,2,3]:
		var surface := MeshInstance2D.new()
		surface.mesh = BODY_MESH._mesh() if mode==0 else BURSTS._particle_mesh(mode)
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		for name: String in SETTINGS.get_meta("settings"):
			mat.set_shader_parameter(name,SETTINGS.get_meta("settings")[name])
		mat.set_shader_parameter("pass_mode",mode)
		mat.set_shader_parameter("value_noise",NOISE.get_meta("texture"))
		mat.set_shader_parameter("half_cells",half)
		mat.set_shader_parameter("radius",shader_radius)
		mat.set_shader_parameter("origin",Vector2.ZERO)
		mat.set_shader_parameter("seed",float(SETTINGS.get_meta("seed")))
		surface.material = mat
		root.add_child(surface)
		materials.append(mat)
	_items[id] = {"node":root,"materials":materials,"started":started}

func apply_frame(rows: Array, clock: float) -> void:
	var duration := float(SETTINGS.get_meta("duration"))
	var fps := float(SETTINGS.get_meta("fps"))
	var live := {}
	for row: Dictionary in rows:
		var id := int(row.id)
		live[id] = true
		if not _items.has(id): _start(id,row.position,float(row.radius),float(row.started))
		var item: Dictionary = _items[id]
		var elapsed := (clock-float(item.started))/float(_params.timing)
		item.node.visible = elapsed>=0.0 and elapsed<duration
		var shader_age := floorf(maxf(0.0,elapsed)*fps)/fps/duration
		for mat: ShaderMaterial in item.materials: mat.set_shader_parameter("age",shader_age)
	for id in _items.keys():
		if live.has(id): continue
		_items[id].node.queue_free()
		_items.erase(id)
