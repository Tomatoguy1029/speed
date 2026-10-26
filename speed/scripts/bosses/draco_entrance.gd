## 生存個体を保護し、同じワールド基準で星空・裂け目・対面を見せる。
extends RefCounted
const STATE = preload("res://scripts/bosses/draco_cinematic_state.gd")
var actor: BossActor
var time := 0.0
var active := false
var stage: StringName = &""
var held: Array = []
var center := Vector2.ZERO
var rift_center := Vector2.ZERO
var rift_axis := Vector2.DOWN
var rift := 0.0
var eyes := 0.0
var chest_glow := 0.0
var emerged := 0.0
var base_zoom := 1.0
var _state := STATE.new()
var _origin := Vector2.ZERO
var _facing := 0.0
var _guard := 0.0
var _mode: StringName = &"idle"
var _ship := Vector2.ZERO
var _camera := Vector2.ZERO
func _init(a: BossActor) -> void: actor=a
func begin() -> void:
	if active: cancel()
	_state.capture(actor)
	_origin=actor.table.pos[actor.body]
	_facing=actor.table.facing[actor.body]
	_guard=actor.table.guard[actor.body]
	_mode=actor.mode
	_ship=actor.run_state.ship_pos
	_camera=actor.run_state.view_center
	base_zoom=maxf(0.1,actor.run_state.camera_zoom)
	center=_safe_stage_position(_ship+Vector2.UP*430.0)
	rift_center=center+Vector2.UP*70.0
	rift_axis=Vector2.DOWN
	active=true;time=0.0;stage=&"quiet"
	rift=0.0;eyes=0.0;chest_glow=0.0;emerged=0.0
	actor.reset_pose()
	actor.mode=&"entrance"
	actor.table.pos[actor.body]=center+Vector2.UP*120.0
	actor.table.facing[actor.body]=PI*0.5
	actor.table.guard[actor.body]=1.0
	actor.run_state.controls_locked=true
	actor.run_state.encounter_protected=true
	actor.run_state.cinematic_bars=1.0
	actor.run_state.cinematic_camera=true
	actor.run_state.cinematic_hide_enemies=true
	actor.run_state.ship_heading=Vector2.UP
	actor.run_state.ship_vel=Vector2.ZERO
	actor.run_state.drawing=false;actor.run_state.tracing=false
	actor._presentation.visible=false
	for row in actor.table.alive.size():
		if actor.table.alive[row]!=0 and actor.table.dead[row]==0 and actor.table.is_boss[row]==0:
			held.append({"row":row,"id":actor.table.id[row],"held":actor.table.held[row]})
			actor.table.held[row]=1
	actor._update_body()
func tick(dt: float) -> bool:
	if not active: return false
	time+=dt
	var quiet: float=float(actor.def.params.get("entrance_quiet",2.5))
	var reveal := quiet+1.35
	var confront := reveal+2.0
	var handoff := confront+1.4
	var finish_at := handoff+0.8
	emerged=smoothstep(reveal,confront,time)
	rift=smoothstep(quiet,quiet+1.0,time)*(1.0-smoothstep(confront,confront+0.7,time))
	eyes=smoothstep(quiet+0.55,reveal,time)*(1.0-smoothstep(confront,confront+0.5,time))
	chest_glow=smoothstep(reveal+0.3,confront,time)
	stage=&"quiet" if time<quiet else (&"rift" if time<reveal else (&"emerge" if time<confront else (&"confront" if time<handoff else &"handoff")))
	actor.table.pos[actor.body]=center+Vector2.UP*120.0*(1.0-emerged)
	actor.table.facing[actor.body]=PI*0.5
	actor._presentation.visible=time>=quiet
	actor._presentation.modulate=Color.WHITE
	var filmed := _ship.lerp(center,0.45)
	var move := smoothstep(0.0,1.5,time)
	var restore := smoothstep(handoff,finish_at,time)
	STATE.frame(actor,_camera.lerp(filmed,move).lerp(_camera,restore),lerpf(base_zoom,base_zoom*0.85,move*(1.0-restore)))
	actor.run_state.cinematic_bars=1.0-restore
	actor._update_body()
	if time>=finish_at: finish()
	return active
func skip() -> void:
	if active: finish()
func finish() -> void:
	if not active: return
	_end(false)
func cancel() -> void:
	if not active: return
	_end(true)
func _end(interrupted: bool) -> void:
	active=false;stage=&""
	for member: Dictionary in held:
		if actor.ctx.enemies.is_same(member.row,member.id): actor.table.held[member.row]=int(member.held)
	held.clear()
	_state.restore(actor)
	actor.reset_pose()
	actor.table.pos[actor.body]=_origin if interrupted else center
	actor.table.facing[actor.body]=_facing if interrupted else PI*0.5
	actor.table.guard[actor.body]=_guard
	actor.mode=_mode if interrupted else &"idle"
	actor._presentation.visible=true
	actor._presentation.modulate=Color.WHITE
	rift=0.0;eyes=0.0;chest_glow=0.0
	actor._update_body()

func _safe_stage_position(desired: Vector2) -> Vector2:
	var margin: float=actor.def.radius*actor.head_scale+40.0
	var limit: float=maxf(margin,float(actor.ctx.cfg.field_radius)-margin)
	var candidate:=desired.limit_length(limit)
	for pass_index in 4:
		candidate=actor.ctx.field.push_out(candidate,margin).limit_length(limit)
	if _clear_position(candidate,margin,limit): return candidate
	var best:=candidate
	var best_score:=INF
	for distance in [430.0,650.0,900.0]:
		for j in 24:
			var point: Vector2=(_ship+Vector2.from_angle(-PI*0.5+j*TAU/24.0)*float(distance)).limit_length(limit)
			if not _clear_position(point,margin,limit): continue
			var score: float=point.distance_squared_to(desired)+maxf(0.0,point.y-_ship.y)*1000.0
			if score<best_score: best=point;best_score=score
	return best
func _clear_position(point: Vector2, margin: float, limit: float) -> bool:
	if point.length()>limit+0.1: return false
	for body: FieldSystem.Body in actor.ctx.field.bodies:
		if point.distance_to(body.pos)<body.r+margin-0.1: return false
	return true
