## canisNovaImplode の滑らかな暗転と、実際の大星画像の発光。
extends Node2D

const DARK_SHADER := preload("res://shaders/canis_nova_dark.gdshader")
const STAR_SHADER := preload("res://shaders/canis_nova_star_light.gdshader")
const STAR_TEXTURE := preload("res://assets/pixel/canis_major/large_star.png")
const NOVA_DISPLAY := preload("res://scripts/render/bosses/canis_nova.gd")
var dark: ColorRect
var star: Sprite2D
var star_light: Sprite2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dark = ColorRect.new()
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dark_material := ShaderMaterial.new()
	dark_material.shader = DARK_SHADER
	dark.material = dark_material
	add_child(dark)
	star = Sprite2D.new()
	star.texture = STAR_TEXTURE
	add_child(star)
	star_light = Sprite2D.new()
	star_light.texture = STAR_TEXTURE
	var star_material := ShaderMaterial.new()
	star_material.shader = STAR_SHADER
	star_light.material = star_material
	add_child(star_light)
	clear()

func clear() -> void:
	if dark!=null: dark.hide()
	if star!=null: star.hide()
	if star_light!=null: star_light.hide()

func update_overlay(nova: Dictionary, params: Dictionary, facing: float, world_to_screen: float) -> void:
	if nova.is_empty() or world_to_screen<=0.0:
		clear()
		return
	var t := float(nova.age)-float(nova.warn)
	var duration := float(params.novaGatherTime)
	var gain := minf(1.0,float(params.intensity))
	var source: Vector2 = nova.source
	if t>=-duration and t<0.0:
		var still := minf(0.08,duration*0.2)
		var k := smoothstep(-duration,-still,t)
		var radius := lerpf(420.0,30.0,k)/world_to_screen
		dark.size = Vector2.ONE*radius*2.0
		dark.position = source-Vector2.ONE*radius
		(dark.material as ShaderMaterial).set_shader_parameter("strength",0.6*k*gain)
		dark.show()
	else: dark.hide()
	var power := NOVA_DISPLAY.flash(t)
	if power<=0.0:
		star.hide()
		star_light.hide()
		return
	var diameter := float(nova.radius)*(0.18+power*0.55)*2.0
	var factor := diameter/maxf(STAR_TEXTURE.get_width(),STAR_TEXTURE.get_height())
	for sprite: Sprite2D in [star,star_light]:
		sprite.position = source
		sprite.rotation = facing
		sprite.scale = Vector2.ONE*factor
		sprite.show()
	star.modulate = Color(1,1,1,power*gain)
	star_light.modulate = Color(1,1,1,0.28*power*gain)
