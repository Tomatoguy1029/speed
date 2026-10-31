## 停止→キラン→直進。停止時に固定した進路を、画面外からの進入も含めて示す。
extends EnemyVisual

const WARNING_SHADER := preload("res://shaders/marlin_warning.gdshader")
const WARNING_HALF_HEIGHT := 7.0
const REFERENCE_HEIGHT := 225.0
var _warning_mesh: QuadMesh
var _warnings: Array[MeshInstance2D] = []
var _warning_count := 0

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super.setup(render, behavior_name)
	_warning_mesh = QuadMesh.new()
	_warning_mesh.size = Vector2.ONE

## 本体の可視判定とは独立して描く。装甲付きの外観でも予告を省略しない。
func draw_marks(_c: CanvasItem, _t: EnemyTable, _i: int) -> void:
	pass

func draw_layer(c: CanvasItem, _view: Rect2) -> void:
	_warning_count = 0
	if state.cinematic_hide_enemies:
		_hide_unused_warnings()
		return
	var t := run.enemies.table
	var view := rm.view_rect().grow(-_px(48.0))
	for i in behavior.rows():
		if t.dead[i] != 0 or t.mode[i] != EnemyTable.Mode.WINDUP or t.held[i] != 0 or t.stone[i] > 0.0:
			continue
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
