## C++が確定した本体・首点列・囲いを、同じ正式素材へ渡す。
extends Node2D
@export var body_texture: Texture2D
@export var neck_spacing_pixels := 14.0
var state := {}
var hit := 0.0
var arena: Node2D
var effects := {}
var shot_scenes := {}
func setup_effects(scope: ContentResourceScope, entries: Dictionary) -> void:
	for entry in entries.values():
		if entry.has("hydra_move"): shot_scenes[entry.hydra_move] = scope.resources.get(entry.path)
var white: Texture2D
func apply_frame(body: Dictionary, _attack: Dictionary = {}, _appearance: Dictionary = {}) -> void:
	state = body
	queue_redraw()
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
	var live := {}
	for effect: Dictionary in body.get("effects",[]):
		live[effect.id] = true
		if not effects.has(effect.id):
			if white==null:
				var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
				image.fill(Color.WHITE)
				white = ImageTexture.create_from_image(image)
			var scene: PackedScene = shot_scenes.get(String(effect.get("technique","")),preload("res://scenes/attacks/hydra_shape.tscn"))
			var line := scene.instantiate()
			line.visual_profile_key = "boss/move/hydra/"+String(effect.get("technique","bite_thrust"))
			line.visual_component = "shape"
			add_child(line)
			line.top_level = true
			line.global_position = Vector2.ZERO
			line.configure(self,StringName(effect.kind),effect.points,white)
			effects[effect.id] = line
		effects[effect.id].update_effect(effect,float(body.clock))
		if effect.get("final",false): effects[effect.id].modulate.a=float(body.get("final_alpha",1.0))
	for id in effects.keys():
		if not live.has(id): effects[id].queue_free();effects.erase(id)

func _draw() -> void:
	for target: Dictionary in state.get("north_targets",[]):
		var color := Color("#fff2b0") if target.locked else Color("#ffd16c")
		draw_line(target.from-position,target.target-position,Color(color,0.55),3.0,true)
		draw_arc(target.target-position,target.radius,0.0,TAU,40,color,3.0,true)
		draw_circle(target.target-position,6.0,color)
