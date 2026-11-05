## 英雄の力の表示。C++から受けた値と出来事だけを描く。
## ペルセウス座は、機体の手前に開くメドゥーサの目（hero_medusa）、開ききった瞬間の画面のブラーと闇のオーラ（hero_medusa_screen）、
## 石の敵が砕ける破片（StoneShards）を出す。石になった敵の色は、敵のベースと装甲の shader が描く（hero_stone.gdshaderinc）。
extends Node2D

const MEDUSA := preload("res://shaders/hero_medusa.gdshader")
const MEDUSA_SCREEN := preload("res://shaders/hero_medusa_screen.gdshader")
const NOISE := preload("res://assets/effects/build/burst_noise.tres")
const SHARDS := preload("res://scripts/render/fx/stone_shards.gd")
const PERSEUS: HeroDef = preload("res://data/heroes/perseus.tres")
## 目の横幅の半分のドット数。まぶたの縁や虹彩の筋をドット単位で描くので、ドット数で形を決める
const EYE_CELLS := 42.0
var petrified := PackedFloat32Array()
var unit := 1.0
var fire := {}
var world_time := 0.0
var px := 1.82
var _eye: MeshInstance2D
var _eye_material: ShaderMaterial
var _screen: ColorRect
var _screen_material: ShaderMaterial
var _shards: StoneShards
var _last_stone := PackedFloat32Array()

## sky は敵より上の親。cell は1ドットの世界での幅。
func setup(cell: float, sky: Node2D) -> void:
	px = cell
	_eye = MeshInstance2D.new()
	_eye.mesh = FireBursts._mesh()
	_eye.scale = Vector2.ONE * EYE_CELLS * 1.5 * px
	_eye.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_eye_material = ShaderMaterial.new()
	_eye_material.shader = MEDUSA
	_eye_material.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	_eye_material.set_shader_parameter("half_cells", EYE_CELLS * 1.5)
	_eye_material.set_shader_parameter("eye_size", EYE_CELLS)
	_eye_material.set_shader_parameter("life", PERSEUS.duration)
	_eye_material.set_shader_parameter("open_to", float(PERSEUS.params.open_delay))
	_eye.material = _eye_material
	_eye.hide()
	_shards = SHARDS.new()
	_shards.setup(px)
	sky.add_child(_shards)
	var layer := CanvasLayer.new()
	layer.layer = sky.get_parent().layer + 1 if sky.get_parent() is CanvasLayer else 64
	add_child(layer)
	# 前の層で取り込まれた画面には目が写っていないので、目まで描いたあとの画面をここで取り込み直す
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(copy)
	_screen = ColorRect.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_material = ShaderMaterial.new()
	_screen_material.shader = MEDUSA_SCREEN
	_screen_material.set_shader_parameter("value_noise", NOISE.get_meta("texture"))
	_screen.material = _screen_material
	_screen.hide()
	layer.add_child(_screen)
	# 目は画面のオーラと機体より上の層に置き、ブラーにも機体にも隠れないようにする
	var eye_layer := CanvasLayer.new()
	eye_layer.layer = layer.layer + 1
	eye_layer.follow_viewport_enabled = true
	add_child(eye_layer)
	eye_layer.add_child(_eye)

## 石だった敵の kill なら破片を出して true を返す（通常の撃破の火花は出さない）。
func frame_event(event: Dictionary) -> bool:
	if event.type == &"hero_power" and StringName(event.get("id", &"")) == &"perseus":
		_eye_material.set_shader_parameter("seed", randf() * 9.0)
	elif event.type == &"kill":
		for i in range(0, _last_stone.size(), 3):
			if Vector2(_last_stone[i], _last_stone[i + 1]).distance_to(event.pos) <= _last_stone[i + 2] + 4.0:
				_shards.burst(event.pos, _last_stone[i + 2])
				return true
	return false

## dt は演出の秒、ship は機体の表示位置、hero は C++ の英雄の値。目の進みは効いている時間の残りから求める。
func frame_tick(dt: float, ship: Vector2, hero: Dictionary) -> void:
	_last_stone = petrified
	var hdr := get_viewport().use_hdr_2d
	for mat: ShaderMaterial in [_eye_material, _screen_material, _shards.material]:
		mat.set_shader_parameter("linear_output", hdr)
	_shards.step(dt)
	var active := float(hero.get("active", 0.0))
	if StringName(hero.get("power", &"")) != &"perseus" or active <= 0.0:
		_eye.hide()
		_screen.hide()
		return
	var age := PERSEUS.duration - active
	_eye.show()
	_eye.position = (ship / px).round() * px
	_eye_material.set_shader_parameter("age", age)
	var since := age - float(PERSEUS.params.open_delay)
	_screen.visible = since >= 0.0 and since < 1.6
	if _screen.visible:
		var size := get_viewport().get_visible_rect().size
		var canvas := get_viewport().get_canvas_transform()
		_screen_material.set_shader_parameter("since", since)
		_screen_material.set_shader_parameter("rect_size", size)
		_screen_material.set_shader_parameter("cell_px", px * canvas.get_scale().x)
		_screen_material.set_shader_parameter("center", (canvas * ship) / size)

func draw_fire(canvas: CanvasItem) -> void:
	var falls: PackedFloat64Array = fire.get("falls",PackedFloat64Array())
	var burns: PackedFloat64Array = fire.get("burns",PackedFloat64Array())
	for i in range(0,falls.size(),3):
		var k := clampf(1.0-falls[i+2]/0.6,0.0,1.0)
		var at := Vector2(falls[i],falls[i+1])
		canvas.draw_circle(at,30.0+60.0*k,Color(1.0,0.4,0.1,0.12+0.25*k))
		canvas.draw_circle(at-Vector2(-0.6,1.0)*500.0*(1.0-k),22.0,Color("#ffb060"))
	for i in range(0,burns.size(),3):
		var flick := 0.8+0.2*sin(world_time*18.0+burns[i])
		canvas.draw_circle(Vector2(burns[i],burns[i+1]),80.0*flick,Color(1.0,0.45,0.1,0.22*minf(1.0,burns[i+2])))
