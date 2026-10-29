## 手描きの節と法線を、戦闘用の点列へ重ねる。解析・切り出しは制作時に完了する。
extends Node2D

@export var heads_only := false
@export var head_textures: Dictionary = {}
@export var segments: Array[Texture2D] = []
@export var tail_taper: Texture2D
@export var tail_tip: Texture2D
@export var immortal: Texture2D
const LIGHTING = preload("res://data/visuals/enemy_lighting.tres")
var host: Node2D

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
	if host == null or host.ctx == null or not host.has_body(): return
	if heads_only:
		_draw_heads()
		return
	if segments.is_empty(): return
	var radius: float = host.table.r[host.body]
	var scale_factor: float = radius * 2.0 / host.body_texture.get_width() if host.body_texture != null else radius / 64.0
	for index in host.necks.size():
		var neck = host.necks[index]
		if neck.row >= 0 or neck.length > 0.0:
			_chain(neck.segs, scale_factor, index, false)
	if host.separated and host.immortal_neck != null:
		_chain(host.immortal_neck.segs, scale_factor, host.necks.size(), true)

func _chain(points: PackedVector2Array, factor: float, variant: int, special: bool) -> void:
	if points.size() < 2: return
	var total := 0.0
	for i in range(1, points.size()): total += points[i - 1].distance_to(points[i])
	if total < 0.001: return
	var tail_length := 0.0
	if host.separated:
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
	for i in range(1, points.size()):
		var delta := points[i] - points[i - 1]
		var length := delta.length()
		if length < 0.001: continue
		if distance <= length or i == points.size() - 1:
			var at := points[i - 1] + delta * clampf(distance / length, 0.0, 1.0)
			draw_set_transform(at - host.table.pos[host.body], delta.angle() - PI * 0.5, Vector2.ONE * factor)
			draw_texture(texture, -texture.get_size() * 0.5)
			return
		distance -= length

func _draw_heads() -> void:
	var factor: float = host.table.r[host.body] * 2.0 / host.body_texture.get_width() if host.body_texture != null else 1.0
	for neck in host.necks:
		if host._alive(neck): _head(neck.row, neck.kind, factor)
	if host.separated and host.immortal_neck != null and host._alive(host.immortal_neck):
		_head(host.immortal_row, &"immortal", factor)
	draw_set_transform(Vector2.ZERO)

func _head(row: int, kind: StringName, factor: float) -> void:
	var texture := head_textures.get(kind) as Texture2D
	if texture == null: return
	var at: Vector2 = host.table.pos[row] - host.table.pos[host.body]
	draw_set_transform(at, host.table.facing[row] - PI * 0.5, Vector2.ONE * factor)
	draw_texture(texture, -texture.get_size() * 0.5)
