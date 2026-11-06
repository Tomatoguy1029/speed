## 手描きの節と法線を、戦闘用の点列へ重ねる。解析・切り出しは制作時に完了する。
extends Node2D

@export var body_only := false
@export var body_texture: Texture2D
@export var heads_only := false
@export var head_textures: Dictionary = {}
@export var segments: Array[Texture2D] = []
@export var tail_taper: Texture2D
@export var tail_tip: Texture2D
@export var immortal: Texture2D
## 合体中の首は当たらないので、本体より少し暗くする。
@export var merged_neck_tint := Color(0.55,0.55,0.55)
## 分離後は蛇ごとに色相をずらし、1匹ずつ見分けられるようにする（度／蛇1匹）。
@export var snake_hue_step := 10.8
@export var snake_saturation := 1.21
## 分離後の蛇は頭から尾へ暗くなる。尾の先の暗さの割合。
@export_range(0.0,1.0,0.05) var snake_tail_shade := 0.6
const LIGHTING = preload("res://data/visuals/enemy_lighting.tres")
var _tint := Color.WHITE
var _chain_total := 0.0
var frame := {}
var host: Node2D

func apply_frame(value: Dictionary) -> void:
	frame = value
	queue_redraw()

func _separated() -> bool:
	return bool(frame.get("separated",false))

func _origin() -> Vector2:
	return frame.get("position",Vector2.ZERO)


func _ready() -> void:
	host = get_parent()
	host.draw.connect(queue_redraw)
	material = material.duplicate()
	for field in ["ambient", "normal_strength", "key_energy", "fill_energy"]:
		material.set_shader_parameter(field, LIGHTING.get(field))
	for entry in [["key_direction", LIGHTING.key_angle], ["fill_direction", LIGHTING.fill_angle]]:
		var direction := Vector2.from_angle(deg_to_rad(float(entry[1])))
		material.set_shader_parameter(entry[0], Vector3(direction.x, direction.y, LIGHTING.height).normalized())

func _draw() -> void:
	if frame.is_empty(): return
	if body_only:
		if not _separated() and body_texture!=null:
			var radius: float = frame.radius
			draw_texture_rect(body_texture,Rect2(Vector2.ONE*-radius,Vector2.ONE*radius*2.0),false)
		return
	var factor: float = float(frame.radius)*2.0/host.body_texture.get_width() if host.body_texture!=null else 1.0
	for index in frame.necks.size():
		var neck: Dictionary = frame.necks[index]
		_tint = _snake_tint(index,snake_saturation) if _separated() else merged_neck_tint
		if heads_only:
			var texture: Texture2D = head_textures.get(StringName(neck.kind))
			if neck.alive and texture!=null:
				draw_set_transform(neck.position-frame.position,float(neck.facing)-PI*0.5,Vector2(float(neck.get("sx",1.0)),float(neck.get("sy",1.0)))*factor)
				draw_texture(texture,-texture.get_size()*0.5,_snake_tint(index,1.0) if _separated() else Color.WHITE)
		elif neck.alive or float(neck.length)>0.0: _chain(neck.points,factor,index,false)
	if frame.has("bearer"):
		var bearer: Dictionary = frame.bearer
		_tint = _snake_tint(frame.necks.size(),snake_saturation) if _separated() else Color.WHITE
		if not heads_only: _chain(bearer.points,factor,frame.necks.size(),true)
		elif bearer.alive:
			var texture: Texture2D = head_textures.get(&"immortal")
			if texture!=null:
				draw_set_transform(bearer.position-frame.position,float(bearer.facing)-PI*0.5,Vector2.ONE*factor)
				draw_texture(texture,-texture.get_size()*0.5,_snake_tint(frame.necks.size(),1.0) if _separated() else Color.WHITE)
	draw_set_transform(Vector2.ZERO)

## 絵は青灰色の濃淡なので、代表色の色相を回した比を掛ければ、絵全体の色相を回したのと近い色になる。
func _snake_tint(index: int, saturation: float) -> Color:
	var base := Color("#4b5a68")
	var turn := deg_to_rad((index-3)*snake_hue_step)
	var c := cos(turn)
	var n := sin(turn)
	var r := base.r*(0.213+0.787*c-0.213*n)+base.g*(0.715-0.715*c-0.715*n)+base.b*(0.072-0.072*c+0.928*n)
	var g := base.r*(0.213-0.213*c+0.143*n)+base.g*(0.715+0.285*c+0.14*n)+base.b*(0.072-0.072*c-0.283*n)
	var b := base.r*(0.213-0.213*c-0.787*n)+base.g*(0.715-0.715*c+0.715*n)+base.b*(0.072+0.928*c+0.072*n)
	var grey := 0.213*r+0.715*g+0.072*b
	return Color(maxf(0.0,lerpf(grey,r,saturation))/base.r,maxf(0.0,lerpf(grey,g,saturation))/base.g,maxf(0.0,lerpf(grey,b,saturation))/base.b)

func _chain(points: PackedVector2Array, factor: float, variant: int, special: bool) -> void:
	if points.size() < 2: return
	var total := 0.0
	for i in range(1, points.size()): total += points[i - 1].distance_to(points[i])
	if total < 0.001: return
	_chain_total = total
	var tail_length := 0.0
	if _separated():
		# 尾端は先端→幅の広がる節→通常節。短い点列には収まる倍率で描く。
		var tail_factor := minf(factor, total / 64.0)
		_stamp(tail_tip, points, 10.0 * tail_factor, tail_factor)
		_stamp(tail_taper, points, 30.0 * tail_factor, tail_factor)
		tail_length = 38.0 * tail_factor
	var end := total
	if special and immortal != null:
		end = maxf(tail_length, total - (immortal.get_height() - 18.0) * factor)
	var spacing: float = maxf(1.0, host.neck_spacing_pixels * factor)
	var distance := tail_length
	var tile := 0
	while distance <= end:
		_stamp(segments[(variant + tile) % segments.size()], points, distance, factor)
		distance += spacing
		tile += 1
	if special and immortal != null:
		_stamp(immortal, points, maxf(0.0, total - (immortal.get_height() * 0.5 - 8.0) * factor), factor)
	draw_set_transform(Vector2.ZERO)

func _stamp(texture: Texture2D, points: PackedVector2Array, distance: float, factor: float) -> void:
	if texture == null: return
	var start := distance
	for i in range(1, points.size()):
		var delta := points[i] - points[i - 1]
		var length := delta.length()
		if length < 0.001: continue
		if distance <= length or i == points.size() - 1:
			var at := points[i - 1] + delta * clampf(distance / length, 0.0, 1.0)
			draw_set_transform(at - _origin(), delta.angle() - PI * 0.5, Vector2.ONE * factor)
			var shade := 1.0-snake_tail_shade*(1.0-start/maxf(1.0,_chain_total)) if _separated() else 1.0
			draw_texture(texture, -texture.get_size() * 0.5, Color(_tint.r*shade,_tint.g*shade,_tint.b*shade))
			return
		distance -= length
