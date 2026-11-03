extends WeaponVisual
## 快進撃：機体の形に沿って揺らめくオーラ。焼いた距離マスクとノイズを shader で読み、強さに応じて太さと色（銀→青→金）を変える。
## ブースト中は倒した数、ブーストのあとは時間とともに弱まる強さに、なめらかに近づける。倒した瞬間は縁が白く光って膨らむ。

## 戦闘エフェクトツールで調整する shader
const TUNED_SHADERS := [preload("res://shaders/build_aura.gdshader")]
var _aura: Sprite2D
var _level := 0.0

func setup_frame(parent: Node2D) -> void:
	_level = -1.0
	_setup(parent)

func _setup(parent: Node2D) -> void:
	_aura = Sprite2D.new()
	_aura.texture = preload("res://assets/effects/build/airship_aura_mask.png")
	_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/build_aura.gdshader")
	mat.set_shader_parameter("noise_tex", preload("res://assets/effects/build/aura_noise.png"))
	_aura.material = mat
	_aura.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
	parent.add_child(_aura)
	node = _aura

func frame_tick(dt: float, pos: Vector2, heading: Vector2, scale: float, tracing: bool, power: Dictionary, clock: float, enabled: bool) -> void:
	_aura.visible = enabled
	if not enabled: return
	var target: float = minf(1.0,float(power.kills)/float(power.target_kills)) if tracing else float(power.strength)
	if _level<0.0: _level = target
	else: _level += (target-_level)*minf(1.0,dt*12.0)
	_aura.position = pos+Vector2(0,5.0*scale).rotated(heading.angle()+PI*0.5)
	_aura.rotation = heading.angle()+PI*0.5
	_aura.scale = Vector2.ONE*scale*EFFECT_SETTINGS.number("trait/rampage","effect_scale",1.0)
	var mat: ShaderMaterial = _aura.material
	mat.set_shader_parameter("strength",_level)
	mat.set_shader_parameter("pop",power.pop)
	mat.set_shader_parameter("clock",clock/maxf(0.01,EFFECT_SETTINGS.number("trait/rampage","duration_scale",1.0)))
	mat.set_shader_parameter("pixel_scale",EFFECT_SETTINGS.number("trait/rampage","pixel_scale",1.0))
	mat.set_shader_parameter("tint",EFFECT_SETTINGS.tinted("trait/rampage",Color.WHITE))
	ShaderTuning.apply(mat,"trait/rampage")
