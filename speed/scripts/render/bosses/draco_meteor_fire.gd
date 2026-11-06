## 飛ぶ隕石の炎。pixelFX fire/fireball の連番を紫へ塗り替え、隕石の下に全体、後ろ半分だけ隕石の上にも重ねる。
extends Node2D
const SHEET := preload("res://assets/effects/reference/canis/fireball.png")
const SHADER := preload("res://shaders/draco_meteor_fire.gdshader")
const ROCK := preload("res://assets/pixel/meteor_0.png")
const FRAME_SIZE := Vector2(136,56)
const PIVOT := Vector2(112,28)
const RIM := [[0.35,0],[0.8,1],[1.25,2],[1.7,3]]
var _under: ShaderMaterial
var _over: ShaderMaterial
var _pool: Array[Sprite2D] = []
var _used := 0
var _shards: Array[Sprite2D] = []
var _shard_used := 0

func _ready() -> void:
	top_level = true
	z_as_relative = false
	_under = ShaderMaterial.new()
	_under.shader = SHADER
	_over = ShaderMaterial.new()
	_over.shader = SHADER
	_over.set_shader_parameter("rear_only",true)

func _sprite(frame_time: float, material_used: ShaderMaterial, layer: int) -> Sprite2D:
	if _used>=_pool.size():
		var made := Sprite2D.new()
		made.texture = SHEET
		made.region_enabled = true
		made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		made.offset = FRAME_SIZE*0.5-PIVOT
		made.z_as_relative = false
		add_child(made)
		_pool.append(made)
	var sprite := _pool[_used]
	_used += 1
	var frame := posmod(floori(frame_time*30.0),36)
	sprite.region_rect = Rect2(Vector2(frame%4,floori(float(frame)/4.0))*FRAME_SIZE,FRAME_SIZE)
	sprite.material = material_used
	sprite.z_index = layer
	sprite.visible = true
	return sprite

func _shard() -> Sprite2D:
	if _shard_used>=_shards.size():
		var made := Sprite2D.new()
		made.texture = ROCK
		made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		made.z_as_relative = false
		made.z_index = 5
		add_child(made)
		_shards.append(made)
	var sprite := _shards[_shard_used]
	_shard_used += 1
	sprite.visible = true
	return sprite

func apply_frame(rows: Array, clock: float, shards: Array = []) -> void:
	_shard_used = 0
	for row: Dictionary in shards:
		var sprite := _shard()
		sprite.position = row.position
		sprite.rotation = float(row.angle)
		sprite.scale = Vector2.ONE*float(row.radius)*2.0/maxf(ROCK.get_width(),ROCK.get_height())
		sprite.modulate.a = float(row.alpha)
	for i in range(_shard_used,_shards.size()): _shards[i].visible = false
	_used = 0
	for row: Dictionary in rows:
		var alpha := float(row.alpha)
		if alpha<=0.01: continue
		var at: Vector2 = row.position
		var angle := float(row.angle)
		var radius := float(row.radius)
		var time := absf(clock+float(row.seed)*0.37)
		var under := _sprite(time,_under,0)
		under.position = at
		under.rotation = angle
		under.scale = Vector2(radius/17.0,radius/8.5)
		under.modulate.a = alpha
		for side: float in [-1.0,1.0]:
			for entry: Array in RIM:
				var turn := float(entry[0])
				var rim := _sprite(time+int(entry[1])*0.21+(side+1.0)*0.3,_under,0)
				rim.position = at+Vector2.from_angle(angle+side*turn)*radius*0.8
				rim.rotation = angle-side*turn*0.12
				rim.scale = Vector2(radius/36.0,radius/22.0)
				rim.modulate.a = alpha
		if row.get("over",true):
			var over := _sprite(time,_over,5)
			over.position = at
			over.rotation = angle
			over.scale = under.scale
			over.modulate.a = alpha
	for i in range(_used,_pool.size()): _pool[i].visible = false
