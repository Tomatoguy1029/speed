## 戦闘の点列と寸法を読むだけの表示。部位やHPへ書き戻さない。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
var state := {}
var hit := 0.0
var _parts: Node2D
func _ready() -> void:
	z_index = 1
	_parts = preload("res://scripts/bosses/draco_parts.gd").new()
	add_child(_parts)
	EFFECT_SETTINGS.apply_key(self,"boss/body/draco")
func apply_frame(body: Dictionary, _attack: Dictionary = {}, _appearance: Dictionary = {}) -> void:
	state = body
	position = body.position
	rotation = body.facing
	visible = body.mode<4
	hit = float(body.flash)
	var points := PackedVector2Array()
	for point: Vector2 in body.body_points: points.append(to_local(point))
	_parts.pose(points,float(body.body_width)*float(body.perspective_scale),float(body.head_scale)*float(body.perspective_scale),float(body.alpha),false,hit)
	queue_redraw()
func _draw() -> void:
	if state.is_empty() or not visible: return
	var depth := float(state.perspective_scale)
	var core := Vector2(-110.0*float(state.head_scale)*depth,0)
	var pulse := 0.85+sin(float(state.clock)*3.0)*0.15
	draw_circle(core,43.0*depth,Color(0.38,0.59,1.0,0.16*pulse*float(state.alpha)))
	preload("res://scripts/bosses/draco_form.gd").star(self,core,27.0*depth,Color(0.85,0.96,1.0,float(state.alpha)))
