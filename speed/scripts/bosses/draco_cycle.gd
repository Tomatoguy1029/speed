## 奥行きの遠近と命中形状を共有し、採集・帰還・再生成を連続させる。
extends RefCounted
const STATE = preload("res://scripts/bosses/draco_cinematic_state.gd")
var actor: BossActor
var first := false
var time := 0.0
var stage: StringName = &""
var home := Vector2.ZERO
var generated := 0
var next_cycle := 12.0
var base_zoom := 1.0
var _state := STATE.new()
var _from := Vector2.ZERO
var _return_from := Vector2.ZERO
var _return_depth := 1.0
var _return_alpha := 1.0
var _return_angle := 0.0
func _init(a: BossActor) -> void: actor=a
func begin_initial() -> void:
	if stage!=&"": cancel()
	_state.capture(actor)
	first=true;stage=&"roar";time=0.0;generated=0
	home=actor.table.pos[actor.body]
	_from=home
	base_zoom=maxf(0.1,actor.run_state.camera_zoom)
	actor.reset_pose()
	actor.run_state.cinematic_camera=true
	actor.run_state.controls_locked=true
	actor.run_state.cinematic_bars=1.0
	actor.run_state.encounter_protected=true
	actor.run_state.drawing=false;actor.run_state.tracing=false
	actor.run_state.ship_vel=Vector2.ZERO
	actor.table.guard[actor.body]=1.0
func begin_deep() -> void:
	if stage!=&"": return
	first=false;stage=&"collect";time=0.0;generated=0
	home=actor.table.pos[actor.body]
	_from=home
	actor.reset_pose()
	actor.mode=&"deep"
	actor.table.guard[actor.body]=1.0
	actor.picaro.attacking=true
func tick(dt: float) -> bool:
	var a=actor
	if stage==&"":
		if not a.selection_enabled or a.phase<2: return false
		if a.mode==&"idle":
			next_cycle-=dt
			if next_cycle<=0.0: begin_deep()
		return stage!=&""
	time+=dt
	if first:
		STATE.frame(a,a.run_state.ship_pos.lerp(a.table.pos[a.body],0.55),base_zoom*0.8)
	match stage:
		&"roar":
			if time>=1.0:
				stage=&"collect";time=0.0
		&"collect":
			var depth := smoothstep(0.0,1.25,time)
			a.table.pos[a.body]=_from+Vector2(sin(time*0.6)*180.0,-320.0)*depth
			a.apply_depth(lerpf(1.0,0.28,depth),lerpf(1.0,0.3,depth))
			a.table.guard[a.body]=1.0
			if time>=(2.0 if first else float(a.def.params.get("collect_time",12.0))) or (not first and a.picaro.alive().is_empty() and time>1.25):
				a.picaro.pause(false)
				stage=&"wait_beams";time=0.0
		&"wait_beams":
			var busy := false
			for member: Dictionary in a.picaro.alive():
				for h in a.ctx.projectiles.hazard_alive.size():
					if a.ctx.projectiles.owns_hazard(h,member.row,member.id): busy=true
			if not busy: _begin_return()
		&"return":
			var progress := smoothstep(0.0,1.2,time)
			a.table.pos[a.body]=_return_from.lerp(home,progress)
			a.table.facing[a.body]=lerp_angle(_return_angle,(a.run_state.ship_pos-home).angle(),progress)
			a.apply_depth(lerpf(_return_depth,1.0,progress),lerpf(_return_alpha,1.0,progress))
			if time>=1.2:
				a.reset_pose()
				a.table.guard[a.body]=1.0 if first else 0.0
				stage=&"generate";time=0.0;generated=0
		&"generate":
			var count := int(a.def.params.get("picaro_count",3))
			if time>=0.6+float(generated)*0.8 and generated<count:
				var choices: Array=a.def.params.get("picaro_candidates",[]).duplicate()
				if choices.is_empty():
					for id in ContentManager.catalog.table(&"enemies"):
						var source: EnemyDef=a.ctx.enemies.def_of(id)
						if source!=null and source.rank>0 and source.gate not in [&"solid",&"immortal"]: choices.append(id)
				if choices.is_empty(): choices=[&"biter"]
				var type := StringName(choices[a.run_state.rng.randi_range(0,choices.size()-1)])
				if not type in a.def.params.get("picaro_excluded",[]): a.picaro.spawn_picaro(type,home+Vector2(150,(generated-1)*180.0))
				generated+=1
			if time>0.6+count*0.8+1.0: _finish()
	a._update_body()
	return stage!=&""
func _begin_return() -> void:
	_return_from=actor.table.pos[actor.body]
	_return_depth=actor.perspective_scale
	_return_alpha=actor._presentation.modulate.a
	_return_angle=actor.table.facing[actor.body]
	if not first: home=actor.run_state.ship_pos+Vector2(500,-150)
	stage=&"return";time=0.0
func _finish() -> void:
	var was_first := first
	_state.restore(actor)
	stage=&"";first=false;time=0.0;next_cycle=10.0
	actor.reset_pose()
	actor.mode=&"idle";actor.elapsed=0.0
	actor.table.guard[actor.body]=0.0
	if was_first: actor.run_state.encounter_protected=false
	actor.picaro.attacking=false
func cancel() -> void:
	if stage==&"" and _state.saved.is_empty(): return
	var was_first := first
	_state.restore(actor)
	if was_first: actor.run_state.encounter_protected=false
	stage=&"";first=false;time=0.0;next_cycle=10.0
	actor.reset_pose()
	if actor.has_body():
		actor.table.guard[actor.body]=0.0
		if actor.mode in [&"deep",&"transition"]: actor.mode=&"idle"
		actor._update_body()
	actor.picaro.attacking=false
