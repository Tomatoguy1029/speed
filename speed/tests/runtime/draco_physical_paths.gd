extends Node
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:
		failures+=1;push_error(label)
func length_of(points: PackedVector2Array) -> float:
	var result := 0.0
	for j in range(points.size()-1):result+=points[j].distance_to(points[j+1])
	return result
func _ready() -> void:
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":710},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.field.bodies.clear();sim.state.phase=RunState.Phase.PLAY
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var a=sim.bosses.actor
	a.selection_enabled=false
	for id in [&"bite",&"tail_sweep",&"tail_slam"]:
		for angle in [0.0,PI*0.5,PI,PI*0.25]:
			a.cancel_attack();a.cycle.cancel()
			a.table.pos[a.body]=Vector2.ZERO;a.table.facing[a.body]=angle
			sim.state.ship_pos=Vector2.from_angle(angle)*(300.0 if id!=&"tail_sweep" else -800.0)
			sim.state.enemy_aim=Vector2(-900,-900);sim.state.ship_vel=Vector2.ZERO
			a.start_attack(id)
			var initial_length: float=length_of(a._runner.base)
			var maximum_error := 0.0
			var active_seen := false
			for frame in 600:
				var before: PackedVector2Array=a.body_points()
				a.sim_tick(1.0/120.0,1.0/120.0)
				if a.mode==&"idle":
					var after: PackedVector2Array=a.body_points()
					var jump := 0.0
					for j in before.size():jump=maxf(jump,before[j].distance_to(after[j]))
					check(jump<25.0,"recovery returns to live idle pose without tail snap: %s jump%s" % [id,jump])
					break
				if not a.body_override.is_empty():maximum_error=maxf(maximum_error,absf(length_of(a.body_points())-initial_length))
				if a.mode==&"active":active_seen=true
			check(active_seen,"physical move reaches active: %s" % id)
			check(maximum_error<1.0,"authored spine length survives pose+recovery: %s angle%s error%s" % [id,angle,maximum_error])
			print("[spine] ",id," angle=",angle," baseline=",initial_length," max_error=",maximum_error)
	# 投射は高HPの壊せる遮蔽として残り、ブレスは同じ個体を最後まで使う。
	a.cancel_attack();a.table.pos[a.body]=Vector2.ZERO;a.table.facing[a.body]=0.0
	sim.state.ship_pos=Vector2(700,0);sim.state.ship_vel=Vector2.ZERO
	a.start_attack(&"meteor")
	for frame in 200:a.sim_tick(1.0/120.0,1.0/120.0)
	check(a.placed_meteors.size()==3,"meteor move leaves three cover rocks")
	var rocks: Array=a.placed_meteors.duplicate()
	for rock: FieldSystem.Rock in rocks:
		check(a.table.max_hp[rock.row]>100.0,"cover tougher than normal meteor")
	a.start_attack(&"breath")
	check(a._runner.reused,"breath reuses prior thrown cover")
	for frame in 370:a.sim_tick(1.0/120.0,1.0/120.0)
	for rock: FieldSystem.Rock in rocks:check(a.table.dead[rock.row]==0,"cover survives entire unfinished breath")
	for frame in 100:a.sim_tick(1.0/120.0,1.0/120.0)
	for rock: FieldSystem.Rock in rocks:check(a.table.dead[rock.row]!=0,"cover collapses only after breath damage ends")
	session.free()
	print("[draco_physical_paths] failures=",failures)
	get_tree().quit(1 if failures else 0)
