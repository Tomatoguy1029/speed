## Shared armored silhouette, cosmic energy and explicit attack geometry.
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var core_glow_radius := 43.0
@export var core_glow_opacity := 0.16
@export var core_glow_color := Color(0.38, 0.59, 1.0)
@export var rift_color := Color("#5a4d91")
var actor: BossActor
var _parts: Node2D
var _core: Node2D
const FORM = preload("res://scripts/bosses/draco_form.gd")
const MODULE_GEOMETRY = preload("res://scripts/ui/legendary_module_geometry.gd")
func _ready() -> void:
	_parts = preload("res://scripts/bosses/draco_parts.gd").new()
	add_child(_parts)
	_core = Node2D.new()
	_core.z_index = 2
	_core.draw.connect(_draw_core)
	add_child(_core)
	material = preload("res://scripts/bosses/boss_hit_feedback.gd").new().make_material()
	EFFECT_SETTINGS.apply_key(self, "boss/body/draco")
func _process(_dt: float) -> void:
	var sample := {"white":0.0,"offset":Vector2.ZERO,"angle":0.0}
	if actor != null and actor.has_body(): sample = actor.hit_feedback.sample(actor.body_id)
	position = sample.offset
	rotation = sample.angle
	material.set_shader_parameter("boss_hit_white", sample.white)
	_core.queue_redraw()
	if actor == null or not actor.has_body():
		_parts.hide()
		return
	var points := PackedVector2Array()
	for point in actor.body_points(): points.append(actor.to_local(point))
	var alpha := smoothstep(0.0, 1.0, actor.entrance.emerged) if actor.entrance.active else 1.0
	if actor.finale.stage == &"explode": alpha = 0.0
	_parts.pose(points, actor.body_width * actor.perspective_scale, actor.head_scale * actor.perspective_scale,
		alpha, actor.cosmic_body, sample.white, actor.to_local(actor.finale.center),
		Vector2.RIGHT.rotated(-actor.rotation) * actor.finale.split * 90.0)


func on_event(event: Dictionary) -> void:
	if event.cue in [&"phase_changed",&"bear_roar"]:
		var at: Vector2=event.get("pos",actor.table.pos[actor.body])
		actor.run_state.emit(&"draco_roar",{"pos":at,"radius":700.0})
func _draw() -> void:
	if actor == null or not actor.has_body(): return
	_draw_rift()
	if actor.finale.stage==&"strikes":
		for trail: Dictionary in actor.finale.strike_trails:
			var age: float=actor.clock-float(trail.time)
			var path := _local_points(trail.points)
			if path.size()>1:
				draw_polyline(path,Color(0.5,0.56,1.0,maxf(0.0,0.35-age*0.7)),14.0,false)
				draw_polyline(path,Color(0.83,0.93,1.0,maxf(0.0,0.7-age*1.4)),3.0,false)

	if actor.finale.stage in [&"release",&"combine",&"pose",&"input"]:
		var at := actor.to_local(actor.finale.core)
		var bear := PackedVector2Array()
		for point in actor.finale.BEAR: bear.append(actor.to_local(actor.finale.core+point))
		draw_polyline(bear,Color("#e6eeff"),3.0,false)
		for point in bear: FORM.star(self,point,9.0,Color("#eefaff"))
		draw_circle(bear[0],12.0,Color.WHITE)
		if actor.finale.stage == &"combine":
			for j in 4:
				var from: Vector2=actor.to_local(actor.finale.core+Vector2.from_angle(j*TAU/4.0)*250.0)
				var position: Vector2=from.lerp(actor.to_local(actor.run_state.ship_pos),clampf(actor.finale.time/2.0,0.0,1.0))
				draw_set_transform(position,-actor.rotation,Vector2.ONE*0.4)
				MODULE_GEOMETRY.draw(self,String(actor.finale.MODULES[j]),Color("#d3c2ff"))
				draw_set_transform(Vector2.ZERO)
				FORM.star(self,position,7.0,Color("#f3eaff"))

	if actor.finale.stage == &"input":
		var guide := PackedVector2Array()
		for point in actor.finale.guide: guide.append(actor.to_local(point))
		if guide.size()>1: draw_polyline(guide,Color(0.65,0.75,1.0,0.18),3.0,false)
		var strokes := PackedVector2Array()
		for point in actor.finale.strokes: strokes.append(actor.to_local(point))
		if strokes.size()>1: draw_polyline(strokes,Color("#effaff"),4.0,false)

	if actor.cycle.stage==&"collect":
		for j in 16:
			var k:=fmod(actor.cycle.time*0.5+j/16.0,1.0)
			var at:=Vector2.from_angle(j*2.399963)*450.0*(1.0-k)
			draw_circle(at,4.0,Color(0.8,0.9,1.0,k))

func _local_points(world: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in world: result.append(actor.to_local(point))
	return result

func _draw_rift() -> void:
	if not actor.entrance.active: return
	var opening: float=actor.entrance.rift
	if opening<=0.0: return
	var center: Vector2=actor.entrance.get("rift_center") if actor.entrance.get("rift_center")!=null else actor.table.pos[actor.body]
	var axis: Vector2=actor.entrance.get("rift_axis") if actor.entrance.get("rift_axis")!=null else Vector2.DOWN
	var line := PackedVector2Array()
	for j in 19:
		var along := float(j-9)*55.0*opening
		var side := (sin(j*2.3)*24.0+sin(j*4.9)*12.0)*opening
		line.append(actor.to_local(center+axis*along+axis.orthogonal()*side))
	draw_polyline(line,Color(0.41,0.25,0.88,0.22),160.0*opening,false)
	draw_polyline(line,rift_color,105.0*opening,false)
	draw_polyline(line,Color("#050612"),88.0*opening,false)
	var eyes: float=float(actor.entrance.get("eyes") if actor.entrance.get("eyes")!=null else opening)
	if eyes>0.0 and actor.entrance.emerged<0.4:
		for side in [-1,1]:
			var at: Vector2=actor.to_local(center+axis.orthogonal()*side*65.0)
			var offset: Vector2=axis.rotated(-actor.rotation)*12.0
			draw_line(at-offset,at+offset,Color(1.0,0.1,0.3,eyes),8.0,false)


func _draw_core() -> void:
	if actor == null or not actor.has_body(): return
	if actor.finale.stage != &"explode":
		var core: Vector2 = actor.to_local(actor.chest_pos())
		var core_glow := 1.0
		if actor.entrance.active: core_glow=float(actor.entrance.get("chest_glow") if actor.entrance.get("chest_glow")!=null else actor.entrance.emerged)
		if actor.finale.stage!=&"": core_glow=0.12 if actor.finale.split<=0.0 else 0.0
		var pulse := 0.85+sin(actor.clock*3.0)*0.15
		_core.draw_circle(core,core_glow_radius*actor.perspective_scale,Color(core_glow_color,core_glow*core_glow_opacity*pulse))
		FORM.star(_core,core,27.0*actor.perspective_scale,Color(0.85,0.96,1.0,core_glow))
