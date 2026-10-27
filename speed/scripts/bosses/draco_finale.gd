## HP0後の実時間シーケンス。構図・自由描画・固定決着を一つの所有者で接続する。
extends RefCounted
const STATE = preload("res://scripts/bosses/draco_cinematic_state.gd")
const MODULES: Array[StringName]=[&"legendary_stern",&"legendary_keel",&"legendary_sail",&"legendary_compass"]
const BEAR=[Vector2(0,-130),Vector2(-35,-65),Vector2(-80,-15),Vector2(-145,10),Vector2(-130,70),Vector2(-55,80),Vector2(-80,-15)]
var actor: BossActor
var stage: StringName = &""
var time := 0.0
var center := Vector2.ZERO
var core := Vector2.ZERO
var guide := PackedVector2Array()
var strokes := PackedVector2Array()
var began := false
var completed := false
var base_zoom := 1.0
var line := PackedVector2Array()
var dim := 0.0
var split := 0.0
var pose_radius := 320.0
var combine_progress := 0.0
var strike_trails: Array = []
var _state := STATE.new()
var _core_from := Vector2.ZERO
var _camera_from := Vector2.ZERO
var _assembly_camera := Vector2.ZERO
var _assembly_zoom := 1.0
var _pose_from := PackedVector2Array()
var _pose := PackedVector2Array()
var _original_pos := Vector2.ZERO
var _original_angle := 0.0
var _original_guard := 0.0
var _original_ship := Vector2.ZERO
var _original_ship_velocity := Vector2.ZERO
var _modules_before: Array[StringName] = []
var _last_strike := -1
var _finish_before := false
func _init(a: BossActor) -> void: actor=a
func begin() -> void:
	if stage!=&"" and not completed: dispose()
	var a=actor
	_original_ship=a.run_state.ship_pos
	_original_ship_velocity=a.run_state.ship_vel
	a.entrance.cancel();a.cancel_attack();a.cycle.cancel();a.picaro.pause(true)
	_state.capture(a)
	_original_pos=a.table.pos[a.body]
	_original_angle=a.table.facing[a.body]
	_original_guard=a.table.guard[a.body]
	_modules_before=a.run_state.final_modules.duplicate()
	_finish_before=a.run_state.draco_finish_done
	a.run_state.draco_finish_done=false
	a.run_state.final_modules.clear()
	_pose_from=a.body_points()
	_camera_from=a.run_state.view_center
	base_zoom=maxf(0.1,a.run_state.camera_zoom)
	_assembly_camera=_camera_from
	_assembly_zoom=base_zoom
	center=_original_pos-Vector2.from_angle(_original_angle)*a.body_length*0.32
	pose_radius=maxf(a.body_width*2.0,a.body_length/(TAU*0.76))
	_core_from=a.chest_pos()
	core=_core_from
	_pose.clear();guide.clear();strokes.clear();line.clear();strike_trails.clear()
	for j in a.body_segments+1:
		var t:=float(j)/float(a.body_segments)
		var angle:=-PI*0.25+t*TAU*0.76
		var radius:=pose_radius*(0.94+sin(t*PI)*0.06)
		_pose.append(center+Vector2.from_angle(angle)*radius)
	began=false;completed=false;dim=0.0;split=0.0;combine_progress=0.0;_last_strike=-1
	stage=&"release";time=0.0
	a.mode=&"finale";a.table.hp[a.body]=1.0;a.table.guard[a.body]=1.0
	a.run_state.controls_locked=true;a.run_state.encounter_protected=true
	a.run_state.cinematic_bars=1.0;a.run_state.cinematic_camera=true
	a.run_state.cinematic_hide_enemies=true
	a.run_state.drawing=false;a.run_state.tracing=false;a.run_state.ship_vel=Vector2.ZERO
	a.run_state.world_scale=0.0
	a.presentation_event.emit({"cue":&"core_released","pos":core,"radius":100.0})
