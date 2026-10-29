## ボスの時間切れ演出。AIの選択処理は各ボスが持つ。
extends BossActor
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@onready var timeline: AnimationPlayer = $Timeline

var final_strike_t := -1.0
var _final_start := 0.0
var _final_charge := 1.0
var _final_beam: Line2D

func begin_final_strike(charge: float) -> void:
	if final_strike_t >= 0.0:
		return
	final_strike_t = 0.0
	_final_start = run_state.time
	_final_charge = maxf(0.1, charge)
	timeline.stop()
	_final_beam = Line2D.new()
	_final_beam.top_level = true
	_final_beam.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	_final_beam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_final_beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_final_beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	var pixels := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	_final_beam.texture = ImageTexture.create_from_image(pixels)
	_final_beam.material = ShaderMaterial.new()
	_final_beam.material.shader = preload("res://shaders/hydra_energy.gdshader")
	add_child(_final_beam)

func _final_strike_tick(dt: float) -> void:
	final_strike_t = run_state.time - _final_start
	var widen_time := float(def.params.final_widen_time)
	var widen := clampf((final_strike_t - (_final_charge - widen_time)) / widen_time, 0.0, 1.0)
	var t := table
	var i := body
	var d := run_state.ship_pos - t.pos[i]
	t.vel[i] = Vector2.ZERO
	t.facing[i] += clampf(Geom.angle_diff(d.angle(), t.facing[i]), -def.turn * dt, def.turn * dt)
	t.guard[i] = 1.0
	t.charge[i] = clampf(final_strike_t / _final_charge, 0.0, 1.0)
	var points := PackedVector2Array([t.pos[i], t.pos[i] + d.normalized() * float(def.params.final_reach)])
	var width := lerpf(float(def.params.final_warn_width), float(def.params.final_beam_width), widen * widen)
	_final_beam.points = points
	_final_beam.width = width
	var mat := _final_beam.material as ShaderMaterial
	mat.set_shader_parameter("tint", EFFECT_SETTINGS.tinted("boss/final_strike", Color(1, 0.25, 0.4)))
	mat.set_shader_parameter("clock", run_state.time)
	mat.set_shader_parameter("warning", final_strike_t < _final_charge - widen_time)
	mat.set_shader_parameter("span", points[0].distance_to(points[1]))
	mat.set_shader_parameter("thickness", width)

func _process(delta: float) -> void:
	super(delta)
	# 一撃が当たったら、敗北の停止の間に光を消し、爆発と GAME OVER を見せる。
	if _final_beam != null and run_state.phase != RunState.Phase.PLAY:
		_final_beam.modulate.a = move_toward(_final_beam.modulate.a, 0.0, delta / maxf(0.01, ctx.cfg.death_freeze_time))

