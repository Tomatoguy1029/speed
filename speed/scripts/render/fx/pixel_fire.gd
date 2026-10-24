## 共通ピクセル炎。実粒子→RGB密度場→変形/画素化/Alpha補正→色面→独立した発光。
## 粒子は1つのMultiMeshへまとめ、粒ごとのNodeを作らない。
@tool
class_name PixelFire
extends Node2D

@export var settings: PixelFireSettings:
	set(value):
		if settings != null and settings.changed.is_connected(_settings_changed):
			settings.changed.disconnect(_settings_changed)
		settings = value
		if settings != null:
			settings.changed.connect(_settings_changed)
		_settings_changed()
@export var manual := false
@export var emitting := true
var particles: Array[Dictionary] = []
var density_view: SubViewport
var color_view: SubViewport
var body: Sprite2D
var glow: Sprite2D
var _batch: InstanceBatch
var _rng := RandomNumberGenerator.new()
var _birth := Vector3.ZERO
var _clock := 0.0
var _accum := 0.0
var _remaining := -1.0
var _origin := Vector2.ZERO
var _shape_material: ShaderMaterial
var _glow_material: ShaderMaterial
var _settings_dirty := false
var settings_apply_count := 0
var density_render_count := 0

func _ready() -> void:
	if settings == null:
		settings = PixelFireSettings.new()
	_rng.seed = 42
	density_view = _viewport("FireDensity")
	_batch = InstanceBatch.new()
	var white := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	_batch.setup_texture(ImageTexture.create_from_image(white))
	var density_material := ShaderMaterial.new()
	density_material.shader = preload("res://shaders/pixel_fire_density.gdshader")
	_batch.material = density_material
	density_view.add_child(_batch)
	color_view = _viewport("FireColor")
	var color_sprite := Sprite2D.new()
	color_sprite.centered = false
	color_sprite.texture = density_view.get_texture()
	color_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shape_material = ShaderMaterial.new()
	_shape_material.shader = preload("res://shaders/pixel_fire_shape.gdshader")
	color_sprite.material = _shape_material
	color_view.add_child(color_sprite)
	glow = Sprite2D.new()
	glow.texture = color_view.get_texture()
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = preload("res://shaders/pixel_fire_glow.gdshader")
	glow.material = _glow_material
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(glow)
	body = Sprite2D.new()
	body.texture = color_view.get_texture()
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(body)
	apply_settings()

func _viewport(label: String) -> SubViewport:
	var view := SubViewport.new()
	view.name = label
	view.transparent_bg = true
	view.disable_3d = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)
	return view

func _settings_changed() -> void:
	_settings_dirty = true

func apply_settings() -> void:
	if not is_instance_valid(density_view) or settings == null:
		return
	_settings_dirty = false
	settings_apply_count += 1
	var size := settings.field_size.clamp(Vector2(32, 64), Vector2(1024, 1024))
	var resolution := Vector2i((size / maxf(1.0, settings.density_pixel_size)).ceil())
	if density_view.size != resolution:
		density_view.size = resolution
		color_view.size = resolution
	_origin = Vector2(size.x * 0.5, size.y - 40.0)
	for sprite in [body, glow]:
		sprite.position = size * 0.5 - _origin
		sprite.scale = Vector2.ONE * maxf(1.0, settings.density_pixel_size)
	for key in ["field_size", "pixel_size", "deformation", "edge_softness", "outer_color", "inner_color", "core_color"]:
		_shape_material.set_shader_parameter(key, settings.get(key))
	_shape_material.set_shader_parameter("threshold", settings.merge_threshold)
	_glow_material.set_shader_parameter("field_size", size)
	_glow_material.set_shader_parameter("radius", settings.glow_radius)
	_glow_material.set_shader_parameter("strength", settings.glow_strength)
	_render_density()

func _process(dt: float) -> void:
	if _settings_dirty:
		apply_settings()
	if not manual and not Engine.is_editor_hint():
		advance(dt)