func advance(dt: float, intent: Intent) -> void:
	if stage==&"" or completed: return
	var a=actor
	time+=dt;a.clock+=dt
	a._update_closing_walls(dt)
	a.run_state.world_scale=0.0
	strike_trails=strike_trails.filter(func(trail):return a.clock-float(trail.time)<0.5)
	match stage:
		&"release":
			core=_core_from.lerp(center+Vector2(-60,-250),smoothstep(0.0,1.8,time))
			if time>=2.0:
				a.presentation_event.emit({"cue":&"bear_roar","pos":core,"radius":180.0})
				_next(&"combine")
		&"combine":
			combine_progress=smoothstep(0.0,1.8,time)
			if time>=2.0:
				a.run_state.final_modules=MODULES.duplicate()
				_next(&"pose")
		&"pose":
			var progress:=smoothstep(0.0,1.2,time)
			var pose:=PackedVector2Array()
			for j in _pose.size():
				var index:=clampi(roundi(float(j)*float(_pose_from.size()-1)/float(_pose.size()-1)),0,_pose_from.size()-1)
				pose.append(_pose_from[index].lerp(_pose[j],progress))
			a.body_override=pose;a.table.pos[a.body]=pose[0]
			a.table.facing[a.body]=(pose[0]-pose[1]).angle()
			if time>=1.2:
				_next(&"input")
				a.run_state.controls_locked=false;a.run_state.cinematic_bars=0.0
				for j in 65: guide.append(center+Vector2.from_angle(j*TAU/64.0)*(pose_radius+a.body_width*0.8))
		&"input":
			if intent.press or intent.alt_press:
				if not began:
					began=true;strokes.append(intent.pen)
			if began and intent.has_cursor and (strokes.is_empty() or strokes[-1].distance_to(intent.pen)>3.0): strokes.append(intent.pen)
			if began and intent.pen_release:
				_next(&"strikes")
				a.run_state.controls_locked=true;a.run_state.drawing=false
			else: a.run_state.drawing=began
		&"strikes":
			var count:=maxi(1,int(a.def.params.get("finish_passes",8)))
			var duration:=maxf(0.15,float(a.def.params.get("finish_pass_time",0.32)))
			var index:=mini(count-1,int(time/duration))
			var progress:=fmod(time,duration)/duration
			var direction:=Vector2.from_angle(index*2.399963)
			line=PackedVector2Array([center-direction*(pose_radius+340.0),center+direction*(pose_radius+340.0)])
			a.run_state.ship_pos=line[0].lerp(line[1],clampf(progress*1.4,0.0,1.0))
			a.run_state.ship_heading=direction
			if index!=_last_strike:
				_last_strike=index
				strike_trails.append({"points":line.duplicate(),"time":a.clock})
				a.presentation_event.emit({"cue":&"finish_strike","pos":center,"radius":pose_radius*0.7})
			if time>=count*duration: _next(&"last")
		&"last":
			line=PackedVector2Array([center+Vector2.DOWN*(pose_radius+750.0),center+Vector2.UP*(pose_radius+750.0)])
			a.run_state.ship_pos=line[0].lerp(line[1],smoothstep(0.0,0.3,time))
			a.run_state.ship_heading=Vector2.UP
			dim=0.95*smoothstep(0.03,0.16,time)
			if time>=0.4: _next(&"sight")
		&"sight":
			dim=lerpf(0.95,0.0,smoothstep(0.0,1.6,time))
			if time>=1.6: _next(&"split")
		&"split":
			split=smoothstep(0.0,0.5,time)
			if time>=0.65:
				_next(&"explode")
				a.presentation_event.emit({"cue":&"cosmic_collapse","pos":center,"radius":pose_radius+a.body_width})
		&"explode":
			if time>=1.1:
				completed=true;a.run_state.draco_finish_done=true
				dispose()
				a.ctx.bosses.on_boss_defeated(a.body,{"cause":&"draco_finale","finale_complete":true})
	if completed: return
	_frame()
	a._update_body();a._presentation.queue_redraw()
func _next(next: StringName) -> void:
	stage=next;time=0.0
func _frame() -> void:
	var target:=base_zoom*0.82
	var camera:=center
	if stage in [&"release",&"combine"]:
		var head_radius: float=actor.head_scale*165.0
		var head: Vector2=actor.table.pos[actor.body]
		var bounds:=Rect2(head-Vector2.ONE*head_radius,Vector2.ONE*head_radius*2.0)
		bounds=bounds.merge(Rect2(actor.run_state.ship_pos-Vector2.ONE*64.0,Vector2.ONE*128.0))
		bounds=bounds.merge(Rect2(core-Vector2.ONE*280.0,Vector2.ONE*560.0))
		camera=bounds.get_center()
		if stage==&"release": camera=_camera_from.lerp(camera,smoothstep(0.0,1.4,time))
		target=_fit_assembly(bounds,camera,target)
		_assembly_camera=camera;_assembly_zoom=target
	elif stage==&"pose":
		var progress:=smoothstep(0.0,1.2,time)
		camera=_assembly_camera.lerp(center,progress)
		target=lerpf(_assembly_zoom,target,progress)
	elif stage==&"strikes":
		var length:=float(maxi(1,int(actor.def.params.get("finish_passes",8))))*maxf(0.15,float(actor.def.params.get("finish_pass_time",0.32)))
		target=base_zoom*lerpf(0.82,1.15,clampf(time/length,0.0,1.0))
	elif stage in [&"last",&"sight",&"split",&"explode"]: target=base_zoom*0.52
	STATE.frame(actor,camera,target)
func _fit_assembly(bounds: Rect2, camera: Vector2, desired_zoom: float) -> float:
	var viewport_size: Vector2=actor.ctx.options.get("view_size",actor.get_viewport().get_visible_rect().size)
	if viewport_size.x<=0.0 or viewport_size.y<=0.0: viewport_size=Vector2(1280,720)
	var half_extent: Vector2=(bounds.position-camera).abs().max((bounds.end-camera).abs())
	return minf(desired_zoom,minf(viewport_size.x*0.44/maxf(1.0,half_extent.x),viewport_size.y*0.36/maxf(1.0,half_extent.y)))
func dispose() -> void:
	if _state.saved.is_empty(): return
	_state.restore(actor)
	actor.run_state.drawing=false;actor.run_state.tracing=false
	if not completed:
		actor.run_state.ship_pos=_original_ship
		actor.run_state.ship_vel=_original_ship_velocity
		actor.run_state.final_modules=_modules_before.duplicate()
		actor.run_state.draco_finish_done=_finish_before
		actor.reset_pose()
		if actor.has_body():
			actor.table.pos[actor.body]=_original_pos
			actor.table.facing[actor.body]=_original_angle
			actor.table.guard[actor.body]=_original_guard
			actor.mode=&"idle"
			actor._update_body()
		stage=&""
