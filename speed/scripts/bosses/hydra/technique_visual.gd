## 絵担当の差し替え用の最小実装。イベントを受け取り、判定と同じ世界時間で表示する。
extends Node2D
const TUNED_SHADERS := [preload("res://shaders/hydra_burst.gdshader")]
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")

@export var warning_color := Color("#ffd16c")
@export var locked_color := Color("#fff2b0")
@export var attack_color := Color("#ff765c")
@export var recovery_color := Color("#8bf5c0")
@export var hit_color := Color("#ffffff")
@export_range(0.1, 5.0) var body_radius_scale := 1.25
@export_range(4.0, 200.0) var head_radius := 42.0
@export_range(1.0, 12.0) var line_width := 3.0
@export_range(0.05, 2.0) var flash_duration := 0.25
## VisualTimeline の装飾トラックで編集する。予告の有無はイベントが決める。
@export var pulse_scale := 1.0
@export_range(0.5, 3.0, 0.05) var burst_pixel_scale := 1.0
@export var technique_id: StringName
var hydra: Node
var actor: Node:
	set(value): hydra = value
var retained: bool:
	get: return not slots.is_empty() or not flashes.is_empty()
var slots: Dictionary = {}
var flashes: Array[Dictionary] = []
var sprites: Dictionary={}
var serial:=0
@export var burst_shader: Shader=preload("res://shaders/hydra_burst.gdshader")
@onready var animations: AnimationPlayer = $AnimationPlayer
@onready var body_anchor: Marker2D = $BodyAnchor
@onready var head_anchor: Marker2D = $HeadAnchor

func _ready() -> void:
	EFFECT_SETTINGS.apply_to(self)

func bind_hydra(actor: Node) -> void:
	hydra = actor
	hydra.presentation_event.connect(on_hydra_event)
	hydra.presentation_advanced.connect(advance_effects)

func on_event(event: Dictionary) -> void:
	if event.cue in [&"growth_started", &"separation_started", &"head_destroyed", &"hit", &"phase_changed", &"exposed", &"defeated"]: return
	if event.technique != technique_id: return
	on_hydra_event(event)

func on_hydra_event(event: Dictionary) -> void:
	var cue: StringName = event.cue
	var index: int = event.neck_index
	if cue in [&"growth_started",&"separation_started",&"head_destroyed",&"gather_started",&"rubble_shattered",&"target_locked"]:_flash(event)
	match cue:
		&"phase_changed", &"exposed", &"defeated":
			clear_effects()
		&"warning_started", &"attack_started", &"recovery_started":
			slots[index] = event.duplicate()
			if float(event.get("damage_delay", 0.0)) > 0.0:
				slots[index].cue = &"warning_started"
				slots[index].delay = event.damage_delay
			if cue == &"attack_started" and float(event.get("damage_delay", 0.0)) <= 0.0:
				_flash(event)
			var clip := &"windup" if cue == &"warning_started" else (&"active" if cue == &"attack_started" else &"recover")
			if animations.has_animation(clip):
				animations.play(clip)
				animations.advance(0.0)
		&"target_locked":
			if slots.has(-1): slots[-1].locked = true
		&"hit":
			_flash(event)
			if animations.has_animation(&"hit"):
				animations.play(&"hit")
				animations.advance(0.0)
		&"head_destroyed", &"finished", &"interrupted":
			if index < 0:
				clear_effects()
			else:
				slots.erase(index)
	queue_redraw()

func clear_effects() -> void:
	slots.clear()
	flashes.clear()
	for sprite in sprites.values():sprite.queue_free()
	sprites.clear()
	animations.stop()
	pulse_scale = 1.0
	queue_redraw()

