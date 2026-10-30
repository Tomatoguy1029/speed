## 試作の実演配置を固定データとして再生する。記録は試作の描画命令（1ドット＝画面の1画素）で、
## 塗り・円・輪・線・光・円弧・光弾・砲口・針は試作と同じ規則のドット描画（PixelPainter）、炎は fire_burst、
## 重力レンズと空間の歪みは本番と同じ shader、ギアアップの炎は本番と同じ GearFire で描く。
## 命令の番号：0 塗り、1 絵、2 円、3 輪（太さ・揺らぎ）、4 線、5 炎、6 針、7 快進撃のオーラ、8 砲口、9 光弾、
## 10 レンズ、11 歪み、12 ミラージュの分身、13 隙間のない輪、14 光、15 円弧、16 ギアアップの炎。
extends Node2D
const FLAT := preload("res://shaders/codex_flat.gdshader")
const FIRE := preload("res://shaders/fire_burst.gdshader")
const LENS := preload("res://shaders/hole_lens.gdshader")
const RIPPLE := preload("res://shaders/space_ripple.gdshader")
const GLOW := preload("res://shaders/codex_glow.gdshader")
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
var _surfaces := {"fire": [], "lens": [], "ripple": [], "glow": []}
var _used := {}
var _sprite_count := 0
var clock := 0.0
var _gear: GearFire
var _gear_clock := -1.0
var _gear_seen := false

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
	_used = {"fire": 0, "lens": 0, "ripple": 0, "glow": 0}
	_gear_seen = false
	var stroke := ""
	var stroke_cells := {}
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
		if opcode != 4: stroke = ""
		match opcode:
			0: painter.add_rect(at, Vector2(command[3], command[4]) * 0.5, command[5], _color(command, 6))
			1: _sprite(command, z)
			2: painter.disk(at, command[3], _color(command, 4))
			3: painter.thick_ring(at, command[3], int(command[4]), _color(command, 5), float(command[9]) if command.size() > 9 else 0.0)
			4:
				# 試作の1本の線（同じ色・太さで続く線分）は、重なるドットを1回だけ塗る。透ける線が濃くならない
				var key := str(command.slice(5))
				if key != stroke:
					stroke = key
					stroke_cells = {}
				_line(painter, at, Vector2(command[3], command[4]), maxi(1, roundi(command[5])), _color(command, 6), stroke_cells)
			5: _fire(command, z)
			6: painter.spindle(at, command[3], command[4], command[5], command[6])
			7: _aura(command, z)
			8: painter.muzzle(at, command[3], command[4], int(command[5]))
			9: painter.bolt(at, command[3], int(command[4]), int(command[5]))
			10: _lens(at, command[3], z)
			11: _ripple(at, command[3], command[4], z)
			13: painter.ring(at, command[3], _color(command, 4))
			14: _glow(at, command[3], Color(command[4], command[5], command[6], command[7]), z)
			15: _arc(painter, at, command[3], command[4], command[5], command[6], _color(command, 7))
			16: _gear_fire(at, command[3], command[4], command[5] > 0.5, z)
			12:
				_sprite([1,"echo",command[1],command[2]+2.0,31*0.55,70*0.55,float(command[3])+PI*0.5,command[6],0,0,31,70],z)
				_sprites[_sprite_count-1].modulate=Color(float(command[5])/8.0,0,0,command[6])
	for batch in _rectangles: batch.end()
	for i in _sprites.size(): _sprites[i].visible = i < _sprite_count
	for kind in _surfaces:
		for i in _surfaces[kind].size(): _surfaces[kind][i].visible = i < _used[kind]
	if is_instance_valid(_gear): _gear.visible = _gear_seen

## 試作の glow：中心から外へ薄れる光を加算で重ねる。
func _glow(at: Vector2, radius: float, color: Color, z: int) -> void:
	var rect := _surface("glow", z) as ColorRect
	rect.position = at - Vector2.ONE * radius
	rect.size = Vector2.ONE * radius * 2.0
	(rect.material as ShaderMaterial).set_shader_parameter("glow_color", color)

## 太さ width の線。cells に塗ったドットを記録し、同じ線の中で二度塗らない。
func _line(painter: PixelPainter, a: Vector2, b: Vector2, width: int, color: Color, cells: Dictionary) -> void:
	var n := maxi(1, ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for i in range(n + 1):
		var at := (a + (b - a) * float(i) / n - Vector2.ONE * (width >> 1)).round()
		for y in width:
			for x in width:
				var cell := at + Vector2(x, y)
				if cells.has(cell): continue
				cells[cell] = true
				painter.fill(cell.x, cell.y, color)

## 線幅 width の円弧（角度 from から to）。
func _arc(painter: PixelPainter, at: Vector2, radius: float, width: float, from: float, to: float, color: Color) -> void:
	var span := to - from
	if span >= TAU: span = TAU
	var steps := maxi(8, ceili(radius * absf(span) * 2.0))
	var seen := {}
	for i in steps + 1:
		var a := from + span * i / steps
		var k := -width * 0.5
		while k < width * 0.5:
			var p := (at + Vector2.from_angle(a) * (radius + k + 0.5)).floor()
			if not seen.has(p):
				seen[p] = true
				painter.fill(p.x, p.y, color)
			k += 0.5

## ギアアップの炎。記録の時刻に合わせて進め、巻き戻ったり飛んだりしたら作り直して今の強さで温める。
func _gear_fire(at: Vector2, angle: float, power: float, on: bool, z: int) -> void:
	_gear_seen = true
	if _gear == null:
		_gear = GearFire.new()
		add_child(_gear)
		_gear.setup(1.0)
	_gear.z_index = maxi(0, mini(z, 4095) - 1)
	_gear.position = at + Vector2.from_angle(angle) * 9.0
	_gear.set_power(power, on)
	var dt := clock - _gear_clock
	if _gear_clock < 0.0 or dt < 0.0 or dt > 0.2:
		_gear.fire.restart()
		_gear.fire.emitting = on
		if on: _gear.fire.warmup(0.3)
		dt = 0.0
	_gear_clock = clock
	_gear.step(dt, angle)

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
			mat.shader = LENS if kind == "lens" else RIPPLE if kind == "ripple" else GLOW
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
	ShaderTuning.apply(mat, key)

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
	ShaderTuning.apply(mat, key)

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
	ShaderTuning.apply(mat, key)

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
