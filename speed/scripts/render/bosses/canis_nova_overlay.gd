## canisNovaImplode の滑らかな暗転と、実際の大星画像の発光。
extends Node2D

const DARK_SHADER := preload("res://shaders/canis_nova_dark.gdshader")
const STAR_SHADER := preload("res://shaders/canis_nova_star_light.gdshader")
const STAR_TEXTURE := preload("res://assets/pixel/canis_major/large_star.png")
const NOVA_DISPLAY := preload("res://scripts/render/bosses/canis_nova.gd")
var dark: ColorRect
var star: Sprite2D
var dark_copy: BackBufferCopy
var star_copy: BackBufferCopy

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dark_copy = BackBufferCopy.new()
	dark_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(dark_copy)
	dark = ColorRect.new()
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dark_material := ShaderMaterial.new()
	dark_material.shader = DARK_SHADER
	dark.material = dark_material
	add_child(dark)
	star_copy = BackBufferCopy.new()
	star_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(star_copy)
	star = Sprite2D.new()
	star.texture = STAR_TEXTURE
	var star_material := ShaderMaterial.new()
	star_material.shader = STAR_SHADER
	star_material.set_shader_parameter("sprite_pixels",STAR_TEXTURE)
	star.material = star_material
	add_child(star)
	clear()

func clear() -> void:
	if dark!=null: dark.hide()
	if star!=null: star.hide()
	if dark_copy!=null: dark_copy.hide()
	if star_copy!=null: star_copy.hide()

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
		(dark.material as ShaderMaterial).set_shader_parameter("linear_target",get_viewport().use_hdr_2d)
		dark_copy.show()
		dark.show()
	else:
		dark_copy.hide()
		dark.hide()
	var power := NOVA_DISPLAY.flash(t)
	if power<=0.0:
		star.hide()
		star_copy.hide()
		return
	var diameter := float(nova.radius)*(0.18+power*0.55)*2.0
	var factor := diameter/maxf(STAR_TEXTURE.get_width(),STAR_TEXTURE.get_height())
	star.position = source
	star.rotation = facing
	star.scale = Vector2.ONE*factor
	var material := star.material as ShaderMaterial
	material.set_shader_parameter("opacity",power*gain)
	material.set_shader_parameter("white_add",0.28*power*gain)
	material.set_shader_parameter("linear_target",get_viewport().use_hdr_2d)
	star_copy.show()
	star.show()