func advance_effects(world_dt: float) -> void:
	if animations.is_playing(): animations.advance(world_dt)
	for event in slots.values():
		if event.has("delay"):
			event.delay -= world_dt
			if event.delay <= 0.0:
				event.cue = &"attack_started"
				event.erase("delay")
	for flash in flashes.duplicate():
		flash.life-=world_dt
		if flash.life<=0.0:
			sprites[flash.id].queue_free()
			sprites.erase(flash.id)
			flashes.erase(flash)
		else:sprites[flash.id].material.set_shader_parameter("progress",1.0-flash.life/flash.duration)
	if is_instance_valid(hydra) and hydra.recovery_t <= 0.0 and slots.has(-1) and slots[-1].cue == &"recovery_started":
		slots.erase(-1)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(hydra) or hydra.ctx == null or not hydra.has_body(): return
	for index: int in slots:
		var event: Dictionary = slots[index]
		var anchor: Transform2D = hydra.presentation_anchor(index)
		var point := anchor * (body_anchor.position if index < 0 else head_anchor.position)
		var radius: float = hydra.table.r[hydra.body] * body_radius_scale if index < 0 else head_radius
		var color := warning_color if event.cue == &"warning_started" else (recovery_color if event.cue == &"recovery_started" else attack_color)
		# 合図は開いた角で示し、本体を囲むシールド状の輪を作らない。
		var reach:=radius*0.55 if index<0 else radius
		for corner in 4:
			var direction:=Vector2(-1 if corner%2==0 else 1,-1 if corner<2 else 1)
			var at: Vector2=(point+direction*reach).snapped(Vector2(3,3))
			var points:=PackedVector2Array([at-Vector2(direction.x,0)*12.0,at,at-Vector2(0,direction.y)*12.0])
			draw_polyline(points,Color(color,0.8),line_width)
		if index < 0 and event.cue == &"warning_started":
			var technique: StringName = event.technique
			if technique == &"north":
				for target in hydra.presentation_targets():
					var marker: Color = locked_color if target.locked else warning_color
					draw_line(target.from, target.target, Color(marker, 0.55), line_width, true)
					draw_arc(target.target, target.radius, 0.0, TAU, 40, marker, line_width, true)
					draw_circle(target.target, line_width * 2.0, marker)
			elif technique in [&"east", &"west"]:
				for neck in hydra.necks:
					if neck.kind == &"beam" and hydra._alive(neck):
						var head: Vector2 = hydra._head_pos(neck)
						draw_line(head, head + Vector2.from_angle(neck.angle) * float(hydra.def.params.beam_len), Color(color, 0.4), line_width, true)

func _flash(event: Dictionary)->void:
	if not is_instance_valid(hydra.attack_field):return
	serial+=1
	var sprite:=Sprite2D.new()
	sprite.texture=hydra.attack_field.white
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position=event.position
	var large: bool=event.cue in [&"growth_started",&"separation_started"]
	var diameter:=520.0 if large else (220.0 if event.cue==&"head_destroyed" else 140.0)
	sprite.scale=Vector2.ONE*diameter/2.0
	sprite.material=ShaderMaterial.new()
	sprite.material.shader=burst_shader
	var color: Color={&"vortex":Color("#70ffe0"),&"thunder":Color("#77bbff"),&"debris":Color("#dbac68"),&"immortal":Color("#ffe69a")}.get(event.kind,attack_color)
	if event.cue==&"hit":color=hit_color
	sprite.material.set_shader_parameter("tint",color)
	sprite.material.set_shader_parameter("pixels",diameter/4.0 * burst_pixel_scale)
	sprite.set_meta("burst_diameter", diameter)
	sprite.material.set_shader_parameter("seed",float(serial%19))
	var profile: String = get_meta("visual_profile", scene_file_path)
	ShaderTuning.apply(sprite.material, profile, scene_file_path)
	sprite.set_meta("shader_tuning_profile", profile)
	sprite.set_meta("shader_tuning_fallback", scene_file_path)
	add_child(sprite)
	sprites[serial]=sprite
	var duration:=0.8 if large else maxf(flash_duration,0.3)
	flashes.append({"id":serial,"position":event.position,"cue":event.cue,"life":duration,"duration":duration})

## 編集中の停止フレームへ、描画だけを反映する。
func refresh_visual_settings() -> void:
	for sprite: Sprite2D in sprites.values():
		var material := sprite.material as ShaderMaterial
		material.set_shader_parameter("pixels", float(sprite.get_meta("burst_diameter")) / 4.0 * burst_pixel_scale)

func phase_state() -> Dictionary:
	if slots.is_empty() or hydra == null: return {}
	var event: Dictionary = slots[-1] if slots.has(-1) else slots.values()[0]
	var phase: StringName = &"windup" if event.cue == &"warning_started" else &"recover" if event.cue == &"recovery_started" else &"active"
	var settings: Dictionary = hydra.move_params(technique_id)
	var duration := float(event.get("duration", settings.get("normal_charge", settings.get("warning_time", 1.0)))) if phase == &"windup" else float(event.get("duration", settings.get("tech_recovery", settings.get("normal_hold", 1.0)))) if phase == &"recover" else float(settings.get("performance_time", settings.get("beam_time", settings.get("normal_lunge", 1.0))))
	return {"phase": phase, "elapsed": hydra._time - float(event.world_time), "duration": duration}
