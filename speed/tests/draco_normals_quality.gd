extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled = false
	var session := RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":709},false)
	session.auto_step = false
	var sim: RunSimulation = session.sim
	sim.field.bodies.clear()
	sim.state.phase = RunState.Phase.PLAY
	sim.ship.invincible = false
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var a = sim.bosses.actor
	a.selection_enabled = false
	for angle in [0.0, PI*0.5, PI, PI*0.25]:
		a.cancel_attack()
		a.cycle.cancel()
		a.table.pos[a.body] = Vector2.ZERO
		a.table.facing[a.body] = angle
		sim.state.ship_pos = Vector2.from_angle(angle)*300.0
		sim.state.enemy_aim = Vector2(-900,-900)
		sim.state.ship_vel = Vector2.ZERO
		sim.state.ship_invuln = 0.0
		var hp: float = sim.state.ship_hp
		check(a.start_attack(&"bite"),"bite starts in each direction")
		check(a.aim.distance_to(sim.state.ship_pos)<1.0,"bite locks actual player rather than stale enemy aim")
		var head_start: Vector2 = a.table.pos[a.body]
		for frame in 48: a.sim_tick(1.0/120.0,1.0/120.0)
		check(a.table.pos[a.body].distance_to(head_start)>15.0,"bite has a visible retract motion")
		for frame in 320: a.sim_tick(1.0/120.0,1.0/120.0)
		check(sim.state.ship_hp<hp,"committed stationary target is bitten, angle=%s" % angle)
		check(a.table.pos[a.body].distance_to(head_start)<2.0,"bite recovers to initial head position")
		a.cancel_attack()
		a.table.pos[a.body]=Vector2.ZERO
		sim.state.ship_pos=Vector2.from_angle(angle)*300.0
		sim.state.ship_invuln=0.0
		hp=sim.state.ship_hp
		a.start_attack(&"bite")
		for frame in 90: a.sim_tick(1.0/120.0,1.0/120.0)
		sim.state.ship_pos+=Vector2.from_angle(angle).orthogonal()*400.0
		for frame in 220: a.sim_tick(1.0/120.0,1.0/120.0)
		check(is_equal_approx(sim.state.ship_hp,hp),"sideways dodge avoids committed bite")
	session.free()
	print("[draco_normals_quality] failures=",failures)
	get_tree().quit(1 if failures else 0)