func restart(seed_value := 42, duration := -1.0) -> void:
	particles.clear()
	_rng.seed = seed_value
	_birth = Vector3.ZERO
	_clock = 0.0
	_accum = 0.0
	_remaining = duration
	emitting = true
	_render_density()

func advance(dt: float) -> void:
	if _settings_dirty:
		apply_settings()
	if finished():
		return
	_accum += maxf(0.0, dt)
	var tick := 1.0 / maxf(1.0, float(settings.update_fps))
	if _accum < tick:
		return
	var elapsed := minf(_accum, 0.5)
	_accum = fmod(_accum, tick)
	for step_index in ceili(elapsed * 60.0):
		_simulate(minf(1.0 / 60.0, elapsed - step_index / 60.0))
	_render_density()

func warmup(seconds: float) -> void:
	for frame in ceili(seconds * 60.0):
		_simulate(1.0 / 60.0)
	_render_density()

func finished() -> bool:
	return not emitting and particles.is_empty()

func _simulate(dt: float) -> void:
	_clock += dt
	for p in particles:
		p.age += dt
		p.pos.y -= p.rise * dt
		p.pos.x += sin(p.age * 5.0 + p.phase) * float(settings.sway) * dt
	particles = particles.filter(func(p): return p.age < p.life)
	if not emitting:
		return
	var emit_dt := dt if _remaining < 0.0 else minf(dt, _remaining)
	for layer in 3:
		if settings.layer_lifetimes[layer] <= 0.0 or settings.layer_sizes[layer] <= 0.0:
			continue
		_birth[layer] += float(settings.birth_rate) * settings.layer_rates[layer] * emit_dt
		while _birth[layer] >= 1.0:
			_birth[layer] -= 1.0
			if particles.size() < int(settings.capacity):
				_spawn_particle(layer)
	if _remaining >= 0.0:
		_remaining = maxf(0.0, _remaining - dt)
		emitting = _remaining > 0.0

func _spawn_particle(layer: int) -> void:
	var source: Vector2 = settings.source_size
	var pos := Vector2.ZERO
	if settings.emission_shape != 0:
		pos.x = _rng.randf_range(-source.x * 0.5, source.x * 0.5)
	if settings.emission_shape == 2:
		pos.y = _rng.randf_range(-source.y * 0.5, source.y * 0.5)
	# 内炎と芯は同じ根元から、独立した発生量・寿命・大きさで生まれる。
	pos.x *= 1.0 - layer * 0.18
	particles.append({"pos": pos, "age": 0.0,
		"life": float(settings.lifetime) * settings.layer_lifetimes[layer] * _rng.randf_range(0.8, 1.2),
		"radius": float(settings.particle_size) * settings.layer_sizes[layer] * _rng.randf_range(0.8, 1.15),
		"rise": float(settings.rise_speed) * _rng.randf_range(0.85, 1.2), "phase": _rng.randf() * TAU, "layer": layer})

func _render_density() -> void:
	if _batch == null:
		return
	if _settings_dirty:
		apply_settings()
		return
	_batch.begin()
	density_render_count += 1
	var pixel := maxf(1.0, settings.density_pixel_size)
	for p in particles:
		var age: float = p.age / p.life
		var radius: float = p.radius * pow(1.0 - age, 0.6) * (0.7 + 0.3 * smoothstep(0.0, 0.08, age))
		var channel := Color(1, 0, 0, 1) if p.layer == 0 else (Color(0, 1, 0, 1) if p.layer == 1 else Color(0, 0, 1, 1))
		_batch.add_upright((p.pos + _origin) / pixel, radius / pixel, channel)
	_batch.end()
	_shape_material.set_shader_parameter("clock", floorf(_clock * maxf(1.0, settings.update_fps)) / maxf(1.0, settings.update_fps))
	density_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	color_view.render_target_update_mode = SubViewport.UPDATE_ONCE
