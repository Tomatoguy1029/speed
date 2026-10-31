## 停止→キラン→直進。停止時に固定した進路を、画面外からの進入も含めて示す。
extends EnemyVisual

const WARNING_SHADER := preload("res://shaders/marlin_warning.gdshader")
const THRUST_SHADER := preload("res://shaders/marlin_thrust.gdshader")
const WARNING_HALF_HEIGHT := 7.0
const REFERENCE_HEIGHT := 225.0
## 原画64pxの吻先（最前列の2pixelの中心）。本体と同じ倍率・回転で追従する。
const HORN_OFFSET := Vector2(0.0, -29.5)
var _warning_mesh: QuadMesh
var _warnings: Array[MeshInstance2D] = []
var _warning_count := 0
var _thrust_mesh: ArrayMesh
var _thrusts: Array[MeshInstance2D] = []
var _thrust_count := 0

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super.setup(render, behavior_name)
	_warning_mesh = QuadMesh.new()
	_warning_mesh.size = Vector2.ONE
	# 筋ごとの四角形を一度だけ用意し、伸縮・明滅は頂点シェーダーへ任せる。
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for ray in 72:
		var first := vertices.size()
		vertices.append_array(PackedVector2Array([Vector2(0, -42), Vector2(112, -42), Vector2(112, 42), Vector2(0, 42)]))
		for corner in 4: uv.append(Vector2(ray, corner))
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	_thrust_mesh = ArrayMesh.new()
	_thrust_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

## 本体の可視判定とは独立して描く。装甲付きの外観でも予告を省略しない。
func draw_marks(_c: CanvasItem, _t: EnemyTable, _i: int) -> void:
	pass

func draw_layer(c: CanvasItem, _view: Rect2) -> void:
	_warning_count = 0
	_thrust_count = 0
	if state.cinematic_hide_enemies:
		_hide_unused_warnings()
		_hide_unused_thrusts()
		return
	var t := run.enemies.table
	var view := rm.view_rect().grow(-_px(48.0))
	for i in behavior.rows():
		if t.dead[i] != 0 or t.held[i] != 0 or t.stone[i] > 0.0:
			continue
		if t.mode[i] == EnemyTable.Mode.DASH:
			if _view.grow(sprite_radius(t, i) * 4.0).has_point(t.pos[i]): _draw_thrust(t, i)
			continue
		if t.mode[i] != EnemyTable.Mode.WINDUP: continue
		var dir := Vector2.from_angle(t.facing[i])
		var from := t.pos[i] + dir * t.r[i]
		var p: Dictionary = t.def[i].params
		var to := t.pos[i] + dir * float(p.dash_speed) * float(p.dash_time)
		var terrain_hit = run.field.first_body_hit(t.pos[i], to, t.r[i])
		if terrain_hit != null:
			to = t.pos[i].lerp(to, float(terrain_hit.t))
		var path := clip_warning(from, to, view)
		if path.is_empty(): continue
		_draw_warning(c, path[0], path[1], from, to, t.charge[i], t.id[i])
	_hide_unused_warnings()
	_hide_unused_thrusts()

func _hide_unused_thrusts() -> void:
	for n in range(_thrust_count, _thrusts.size()): _thrusts[n].visible = false

func _draw_thrust(t: EnemyTable, i: int) -> void:
	if _thrust_count == _thrusts.size():
		var node := MeshInstance2D.new()
		node.name = "MarlinThrust%d" % _thrust_count
		node.mesh = _thrust_mesh
		var thrust_material := ShaderMaterial.new()
		thrust_material.shader = THRUST_SHADER
		node.material = thrust_material
		# 装甲の専用CanvasLayerより前面。後方へ開く方向とは独立した描画順。
		rm._lit_enemy_marks.add_child(node)
		_thrusts.append(node)
	var thrust := _thrusts[_thrust_count]
	_thrust_count += 1
	var scale_px := sprite_radius(t, i) / 32.0
	var angle := rm._enemy_sprite_angle(t.type[i], t.facing[i])
	thrust.position = t.pos[i] + (HORN_OFFSET * scale_px).rotated(angle)
	thrust.rotation = angle + PI * 0.5
	thrust.scale = Vector2.ONE * scale_px
	thrust.visible = true
	var mat := thrust.material as ShaderMaterial
	var elapsed := maxf(0.0, float(t.def[i].params.dash_time) - t.timer[i])
	mat.set_shader_parameter("clock", elapsed)
	mat.set_shader_parameter("strength", minf(1.0, minf(elapsed, maxf(0.0, t.timer[i])) / 0.08))

func _hide_unused_warnings() -> void:
	for n in range(_warning_count, _warnings.size()): _warnings[n].visible = false

## 予告を実際の表示範囲へ切り詰め、最初に画面へ入る位置を返す。
static func clip_warning(from: Vector2, to: Vector2, view: Rect2) -> PackedVector2Array:
	var dir := to - from
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		if absf(dir[axis]) < 0.0001:
			if from[axis] < view.position[axis] or from[axis] > view.end[axis]:
				return PackedVector2Array()
			continue
		var a := (view.position[axis] - from[axis]) / dir[axis]
		var b := (view.end[axis] - from[axis]) / dir[axis]
		enter = maxf(enter, minf(a, b))
		leave = minf(leave, maxf(a, b))
		if enter >= leave: return PackedVector2Array()
	return PackedVector2Array([from.lerp(to, enter), from.lerp(to, leave)])

## 予兆の同時表示数だけ表示ノードを確保し、メッシュ・マテリアルを次の予兆でも再利用する。
func _draw_warning(c: CanvasItem, from: Vector2, to: Vector2, origin: Vector2, end: Vector2, charge: float, id: int) -> void:
	var distance := from.distance_to(to)
	if distance <= 0.001: return
	if _warning_count == _warnings.size():
		var node := MeshInstance2D.new()
		node.name = "MarlinWarning%d" % _warning_count
		node.mesh = _warning_mesh
		node.show_behind_parent = true
		var warning_material := ShaderMaterial.new()
		warning_material.shader = WARNING_SHADER
		node.material = warning_material
		c.add_child(node)
		_warnings.append(node)
	var warning := _warnings[_warning_count]
	_warning_count += 1
	var pixel := _px(maxf(1.0, rm.get_viewport().get_visible_rect().size.y / REFERENCE_HEIGHT))
	warning.position = (from + to) * 0.5
	warning.rotation = (to - from).angle()
	warning.scale = Vector2(distance, WARNING_HALF_HEIGHT * 2.0 * pixel)
	warning.visible = true
	var material := warning.material as ShaderMaterial
	material.set_shader_parameter("beam_length", distance / pixel)
	material.set_shader_parameter("path_length", origin.distance_to(end) / pixel)
	material.set_shader_parameter("path_offset", origin.distance_to(from) / pixel)
	material.set_shader_parameter("charge", charge)
	material.set_shader_parameter("seed", float(id % 4093))
	material.set_shader_parameter("clock", fmod(state.world_time, 4.0))
	material.set_shader_parameter("linear_output", c.get_viewport().use_hdr_2d)
