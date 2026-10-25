## 本体と同じ仮の全身へ、通常ピカロと共通のshaderを重ねる。
extends Node2D
var actor: BossActor
var unit: Dictionary
func _ready() -> void:
	top_level=true
	material=ShaderMaterial.new()
	material.shader=preload("res://shaders/picaro.gdshader")
func _process(_dt: float) -> void:
	if actor==null or not actor.ctx.enemies.is_same(unit.row,unit.id) or actor.table.dead[unit.row]!=0:
		hide();return
	global_position=actor.table.pos[unit.row]
	global_rotation=unit.angle
	queue_redraw()
func _draw() -> void:
	var points:=PackedVector2Array([Vector2.ZERO])
	for j in 12: points.append(Vector2(-(j+1)*45.0,sin((j+1)*0.7-actor.clock)*55.0))
	draw_polyline(points,Color("#544475"),78.0,false)
	draw_colored_polygon(PackedVector2Array([Vector2(-30,-48),Vector2(80,-35),Vector2(105,0),Vector2(80,35),Vector2(-30,48)]),Color("#70618c"))
	for side in [-1,1]:draw_circle(Vector2(58,side*24),7.0,Color("#ff3155"))
