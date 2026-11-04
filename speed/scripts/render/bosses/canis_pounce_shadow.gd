## 試作 canisDraw の着地点の影。7部位の実画像を、画面5pxのガウスでぼかす。
extends Node2D

const BLUR := preload("res://shaders/canis_shadow_blur.gdshader")
const COMPOSITE := preload("res://shaders/fx_reference_composite.gdshader")
const NAMES := ["Tail","RearLeftLeg","RearRightLeg","FrontLeftLeg","FrontRightLeg","Body","Head"]

class BlurImage:
	var source: Texture2D
	var horizontal: SubViewport
	var vertical: SubViewport
	var h_rect: ColorRect
	var v_rect: ColorRect
	var h_material: ShaderMaterial
	var v_material: ShaderMaterial

var _images: Dictionary = {}
var _parts: Dictionary = {}
var _last_sigma := -1.0
var _source_reach := 0.0
var _mask: SubViewport
var _rig: Node2D
var _display: Sprite2D
var _material: ShaderMaterial

func setup(source_parts: Node2D) -> void:
	show_behind_parent = true
	z_index = -3
	_mask = SubViewport.new()
	_mask.transparent_bg = true
	_mask.disable_3d = true
	_mask.use_hdr_2d = false
	_mask.world_2d = World2D.new()
	add_child(_mask)
	_rig = Node2D.new()
	_mask.add_child(_rig)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	_display = Sprite2D.new()
	_display.texture = _mask.get_texture()
	_material = ShaderMaterial.new()
	_material.shader = COMPOSITE
	_material.set_shader_parameter("color_pixels",_display.texture)
	_material.set_shader_parameter("light_pixels",_display.texture)
	_material.set_shader_parameter("has_light",false)
	_display.material = _material
	add_child(_display)
	for name: String in NAMES:
		var source_node := source_parts.get_node(name) as Node2D
		var source := source_node.get_node("Sprite") as Sprite2D
		var texture: Texture2D = (source.texture as CanvasTexture).diffuse_texture if source.texture is CanvasTexture else source.texture
		_source_reach = maxf(_source_reach,source_node.position.length()+source.position.length()+texture.get_size().length()*0.5)
		var key := texture.get_instance_id()
		if not _images.has(key): _images[key] = _make_image(texture)
		var image: BlurImage = _images[key]
		var part := Node2D.new()
		part.position = source_node.position
		_rig.add_child(part)
		var sprite := Sprite2D.new()
		sprite.texture = image.vertical.get_texture()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.position = source.position
		sprite.flip_h = source.flip_h
		part.add_child(sprite)
		_parts[name] = part
	visible = false

func _make_image(source: Texture2D) -> BlurImage:
	var image := BlurImage.new()
	image.source = source
	image.horizontal = SubViewport.new()
	image.horizontal.transparent_bg = true
	image.horizontal.disable_3d = true
	image.horizontal.world_2d = World2D.new()
	add_child(image.horizontal)
	image.h_rect = ColorRect.new()
	image.h_material = ShaderMaterial.new()
	image.h_material.shader = BLUR
	image.h_material.set_shader_parameter("source_texture",source)
	image.h_material.set_shader_parameter("source_size",source.get_size())
	image.h_material.set_shader_parameter("direction",Vector2.RIGHT)
	image.h_rect.material = image.h_material
	image.horizontal.add_child(image.h_rect)
	image.vertical = SubViewport.new()
	image.vertical.transparent_bg = true
	image.vertical.disable_3d = true
	image.vertical.world_2d = World2D.new()
	add_child(image.vertical)
	image.v_rect = ColorRect.new()
	image.v_material = ShaderMaterial.new()
	image.v_material.shader = BLUR
	image.v_material.set_shader_parameter("source_texture",image.horizontal.get_texture())
	image.v_material.set_shader_parameter("direction",Vector2.DOWN)
	image.v_material.set_shader_parameter("padding",Vector2.ZERO)
	image.v_rect.material = image.v_material
	image.vertical.add_child(image.v_rect)
	return image

func apply(body: Dictionary, attack: Dictionary, gait: float, world_to_screen: float) -> void:
	var motion: Dictionary = attack.get("pounce_motion",{})
	visible = not motion.is_empty() and not bool(motion.get("jumping",false)) and not bool(motion.get("done",false)) and int(attack.get("stage",5))==0 and attack.get("aim") is Vector2
	if not visible: return
	var k := float(body.radius)/100.0
	if k<=0.0 or world_to_screen<=0.0:
		visible = false
		return
	position = (get_parent() as Node2D).to_local(attack.aim)
	rotation = -float(body.facing)
	scale = Vector2.ONE/world_to_screen
	var progress := clampf(float(motion.stage_time)/maxf(float(motion.warn_time),0.001),0.0,1.0)
	_rig.modulate.a = 0.28*progress
	_rig.rotation = float(body.facing)-PI/2.0
	_rig.scale = Vector2.ONE*(k*world_to_screen)
	_material.set_shader_parameter("linear_target",get_viewport().use_hdr_2d)
	for i in 4:
		var name: String = ["RearLeftLeg","RearRightLeg","FrontLeftLeg","FrontRightLeg"][i]
		(_parts[name] as Node2D).rotation = sin(gait+(0.0 if i==0 or i==3 else PI))*0.015
	(_parts.Tail as Node2D).rotation = sin(gait*0.4)*0.07
	var sigma := 5.0/(k*world_to_screen)
	if not is_equal_approx(sigma,_last_sigma):
		_last_sigma = sigma
		var padding := ceili(sigma*3.0)+1
		var mask_side := ceili((_source_reach+float(padding)*sqrt(2.0))*k*world_to_screen*2.0)+2
		_mask.size = Vector2i.ONE*maxi(mask_side,2)
		_rig.position = Vector2(_mask.size)*0.5
		for image: BlurImage in _images.values():
			var dimensions := Vector2i(image.source.get_size())+Vector2i.ONE*padding*2
			image.horizontal.size = dimensions
			image.vertical.size = dimensions
			image.h_rect.size = Vector2(dimensions)
			image.v_rect.size = Vector2(dimensions)
			image.h_material.set_shader_parameter("output_size",Vector2(dimensions))
			image.h_material.set_shader_parameter("padding",Vector2.ONE*padding)
			image.h_material.set_shader_parameter("sigma",sigma)
			image.v_material.set_shader_parameter("source_size",Vector2(dimensions))
			image.v_material.set_shader_parameter("output_size",Vector2(dimensions))
			image.v_material.set_shader_parameter("sigma",sigma)
			image.horizontal.render_target_update_mode = SubViewport.UPDATE_ONCE
			image.vertical.render_target_update_mode = SubViewport.UPDATE_ONCE
	_mask.render_target_update_mode = SubViewport.UPDATE_ONCE
