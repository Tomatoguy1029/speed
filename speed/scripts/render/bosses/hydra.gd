## C++が確定した本体・首点列・囲いを、同じ正式素材へ渡す。
extends Node2D
@export var body_texture: Texture2D
@export var neck_spacing_pixels := 14.0
var state := {}
var hit := 0.0
var arena: Node2D
func apply_frame(body: Dictionary, _attack: Dictionary = {}, _appearance: Dictionary = {}) -> void:
	state = body
	position = body.position
	rotation = 0.0
	visible = body.mode<4
	hit = float(body.flash)
	modulate = Color(1.5,1.5,1.5) if hit>0.0 else Color.WHITE
	for child in get_children():
		if child.has_method("apply_frame"): child.apply_frame(body)
	if arena==null and body.has("arena"):
		arena = preload("res://scripts/bosses/hydra_arena.gd").new()
		add_child(arena)
		arena.top_level = true
		arena.position = Vector2.ZERO
		arena.z_index = 3
		arena.bounds = body.arena
		arena.thickness = float(body.arena_wall_thickness)
		arena._build_rubble()
		arena._build_mesh()
		arena.queue_redraw()
	if arena!=null: arena.visible = visible and body.has("arena")
