## 首が放つ攻撃の見た目。点列と時間は技から受け取り、判定を書き換えない。
extends AttackVisual
@export var energy_shader: Shader = preload("res://shaders/hydra_energy.gdshader")
@export var area_shader: Shader = preload("res://shaders/hydra_area.gdshader")
@export var tornado_scene: PackedScene = preload("res://scenes/bosses/hydra_tornado.tscn")
var line: Node2D
func configure(_actor: Node, kind: StringName, points: PackedVector2Array, white: Texture2D) -> void:
	var area := kind == &"lightning" and points[0].distance_to(points[-1]) < 1.0
	if kind in [&"tornado", &"tornado_charge"]:
		line = tornado_scene.instantiate()
	elif area:
		line = Sprite2D.new()
		line.texture = white
	else:
		line = Line2D.new()
		line.texture = white
		line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind not in [&"tornado", &"tornado_charge"]:
		line.material = ShaderMaterial.new()
		line.material.shader = area_shader if area else energy_shader
	add_child(line)
func update_effect(effect: Dictionary, clock: float) -> void:
	if line.has_method("update_effect"):
		line.update_effect(effect, clock)
		return
	if line is Line2D:
		line.points = effect.points
		line.width = effect.width
	else:
		line.position = effect.points[0]
		line.scale = Vector2.ONE * float(effect.width) * 0.5
	var color: Color = {&"tornado":Color(0.3,0.85,0.72), &"rubble":Color(0.55,0.44,0.3), &"wind":Color(0.25,0.9,0.75), &"wind_blade":Color(0.3,1,0.8), &"lightning":Color(0.4,0.75,1), &"bite":Color(1,0.45,0.18)}.get(effect.kind, Color(1,0.25,0.4))
	line.material.set_shader_parameter("style", {&"wind":1,&"wind_blade":1,&"lightning":2,&"rubble":3,&"tornado":4,&"bolt":5}.get(effect.kind,0))
	line.material.set_shader_parameter("tint", color)
	line.material.set_shader_parameter("clock", clock)
	line.material.set_shader_parameter("warning", effect.age < effect.delay)
	var length := 0.0
	for i in range(1, effect.points.size()): length += effect.points[i - 1].distance_to(effect.points[i])
	line.material.set_shader_parameter("span", maxf(1.0, length))
	line.material.set_shader_parameter("thickness", effect.width)
