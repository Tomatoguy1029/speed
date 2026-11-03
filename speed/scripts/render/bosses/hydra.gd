## C++が確定した本体・首点列・囲いを、同じ正式素材へ渡す。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
const BURST_KEY := "boss/body/hydra"
const BURST_SHADER := preload("res://shaders/hydra_burst.gdshader")
@export var body_texture: Texture2D
@export var neck_spacing_pixels := 14.0
var frame_scope: ContentResourceScope
var state := {}
var hit := 0.0
var arena: Node2D
var effects := {}
var shot_scenes := {}
var _burst_clock := -1.0
var _burst_serial := 0
var _bursts: Array[Dictionary] = []
func setup_effects(scope: ContentResourceScope, entries: Dictionary) -> void:
	frame_scope = scope
	for entry in entries.values():
		if entry.has("hydra_move"): shot_scenes[entry.hydra_move] = scope.resources.get(entry.path)
var white: Texture2D
func apply_frame(body: Dictionary, _attack: Dictionary = {}, _appearance: Dictionary = {}) -> void:
	var clock := float(body.clock)
	_advance_bursts(maxf(0.0,clock-_burst_clock) if _burst_clock>=0.0 else 0.0)
	_burst_clock = clock
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

func frame_event(event: Dictionary) -> void:
	var cue := String(event.get("cue",""))
	if cue in ["phase_changed","exposed","defeated"]:
		for burst in _bursts: burst.sprite.queue_free()
		_bursts.clear()
		return
	if cue not in ["growth_started","separation_started","head_destroyed","hit"]: return
	if white==null:
		var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		white = ImageTexture.create_from_image(image)
	var values: Dictionary = EFFECT_SETTINGS.resolved_values(BURST_KEY,scene_file_path)
	var large := cue in ["growth_started","separation_started"]
	var diameter := 520.0 if large else 220.0 if cue=="head_destroyed" else 140.0
	var color: Color = {"vortex":Color("#70ffe0"),"thunder":Color("#77bbff"),"debris":Color("#dbac68"),"immortal":Color("#ffe69a")}.get(String(event.get("kind","body")),values.get("attack_color",Color("#ff765c")))
	if cue=="hit": color = values.get("hit_color",Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.texture = white
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE*diameter/2.0
	var burst_material := ShaderMaterial.new()
	burst_material.shader = BURST_SHADER
	burst_material.set_shader_parameter("tint",color)
	_burst_serial += 1
	burst_material.set_shader_parameter("seed",float(_burst_serial%19))
	sprite.material = burst_material
	add_child(sprite)
	sprite.top_level = true
	sprite.global_position = event.position
	_bursts.append({"sprite":sprite,"age":0.0,"large":large,"diameter":diameter})
	if _bursts.size()>96:
		var oldest: Dictionary = _bursts.pop_front()
		oldest.sprite.queue_free()
	_advance_bursts(0.0)

func _advance_bursts(dt: float) -> void:
	var values: Dictionary = EFFECT_SETTINGS.resolved_values(BURST_KEY,scene_file_path)
	for burst in _bursts.duplicate():
		burst.age += dt
		var duration := maxf(0.01,float(values.get("burst_large_seconds" if burst.large else "burst_small_seconds",0.8 if burst.large else maxf(float(values.get("flash_duration",0.25)),0.3))))
		var age: float = burst.age/ShaderTuning.burst_time_scale(BURST_KEY,scene_file_path)
		var burst_material: ShaderMaterial = burst.sprite.material
		ShaderTuning.apply(burst_material,BURST_KEY,scene_file_path)
		burst_material.set_shader_parameter("pixels",float(burst.diameter)/4.0*float(values.get("burst_pixel_scale",1.0)))
		burst_material.set_shader_parameter("progress",clampf(age/duration,0.0,1.0))
		burst.sprite.visible = age<duration
		if age>=duration and not ShaderTuning.previewing():
			burst.sprite.queue_free()
			_bursts.erase(burst)

func _draw() -> void:
	for target: Dictionary in state.get("north_targets",[]):
		var color := Color("#fff2b0") if target.locked else Color("#ffd16c")
		draw_line(target.from-position,target.target-position,Color(color,0.55),3.0,true)
		draw_arc(target.target-position,target.radius,0.0,TAU,40,color,3.0,true)
		draw_circle(target.target-position,6.0,color)
