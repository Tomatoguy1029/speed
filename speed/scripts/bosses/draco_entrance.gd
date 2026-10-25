## 道中の生存個体を保護し、星空・裂け目・赤眼・対面を実時間で見せる。
extends RefCounted
var actor: BossActor
var time := 0.0
var active := false
var held: Array = []
var center := Vector2.ZERO
var rift := 0.0
var emerged := 0.0
var base_zoom := 1.0
func _init(a: BossActor) -> void: actor=a
func begin() -> void:
	active=true;time=0.0
	center=actor.table.pos[actor.body]
	base_zoom=maxf(0.1,actor.run_state.camera_zoom)
	actor.mode=&"entrance"
	actor.table.guard[actor.body]=1.0
	actor.run_state.controls_locked=true
	actor.run_state.cinematic_bars=1.0
	actor.run_state.cinematic_camera=true
	actor.run_state.cinematic_hide_enemies=true
	actor.run_state.drawing=false;actor.run_state.tracing=false
	for row in actor.table.alive.size():
		if actor.table.alive[row]!=0 and actor.table.dead[row]==0 and actor.table.is_boss[row]==0:
			held.append({"row":row,"id":actor.table.id[row],"held":actor.table.held[row]})
			actor.table.held[row]=1
func tick(dt: float) -> bool:
	if not active: return false
	time+=dt
	var a = actor
	var quiet := float(a.def.params.get("entrance_quiet",2.5))
	rift=clampf((time-quiet)/1.2,0.0,1.0)
	emerged=clampf((time-quiet-1.2)/2.0,0.0,1.0)
	a._presentation.visible=rift>0.0
	a._presentation.modulate.a=0.35+emerged*0.65
	a._presentation.scale=Vector2.ONE*lerpf(0.2,1.0,emerged)
	a.run_state.view_center=center+Vector2(-140,0)
	a.run_state.camera_zoom=base_zoom*lerpf(0.75,1.0,emerged)
	if time>=quiet+4.8:
		cancel()
		a.mode=&"idle";a.table.guard[a.body]=0.0
	return active
func cancel() -> void:
	if not active: return
	active=false
	for member: Dictionary in held:
		if actor.ctx.enemies.is_same(member.row,member.id): actor.table.held[member.row]=int(member.held)
	held.clear()
	actor.run_state.controls_locked=false;actor.run_state.cinematic_bars=0.0
	actor.run_state.cinematic_camera=false;actor.run_state.cinematic_hide_enemies=false
	actor._presentation.visible=true;actor._presentation.modulate=Color.WHITE;actor._presentation.scale=Vector2.ONE
