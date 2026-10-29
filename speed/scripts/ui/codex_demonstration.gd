## 試作の実演配置を固定データとして再生する。記録は試作の描画命令（1ドット＝画面の1画素）で、
## 塗り・円・輪・線・光弾・砲口・針は試作と同じ規則のドット描画（PixelPainter）、炎は fire_burst、
## 重力レンズと空間の歪みは本番と同じ shader で描く。
extends Node2D
const FLAT := preload("res://shaders/codex_flat.gdshader")
const FIRE := preload("res://shaders/fire_burst.gdshader")
const LENS := preload("res://shaders/hole_lens.gdshader")
const RIPPLE := preload("res://shaders/space_ripple.gdshader")
const VALUE_NOISE := preload("res://assets/effects/build/value_noise.png")
const NOISE := preload("res://assets/effects/build/aura_noise.png")
const SHIP := preload("res://assets/pixel/airship.png")
const TEXTURES := {
	"ship": SHIP, "flame": preload("res://assets/pixel/airship_flame.png"),
	"canon": preload("res://assets/pixel/airship_canon.png"), "tbase": preload("res://assets/pixel/airship_turret_base.png"),
	"turret": preload("res://assets/pixel/airship_turret.png"), "armor": preload("res://assets/pixel/airship_armor.png"),
	"mine": preload("res://assets/pixel/airship_mine.png"), "probe": preload("res://assets/pixel/airship_electronic_probe.png"),
	"drone": preload("res://assets/pixel/drone.png"), "enemy_drifter": preload("res://assets/effects/build/codex_drifter.png"),
	"enemy_armored": preload("res://assets/effects/build/codex_armored.png")}
var animation: Resource
var code := ""
var key := ""
var _sprites: Array[Sprite2D] = []
var _rectangles: Array[PixelPainter] = []
## 炎・レンズ・歪みの面。種類ごとに使い回す
var _surfaces := {"fire": [], "lens": [], "ripple": []}
var _used := {}
var _sprite_count := 0
var clock := 0.0

func setup(module: Resource, prepared_animation: Resource = null) -> void:
	code = String(module.code_id)
	key = ("weapon/" if String(module.id).begins_with("W") else "trait/") + code
	var path := "res://data/codex/%s.res" % code
	animation = prepared_animation if prepared_animation != null else load(path) if ResourceLoader.exists(path) else null
	clock = 0.0

func sample(time: float) -> void:
	if animation == null: return
	clock = fposmod(time, animation.period)
	var frame: Array = animation.frames[mini(animation.frames.size() - 1, floori(clock * 30.0))]
	_sprite_count = 0
	_used = {"fire": 0, "lens": 0, "ripple": 0}
	for batch in _rectangles: batch.begin()
	var order := 0
	for command: Array in frame:
		var opcode := int(command[0])
		var z := order
		order += 1
		var tier := z / 64
		while _rectangles.size() <= tier:
			var batch := PixelPainter.new()
			batch.setup_painter(1.0)
			batch.z_index = _rectangles.size() * 64
			add_child(batch)
			batch.begin()
			_rectangles.append(batch)
		var painter := _rectangles[tier]
		var at := Vector2(command[1], command[2]) if command.size() > 2 and command[1] is float else Vector2.ZERO
		match opcode:
			0: painter.add_rect(at, Vector2(command[3], command[4]) * 0.5, command[5], _color(command, 6))
			1: _sprite(command, z)
			2: painter.disk(at, command[3], _color(command, 4))
			3: painter.thick_ring(at, command[3], int(command[4]), _color(command, 5))
			4: painter.line(at, Vector2(command[3], command[4]), _color(command, 6), int(command[5]))
			5: _fire(command, z)
			6: painter.spindle(at, command[3], command[4], command[5], command[6])
			7: _aura(command, z)
			8: painter.muzzle(at, command[3], command[4], int(command[5]))
			9: painter.bolt(at, command[3], int(command[4]), int(command[5]))
			10: _lens(at, command[3], z)
			11: _ripple(at, command[3], command[4], z)
			12:
				_sprite([1,"echo",command[1],command[2]+2.0,31*0.55,70*0.55,float(command[3])+PI*0.5,command[6],0,0,31,70],z)
				_sprites[_sprite_count-1].modulate=Color(float(command[5])/8.0,0,0,command[6])
	for batch in _rectangles: batch.end()
	for i in _sprites.size(): _sprites[i].visible = i < _sprite_count
	for kind in _surfaces:
		for i in _surfaces[kind].size(): _surfaces[kind][i].visible = i < _used[kind]

