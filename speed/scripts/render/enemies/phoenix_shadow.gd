## ぼかした実画像の半影・本影と、背後の光だまり。
extends Node2D

const SOURCE := preload("res://assets/effects/reference/phoenix_shadow.png")
const BLUR := preload("res://shaders/phoenix_shadow_blur.gdshader")
const POOL := preload("res://shaders/phoenix_pool.gdshader")
const SOURCE_SIZE := Vector2(177, 134)

class Shadow:
	var horizontal: SubViewport
	var vertical: SubViewport
	var h_rect: ColorRect
	var v_rect: ColorRect
	var h_material: ShaderMaterial
	var v_material: ShaderMaterial
	var sprite: Sprite2D

var _pool: Sprite2D
var _pool_material: ShaderMaterial
var _outer: Shadow
var _inner: Shadow

func _ready() -> void:
	_pool = Sprite2D.new()
	_pool.texture = SOURCE
	_pool_material = ShaderMaterial.new()
	_pool_material.shader = POOL
	_pool.material = _pool_material
	add_child(_pool)
	_outer = _make_shadow()
	_inner = _make_shadow()

func _make_shadow() -> Shadow:
	var result := Shadow.new()
	result.horizontal = SubViewport.new()
	result.horizontal.transparent_bg = true
	result.horizontal.disable_3d = true
	result.horizontal.world_2d = World2D.new()
	add_child(result.horizontal)
	result.h_rect = ColorRect.new()
	result.h_material = ShaderMaterial.new()
	result.h_material.shader = BLUR
	result.h_material.set_shader_parameter("source_texture", SOURCE)
	result.h_material.set_shader_parameter("source_size", SOURCE_SIZE)
	result.h_material.set_shader_parameter("direction", Vector2.RIGHT)
	result.h_rect.material = result.h_material
	result.horizontal.add_child(result.h_rect)
	result.vertical = SubViewport.new()
	result.vertical.transparent_bg = true
	result.vertical.disable_3d = true
	result.vertical.world_2d = World2D.new()
	add_child(result.vertical)
	result.v_rect = ColorRect.new()
	result.v_material = ShaderMaterial.new()
	result.v_material.shader = BLUR
	result.v_material.set_shader_parameter("source_texture", result.horizontal.get_texture())
	result.v_material.set_shader_parameter("direction", Vector2.DOWN)
	result.v_material.set_shader_parameter("padding", Vector2.ZERO)
	result.v_rect.material = result.v_material
	result.vertical.add_child(result.v_rect)
	result.sprite = Sprite2D.new()
	result.sprite.texture = result.vertical.get_texture()
	result.sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(result.sprite)
	return result

## zoom はワールド座標から実画面画素への倍率。
func apply(anchor: Vector2, sprite_radius: float, angle: float, radius: float, charge: float, dive: float, size: float, intensity: float, zoom: float, colors: Array[Color]) -> void:
	position = anchor
	var h := (1.0 - charge) * 0.8 + 0.2 * (1.0 - dive)
	var pool_radius := radius * (1.0 + 0.3 * h)
	_pool.scale = Vector2(pool_radius * 2.0 / SOURCE_SIZE.x, pool_radius * 2.0 / SOURCE_SIZE.y)
	_pool_material.set_shader_parameter("center_color", colors[0])
	_pool_material.set_shader_parameter("middle_color", colors[1])
	_pool_material.set_shader_parameter("edge_color", colors[2])
	_pool_material.set_shader_parameter("center_alpha", (0.22 + 0.45 * charge) * intensity)
	_pool_material.set_shader_parameter("middle_alpha", (0.10 + 0.22 * charge) * intensity)
	_update_shadow(_outer, sprite_radius, angle, 1.35 + 0.6 * h, (2 + 18 * h) * size, (0.25 + 0.35 * (1 - h)) * intensity, zoom)
	_update_shadow(_inner, sprite_radius, angle, (0.55 + 0.45 * charge) * (1 + 0.15 * h), (1 + 9 * h) * size, minf(1, (0.45 + 0.5 * (1 - h)) * intensity), zoom)

func _update_shadow(shadow: Shadow, sprite_radius: float, angle: float, size: float, blur: float, alpha: float, zoom: float) -> void:
	var world_pixel := 2.0 * sprite_radius * size / 137.0
	var sigma := blur / maxf(0.000001, world_pixel * zoom)
	var pad := ceili(sigma * 3.0) + 1
	var dimensions := Vector2i(SOURCE_SIZE) + Vector2i.ONE * pad * 2
	if shadow.horizontal.size != dimensions:
		shadow.horizontal.size = dimensions
		shadow.vertical.size = dimensions
		shadow.h_rect.size = Vector2(dimensions)
		shadow.v_rect.size = Vector2(dimensions)
	shadow.h_material.set_shader_parameter("output_size", Vector2(dimensions))
	shadow.h_material.set_shader_parameter("padding", Vector2.ONE * pad)
	shadow.h_material.set_shader_parameter("sigma", sigma)
	shadow.v_material.set_shader_parameter("source_size", Vector2(dimensions))
	shadow.v_material.set_shader_parameter("output_size", Vector2(dimensions))
	shadow.v_material.set_shader_parameter("sigma", sigma)
	shadow.sprite.rotation = angle
	shadow.sprite.scale = Vector2.ONE * world_pixel
	shadow.sprite.modulate.a = clampf(alpha, 0.0, 1.0)
	shadow.horizontal.render_target_update_mode = SubViewport.UPDATE_ONCE
	shadow.vertical.render_target_update_mode = SubViewport.UPDATE_ONCE
