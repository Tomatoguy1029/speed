## 時間切れの仮の演出（仕様書 4.1）。制限時間に達すると、画面の端から機体へ暗闇が閉じる。
## 閉じきる時間は敗北の停止の時間（config.death_freeze_time）と同じで、その後の GAME OVER は HUD が出す。
extends ColorRect

@export var run_path: NodePath

var run: RunManager
var _t := -1.0
var _start_radius := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/time_up_iris.gdshader")
	material = mat
	visible = false
	run = get_node(run_path) as RunManager
	run.frame_events.connect(_on_events)

func _on_events(events: Array[Dictionary]) -> void:
	for ev in events:
		if ev.type == &"time_up":
			_t = 0.0
			_start_radius = 0.0
			visible = true

func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var center := get_viewport().get_canvas_transform() * run.state.ship_pos
	if _start_radius <= 0.0:
		for corner in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
			_start_radius = maxf(_start_radius, center.distance_to(corner))
	# 初めはゆっくり、終わりに向けて速く閉じる。
	var k := clampf(_t / maxf(0.01, run.cfg.death_freeze_time), 0.0, 1.0)
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("radius", _start_radius * (1.0 - k * k))