## 種類ごとの面を1枚取り出す。足りなければ作る。
func _surface(kind: String, z: int) -> CanvasItem:
	var pool: Array = _surfaces[kind]
	var index: int = _used[kind]
	_used[kind] = index + 1
	if pool.size() <= index:
		var item: CanvasItem
		var mat := ShaderMaterial.new()
		if kind == "fire":
			var mesh := MeshInstance2D.new()
			mesh.mesh = FireBursts._mesh()
			mat.shader = FIRE
			mat.set_shader_parameter("value_noise", VALUE_NOISE)
			item = mesh
		else:
			var rect := ColorRect.new()
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mat.shader = LENS if kind == "lens" else RIPPLE
			item = rect
		item.material = mat
		item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(item)
		pool.append(item)
	var surface: CanvasItem = pool[index]
	surface.visible = true
	surface.z_index = mini(z, 4095)
	return surface

## 試作の pfire：[5, x, y, 半径, 経過, 色4つ, 種]
func _fire(c: Array, z: int) -> void:
	var node := _surface("fire", z) as MeshInstance2D
	var center := Vector2(c[1], c[2]).round()
	var half := ceilf(float(c[3]) * 1.25) + 3.0
	node.position = center
	node.scale = Vector2.ONE * half
	var mat := node.material as ShaderMaterial
	mat.set_shader_parameter("half_cells", half)
	mat.set_shader_parameter("radius", c[3])
	mat.set_shader_parameter("life", c[4])
	mat.set_shader_parameter("origin", center)
	mat.set_shader_parameter("seed", c[21])
	for i in 4: mat.set_shader_parameter("c%d" % i, _color(c, 5 + i * 4))

## 試作の lens：暗黒の半径 shadow、レンズの届く範囲は shadow の7倍（最大120）。
func _lens(at: Vector2, shadow: float, z: int) -> void:
	var rect := _surface("lens", z) as ColorRect
	var reach := minf(shadow * 7.0, 120.0)
	rect.position = at - Vector2.ONE * reach
	rect.size = Vector2.ONE * reach * 2.0
	var mat := rect.material as ShaderMaterial
	mat.set_shader_parameter("half_size", reach)
	mat.set_shader_parameter("shadow", shadow)
	mat.set_shader_parameter("reach", reach)

## 試作の ripple：半径 r の帯の中を外へずらす。ずれが 0.5 ドット未満なら描かない。
func _ripple(at: Vector2, radius: float, amp: float, z: int) -> void:
	if amp < 0.5: return
	var rect := _surface("ripple", z) as ColorRect
	rect.position = Vector2.ZERO
	rect.size = Vector2(300, 170)
	var mat := rect.material as ShaderMaterial
	mat.set_shader_parameter("count", 1)
	mat.set_shader_parameter("cell", 1.0)
	var ripples: Array[Vector4] = [Vector4(at.x, at.y, radius, amp)]
	for i in 7: ripples.append(Vector4.ZERO)
	mat.set_shader_parameter("ripples", ripples)

func _color(data: Array, at: int) -> Color:
	return Color(float(data[at]),float(data[at+1]),float(data[at+2]),float(data[at+3]))

func _sprite(c: Array, z: int) -> void:
	while _sprites.size() <= _sprite_count:
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_sprites.append(sprite)
	var sprite := _sprites[_sprite_count]
	_sprite_count += 1
	var name := String(c[1])
	var echo := name.begins_with("echo")
	sprite.texture = TEXTURES.get(name,SHIP)
	sprite.region_enabled = not echo
	sprite.region_rect = Rect2(float(c[8]),float(c[9]),float(c[10]),float(c[11]))
	var source := Vector2(31,70) if echo else Vector2(c[10],c[11])
	sprite.scale = Vector2(c[4],c[5])/source
	sprite.position = Vector2(c[2],c[3])
	sprite.rotation = c[6]
	sprite.modulate = Color(1,1,1,c[7])
	sprite.z_index = mini(z,4095)
	if name == "flame": sprite.material = null
	else:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/afterimage.gdshader") if echo else FLAT
		if echo:
			mat.set_shader_parameter("clock",clock)
			mat.set_shader_parameter("noise_tex",NOISE)
			mat.set_shader_parameter("ghost",name!="echo")
			sprite.modulate=Color(0,0.0 if name=="echo0" else 0.5 if name=="echo1" else 0.9 if name=="echo2" else 0.0,0,c[7])
		else: mat.set_shader_parameter("ink",Color("#2456c8") if name.begins_with("enemy_") else Color("#e8f4ff"))
		sprite.material = mat

func _aura(c: Array, z: int) -> void:
	_sprite([1,"aura",c[1],float(c[2])+3.0,83*0.55,122*0.55,float(c[3])+PI*0.5,1,0,0,83,122],z)
	var sprite := _sprites[_sprite_count-1]
	sprite.texture = preload("res://assets/effects/build/airship_aura_mask.png")
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/build_aura.gdshader")
	mat.set_shader_parameter("noise_tex",NOISE)
	mat.set_shader_parameter("strength",c[4])
	mat.set_shader_parameter("pop",c[7])
	mat.set_shader_parameter("clock",c[6])
	sprite.material = mat
