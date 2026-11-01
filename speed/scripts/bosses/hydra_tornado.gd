## 攻撃点列を包む渦のシェーダーと、その中を回る実スプライトの瓦礫。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
const ROCKS := [preload("res://assets/pixel/meteor_0.png"),preload("res://assets/pixel/meteor_1.png")]
@export var vortex_shader: Shader=preload("res://shaders/hydra_tornado.gdshader")
var effect_tint := Color.WHITE
var wind: Sprite2D
var stones: Array[Sprite2D]=[]
var feed_stones: Array[Sprite2D]=[]
func _visual_values() -> Dictionary:
	return EFFECT_SETTINGS.component_values(get_meta("shape_owner", "boss/shared/tornado_shader"), "shape", "boss/shared/tornado_shader")
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	wind=Sprite2D.new()
	var pixels:=Image.create(2,2,false,Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	wind.texture=ImageTexture.create_from_image(pixels)
	wind.material=ShaderMaterial.new()
	wind.material.shader=vortex_shader
	var profile: String = get_meta("shape_owner", "boss/shared/tornado_shader")
	ShaderTuning.apply(wind.material, profile, "boss/shared/tornado_shader", "shape")
	wind.set_meta("shader_tuning_profile", profile)
	wind.set_meta("shader_tuning_fallback", "boss/shared/tornado_shader")
	wind.set_meta("shader_tuning_component", "shape")
	wind.material.set_shader_parameter("tint",effect_tint * _visual_values().get("vortex_tint", Color.WHITE))
	wind.material.set_shader_parameter("pixel_size",3.0 * float(EFFECT_SETTINGS.values_for("boss/shared/tornado_shader").get("pixel_scale", 1.0)))
	wind.z_index=1
	add_child(wind)
	for i in 14:
		var rock:=Sprite2D.new()
		rock.texture=ROCKS[i%2]
		stones.append(rock)
		add_child(rock)
	for i in 3:
		var rock:=Sprite2D.new()
		rock.texture=ROCKS[i%2]
		rock.z_index=3
		feed_stones.append(rock)
		add_child(rock)
func set_effect_tint(value: Color) -> void:
	effect_tint=value
	if is_instance_valid(wind): wind.material.set_shader_parameter("tint",effect_tint * _visual_values().get("vortex_tint", Color.WHITE))
func set_pixel_size(value: float) -> void:
	if is_instance_valid(wind): wind.material.set_shader_parameter("pixel_size",value * float(EFFECT_SETTINGS.values_for("boss/shared/tornado_shader").get("pixel_scale", 1.0)))
func update_effect(effect: Dictionary, clock: float) -> void:
	var points: PackedVector2Array=effect.points
	var delta:=points[-1]-points[0]
	var span:=delta.length()
	var width: float=effect.width
	var charge: float=effect.get("fill",1.0)
	position=(points[0]+points[-1])*0.5
	rotation=delta.angle() if span>1.0 else 0.0
	wind.scale=Vector2(span+width,width)*0.5
	wind.material.set_shader_parameter("clock",clock)
	wind.material.set_shader_parameter("span",span)
	wind.material.set_shader_parameter("thickness",width)
	wind.material.set_shader_parameter("power",charge)
	for i in stones.size():
		var rock:=stones[i]
		var phase:=clock*(3.0+float(i%3)*0.3)+float(i)*TAU/7.0
		var orbit:=0.65+float(i%4)*0.09
		rock.position=Vector2(sin(phase)*(span*0.27+width*0.31),cos(phase)*width*0.32)*orbit
		rock.position=rock.position.snapped(Vector2(2,2))
		rock.rotation=clock*(1.2 if i%2==0 else -0.9)+float(i)
		var radius:=width*(0.065+float(i%3)*0.017)
		rock.scale=Vector2.ONE*radius*2.0/rock.texture.get_width()
		var shade:=0.55+0.45*(cos(phase)*0.5+0.5)
		rock.modulate=Color(shade,shade,shade,clampf(charge*float(stones.size())-i,0.0,1.0))
		rock.z_index=2 if cos(phase)>0.0 else 0
	var feed: Array=effect.get("feed",[])
	for i in feed_stones.size():
		var rock:=feed_stones[i]
		rock.visible=i<feed.size()
		if not rock.visible:continue
		var stone: Vector3=feed[i]
		rock.position=(Vector2(stone.x,stone.y)-position).rotated(-rotation)
		rock.scale=Vector2.ONE*stone.z*2.0/rock.texture.get_width()
		rock.rotation=clock*2.0+float(i)
