## おおいぬ座の直線の光。判定の線分と同じ帯へ、世界時間で炎を流す。
extends AttackVisual
var canvas: BeamCanvas
func _ready() -> void:
	canvas = BeamCanvas.new()
	add_child(canvas)
func begin_batch() -> void:
	canvas.beams.clear()
func draw_hazard(_c: CanvasItem, pr: ProjectileSystem, i: int, _view: Rect2) -> void:
	if pr.hazard_t[i] < pr.hazard_delay[i]: return
	var left := pr.hazard_delay[i] + pr.hazard_active[i] - pr.hazard_t[i]
	canvas.beams.append({"from": pr.hazard_pos[i], "angle": pr.hazard_angle[i], "length": pr.hazard_len[i], "width": pr.hazard_width[i], "alpha": smoothstep(0.0, minf(0.08, pr.hazard_active[i]), left)})
func end_batch() -> void:
	canvas.clock = state.world_time
	canvas.queue_redraw()

class BeamCanvas extends Node2D:
	var beams: Array = []
	var clock := 0.0
	func _ready() -> void:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = preload("res://shaders/canis_flame_beam.gdshader")
		material = shader_material
	func _draw() -> void:
		material.set_shader_parameter("world_time", clock)
		for beam in beams:
			var start: Vector2 = beam.from
			var u := Vector2.from_angle(float(beam.angle))
			var side := u.orthogonal() * float(beam.width) * 0.5
			var end := start + u * float(beam.length)
			draw_primitive(PackedVector2Array([start-side, end-side, end+side, start+side]), PackedColorArray([Color(1,1,1,float(beam.alpha))]), PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]))
