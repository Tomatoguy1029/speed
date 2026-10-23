## 再利用可能な炎1つ。原点は発生源、幅・高さはデザイン座標。
## 描画専用。seek() は同じ時刻・seedで同じ形を作り、ゲームの時計でも駆動できる。
class_name PixelFlame
extends Node2D

const FIELD_SIZE := Vector2i(224, 256)
const SOURCE := Vector2(112, 207)
const DENSITY_SHADER := preload("res://shaders/flame_density.gdshader")
const COMPOSITE_SHADER := preload("res://shaders/pixel_flame.gdshader")

@export var settings: PixelFlameSettings = preload("res://data/visuals/pixel_flame.tres")
@export var seed_value := 7
## 0 は持続燃焼。正の秒数は、発生を止めたあと残った粒が上昇して消える。
@export var emission_duration := 0.0
@export var autoplay := true

var elapsed := 0.0
var density_viewport: SubViewport
var composite: ShaderMaterial
var source_position := SOURCE
var _particles: InstanceBatch
var _sprite: Sprite2D
var _clock := 0.0
var _last_clock := -1.0
var _last_shape: Array = []

func _ready() -> void:
	density_viewport = SubViewport.new()
	density_viewport.name = "FlameDensity"
	density_viewport.size = FIELD_SIZE
	density_viewport.transparent_bg = true
	density_viewport.disable_3d = true
	density_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(density_viewport)
	_particles = InstanceBatch.new()
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	_particles.setup_texture(ImageTexture.create_from_image(white))
	var kernel := ShaderMaterial.new()
	kernel.shader = DENSITY_SHADER
	_particles.material = kernel
	density_viewport.add_child(_particles)
	composite = ShaderMaterial.new()
	composite.shader = COMPOSITE_SHADER
	_sprite = Sprite2D.new()
	_sprite.texture = density_viewport.get_texture()
	_sprite.centered = false
	_sprite.position = -SOURCE
	_sprite.material = composite
	add_child(_sprite)
	seek(elapsed)

func _process(dt: float) -> void:
	if autoplay:
		seek(elapsed + dt)

func seek(seconds: float) -> void:
	elapsed = maxf(0.0, seconds)
	_clock = elapsed * settings.speed
	if settings.animation_fps > 0.0:
		_clock = floorf(_clock * settings.animation_fps) / settings.animation_fps
	if not is_instance_valid(_particles):
		return
	settings.apply(composite)
	composite.set_shader_parameter("clock", _clock)
	var shape: Array = [settings.birth_rate, settings.source_width, settings.particle_radius,
		settings.outer_lifetime, settings.inner_lifetime, settings.core_lifetime,
		settings.rise_speed, settings.wind, settings.sway, seed_value, emission_duration]
	if _clock == _last_clock and shape == _last_shape:
		return
	_last_clock = _clock
	_last_shape = shape
	_fit_field()
	_particles.begin()
	_draw_density()
	_particles.end()

func _fit_field() -> void:
	# 調整範囲を広げても先端や横風で切れない余白を確保する。
	var life := maxf(settings.outer_lifetime, maxf(settings.inner_lifetime, settings.core_lifetime)) * 1.22
	var padding := settings.particle_radius * 2.0 + 28.0
	var width := maxi(FIELD_SIZE.x, ceili(settings.source_width + (absf(settings.wind) * life + settings.sway * 1.3 + padding) * 2.0))
	var height := maxi(FIELD_SIZE.y, ceili(settings.rise_speed * life * 1.18 + 22.0 * life * life + padding + 49.0))
	var bounds := Vector2i(width, height)
	if bounds != density_viewport.size:
		density_viewport.size = bounds
	source_position = Vector2(width * 0.5, height - 49.0)
	_sprite.position = -source_position

func _random(index: int, salt: int) -> float:
	# 整数hash。描画順・他のゲーム乱数・seekの順序から独立させる。
	var value := (index * 374761393 + salt * 668265263 + seed_value * 1274126177) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return float(value ^ (value >> 16)) / 2147483647.0

func _draw_density() -> void:
	var lifetimes := [settings.outer_lifetime, settings.inner_lifetime, settings.core_lifetime]
	for layer in 3:
		var rate := settings.birth_rate
		var lifetime: float = lifetimes[layer]
		var last := floori(_clock * rate)
		var first := maxi(0, floori((_clock - lifetime * 1.25) * rate))
		if emission_duration > 0.0:
			last = mini(last, ceili(emission_duration * rate) - 1)
		for index in range(first, last + 1):
			var salt := 19 + layer * 71
			var born := float(index) / rate
			var age := _clock - born
			var x := (_random(index, salt) - 0.5) * settings.source_width
			var edge := absf(x) / maxf(1.0, settings.source_width * 0.5)
			var life := lifetime * lerpf(0.8, 1.22, _random(index, salt + 1)) * (1.0 - edge * 0.22)
			if age < 0.0 or age >= life:
				continue
			var progress := age / life
			var radius := settings.particle_radius * lerpf(0.82, 1.2, _random(index, salt + 2))
			radius *= pow(1.0 - progress, 0.72) * (1.0 - layer * 0.12)
			var phase := born * 4.2 + x * 0.065
			var drift := sin(phase + age * 4.0) * settings.sway * progress
			drift += sin(age * 7.0 + phase) * settings.sway * progress * 0.3
			var rise := settings.rise_speed * age * lerpf(0.85, 1.18, _random(index, salt + 3)) + 22.0 * age * age
			var center := source_position + Vector2(x * (1.0 - progress * 0.36) + drift + settings.wind * age, -rise)
			# 縦長の粒が根元で結合し、縮小した粒が先端で千切れる。
			var channels := [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]
			var color: Color = channels[layer]
			color *= smoothstep(0.0, 0.045, age) * (1.0 - smoothstep(0.82, 1.0, progress))
			color.a = progress
			_particles.add_upright(center, radius, color)
