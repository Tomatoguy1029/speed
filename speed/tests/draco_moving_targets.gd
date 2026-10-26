extends Node
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;push_error(label)
func _ready() -> void:
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":711},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.field.bodies.clear();sim.state.phase=RunState.Phase.PLAY
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var a=sim.bosses.actor
	a.selection_enabled=false
	for id in [&"bite",&"charge",&"leap",&"tail_slam",&"star_fan"]:
		for angle in [0.0,PI*0.5,PI*0.25]:
			for dodge in [false,true]:
				a.cancel_attack();a.cycle.cancel();sim.projectiles.clear_hostile()
				a.table.pos[a.body]=Vector2.ZERO;a.table.facing[a.body]=angle
				sim.state.phase=RunState.Phase.PLAY;sim.state.ship_hp=10000.0;sim.state.ship_invuln=0.0
				sim.state.ship_pos=Vector2.from_angle(angle)*(300.0 if id==&"bite" else 600.0)
				sim.state.ship_vel=Vector2.from_angle(angle).orthogonal()*500.0
				sim.state.enemy_aim=Vector2(-900,-900)
				a.start_attack(id)
				var changed := false
				var lock := Vector2.ZERO
				for frame in 420:
					var t := frame/120.0
					if t>0.35 and not changed:
						changed=true;lock=a.aim
						if dodge:sim.state.ship_vel=-sim.state.ship_vel*2.0
					if changed and a.mode==&"windup":check(a.aim.distance_to(lock)<1.0,"committed target no longer homes: %s" % id)
					sim.state.ship_pos+=sim.state.ship_vel/120.0
					sim._update_camera(1.0/120.0)
					a.sim_tick(1.0/120.0,1.0/120.0)
					sim.projectiles.tick(1.0/120.0,1.0/120.0)
				var hit := sim.state.ship_hp<10000.0
				print("[moving] ",id," angle=",angle," reverse=",dodge," hit=",hit)
				check(hit!=dodge,"steady cruise is threatened; direction change dodges: %s %s reverse%s" % [id,angle,dodge])
	# 最小射程250でも、口先の前に現れた中央弾が停止機体へ届く。
	a.cancel_attack();a.table.pos[a.body]=Vector2.ZERO;sim.projectiles.clear_hostile()
	sim.state.ship_pos=Vector2(250,0);sim.state.ship_vel=Vector2.ZERO;sim.state.ship_hp=10000.0;sim.state.ship_invuln=0.0
	a.start_attack(&"star_fan")
	for frame in 300:
		a.sim_tick(1.0/120.0,1.0/120.0);sim.projectiles.tick(1.0/120.0,1.0/120.0)
	check(sim.state.ship_hp<10000.0,"fan minimum permitted distance250 remains dangerous")
	session.free()
	print("[draco_moving_targets] failures=",failures)
	get_tree().quit(1 if failures else 0)
