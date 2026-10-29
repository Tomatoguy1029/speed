## Whole-body copies use the same authored silhouette and the same posed points as their damage rows.
extends Node2D
const FORM = preload("res://scripts/bosses/draco_form.gd")
var actor: BossActor
var unit: Dictionary
func _ready() -> void:
	top_level = true
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/picaro.gdshader")
func _process(_dt: float) -> void:
	if actor==null or not actor.ctx.enemies.is_same(unit.row,unit.id) or actor.table.dead[unit.row]!=0:
		hide();material.set_shader_parameter("boss_hit_white",0.0);return
	visible = not actor.run_state.cinematic_hide_enemies
	var sample: Dictionary = actor.hit_feedback.sample(unit.id)
	global_position = actor.table.pos[unit.row] + sample.offset
	global_rotation = float(unit.angle) + float(sample.angle)
	material.set_shader_parameter("boss_hit_white",sample.white)
	queue_redraw()
func _draw() -> void:
	if actor==null: return
	var world: PackedVector2Array = unit.get("points",actor.neutral_body_points(actor.table.pos[unit.row],unit.angle))
	var points := PackedVector2Array()
	for point in world: points.append((point-actor.table.pos[unit.row]).rotated(-float(unit.angle)))
	FORM.draw_body(self,points,actor.body_width,actor.clock,true,1.0,PackedFloat32Array(),true)
	FORM.draw_head(self,actor.head_scale,0.6 if not unit.get("done",false) else 0.0)
