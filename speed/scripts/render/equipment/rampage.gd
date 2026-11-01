extends WeaponVisual
## 快進撃：機体の形に沿って揺らめくオーラ。焼いた距離マスクとノイズを shader で読み、強さに応じて太さと色（銀→青→金）を変える。
## ブースト中は倒した数、ブーストのあとは時間とともに弱まる強さに、なめらかに近づける。倒した瞬間は縁が白く光って膨らむ。

## 戦闘エフェクトツールで調整する shader
const TUNED_SHADERS := [preload("res://shaders/build_aura.gdshader")]
var _aura: Sprite2D
var _level := 0.0

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	_aura = Sprite2D.new()
	_aura.texture = preload("res://assets/effects/build/airship_aura_mask.png")
	_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/build_aura.gdshader")
	mat.set_shader_parameter("noise_tex", preload("res://assets/effects/build/aura_noise.png"))
	_aura.material = mat
	_aura.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
	rm._layers.ship.add_child(_aura)
	node = _aura

func tick(_dt: float) -> void:
	var dt := world_dt()
	_aura.visible = active
	if not active: return
	var target: float = minf(1.0, float(behavior.kills) / float(behavior.def.params.kills)) if state.tracing else behavior.strength
	_level += (target - _level) * minf(1.0, dt * 12.0)
	# マスクの中心は機体の絵の中心から 5 テクセル後ろ（余白の差）。
	_aura.position = state.ship_pos + Vector2(0, 5.0 * cfg.character_scale).rotated(state.ship_heading.angle() + PI * 0.5)
	_aura.rotation = state.ship_heading.angle() + PI * 0.5
	_aura.scale = Vector2.ONE * cfg.character_scale * visual_number("effect_scale", 1.0)
	var mat: ShaderMaterial = _aura.material
	mat.set_shader_parameter("strength", _level)
	mat.set_shader_parameter("pop", behavior.pop)
	mat.set_shader_parameter("clock", state.world_time / maxf(0.01, visual_number("duration_scale", 1.0)))
	mat.set_shader_parameter("pixel_scale", visual_number("pixel_scale", 1.0))
	mat.set_shader_parameter("tint", visual_color(Color.WHITE))
	tune(mat)
