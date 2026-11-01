## 機雷の爆発だけを反復する。武器本体の表示と保存profile・shader・破片を共用する。
extends "res://scripts/render/attacks/zone_bomber.gd"

const MINE_VISUAL := preload("res://scripts/render/equipment/mines.gd")
var _debris_painter: PixelPainter
var _debris: Array[Dictionary] = []
var _radius := 0.0
var _fit_revision := -1
var _fit_size := Vector2.ZERO

func burst_shader() -> Shader:
	return MINE_VISUAL.TUNED_SHADERS[0]

func _create_blasts() -> void:
	super._create_blasts()
	_blasts.key = MINE_VISUAL.EFFECT_KEY
	if is_instance_valid(_debris_painter):
		remove_child(_debris_painter)
		_debris_painter.queue_free()
	_debris_painter = PixelPainter.new()
	_debris_painter.setup_painter(_blasts.px)
	add_child(_debris_painter)
	move_child(_debris_painter, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_preview_seed * 104729.0)
	_debris = MINE_VISUAL.explosion_debris(rng)

func _spawn(at: Vector2, radius: float, age: float) -> void:
	_radius = MINE_VISUAL.blast_radius(radius, _blasts.px)
	_fit_revision = -1
	_blasts.add(at, _radius, -age)
	_blasts.step(0.0)

func preview_step(dt: float) -> void:
	super.preview_step(dt)
	_fit_preview()
	_debris_painter.begin()
	MINE_VISUAL.draw_explosion_debris(_debris_painter, Vector2.ZERO, _debris, _preview_age,
		ShaderTuning.burst_time_scale(MINE_VISUAL.EFFECT_KEY), ShaderTuning.burst_number(MINE_VISUAL.EFFECT_KEY, "glow_energy", 1.0))
	_debris_painter.end()

func _fit_preview() -> void:
	var revision: int = ShaderTuning.SETTINGS.preview_revision
	var viewport_size := get_viewport().get_visible_rect().size
	if revision == _fit_revision and viewport_size == _fit_size: return
	var mat := ShaderMaterial.new()
	mat.shader = burst_shader()
	ShaderTuning.apply(mat, MINE_VISUAL.EFFECT_KEY)
	var extent := (ceilf(_radius * BlastBursts._reach(mat, _radius)) + 3.0) * _blasts.px
	for debris in _debris: extent = maxf(extent, float(debris.v) * _blasts.px)
	var available := maxf(1.0, minf(viewport_size.x, viewport_size.y) * 0.5 - 16.0)
	scale = Vector2.ONE * minf(1.0, available / maxf(1.0, extent))
	_fit_revision = revision
	_fit_size = viewport_size

func _preview_life() -> float:
	var mat := ShaderMaterial.new()
	mat.shader = burst_shader()
	ShaderTuning.apply(mat, MINE_VISUAL.EFFECT_KEY)
	return maxf(0.4, BlastBursts._life(mat)) * ShaderTuning.burst_time_scale(MINE_VISUAL.EFFECT_KEY)
