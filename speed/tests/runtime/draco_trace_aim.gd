extends Node
const MOTION = preload("res://scripts/bosses/draco_attack_motion.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled = false
	var session := RunManager.create_session(self, {"lab": true, "stage": stage, "stage_index": 5, "seed": 611}, false)
	session.auto_step = false
	var sim: RunSimulation = session.sim
	sim.field.bodies.clear()
	sim.state.phase = RunState.Phase.PLAY
	sim.bosses.spawn(load("res://data/bosses/draco.tres"), Vector2.ZERO)
	var actor = sim.bosses.actor
	actor.entrance.cancel()
	actor.cycle.cancel()
	actor.selection_enabled = false
	for id in [&"charge", &"leap", &"tail_slam", &"star_fan"]:
		actor.cancel_attack()
		actor.table.pos[actor.body] = Vector2.ZERO
		actor.table.facing[actor.body] = 0.0
		actor.body_trail.clear()
		actor.body_pose.clear()
		actor.reset_pose()
		sim.state.ship_pos = Vector2(600, 0)
		sim.state.ship_vel = Vector2(0, 1500)
		sim.state.enemy_aim = Vector2(500, 0)
		sim.state.tracing = true
		check(actor.start_attack(id), "攻撃開始: %s" % id)
		var locked_aim: Vector2 = actor._runner.target if id == &"tail_slam" else actor.aim
		check(actor.aim_target(0.5) == sim.state.enemy_aim, "なぞり中の直接照準: %s" % id)
		check(MOTION.predict(actor, 1.0, 900.0) == sim.state.enemy_aim, "なぞり中の速度予測停止: %s" % id)
		sim.state.ship_pos = Vector2(800, 900)
		actor.sim_tick(1.0 / 60.0, 1.0 / 600.0)
		if id in [&"charge", &"leap"]:
			for frame in 1200:
				if actor._runner.locked: break
				actor.sim_tick(1.0 / 60.0, 1.0 / 60.0)
		check(actor._runner.locked, "なぞり開始で予告照準を確定: %s" % id)
		check((actor._runner.target if id == &"tail_slam" else actor.aim).distance_to(locked_aim) < 0.01, "高速移動へ照準を引きずらない: %s" % id)
		sim.state.tracing = false
		sim.state.glide = true
		sim.state.ship_pos = Vector2(-900, -300)
		actor.sim_tick(1.0 / 60.0, 1.0 / 60.0)
		check((actor._runner.target if id == &"tail_slam" else actor.aim).distance_to(locked_aim) < 0.01, "なぞり後も同じ予告を維持: %s" % id)
		if id in [&"charge", &"leap"]:
			actor.elapsed = float(actor.rule().warn) - 0.001
			actor.sim_tick(1.0 / 60.0, 1.0 / 60.0)
			var destination: Vector2 = actor._runner.destination
			sim.state.ship_pos = Vector2(1500, 1500)
			actor.sim_tick(1.0 / 60.0, 1.0 / 60.0)
			check(actor._runner.destination == destination, "発進後の軌道は自機を追わない: %s" % id)
		sim.state.glide = false
	actor.cancel_attack()
	sim.state.tracing = false
	sim.state.ship_pos = Vector2(600, 0)
	sim.state.ship_vel = Vector2.ZERO
	actor.table.pos[actor.body] = Vector2.ZERO
	check(actor.start_attack(&"charge"), "通常の突進を開始")
	for frame in 1200:
		if actor._runner.staging.phase == &"ready": break
		actor.sim_tick(1.0 / 60.0, 1.0 / 60.0)
	var normal_aim: Vector2 = actor.aim
	sim.state.ship_pos = Vector2(650, 120)
	actor.sim_tick(1.0 / 60.0, 1.0 / 60.0)
	check(actor.aim.distance_to(normal_aim) > 1.0 and not actor._runner.locked, "通常時は予告確定まで狙いを更新")
	actor.cancel_attack()
	sim.state.ship_pos = Vector2.ZERO
	sim.state.enemy_aim = Vector2.ZERO
	sim.state.tracing = true
	check(actor.start_attack(&"spiral"), "渦を開始")
	var spiral = actor._runner
	for frame in 1200:
		if not spiral.departing: break
		actor.sim_tick(1.0 / 60.0, 1.0 / 60.0)
	sim.state.ship_pos = Vector2(400, 0)
	actor.sim_tick(1.0 / 60.0, 1.0 / 60.0)
	check(spiral.center.x > 0.0 and not spiral.locked, "渦の構図追従を止めず発進までは移動")
	actor.cancel_attack()
	actor.selection_enabled = true
	actor.table.pos[actor.body] = Vector2.ZERO
	actor.table.facing[actor.body] = 0.0
	sim.state.ship_pos = Vector2(0, 1200)
	sim.state.enemy_aim = Vector2(1200, 0)
	actor.sim_tick(1.0 / 60.0, 1.0 / 600.0)
	check(actor.table.pos[actor.body].x > 0.0 and absf(actor.table.facing[actor.body]) < 0.01, "なぞり中の待機旋回も自機へ瞬時に向き直らない")
	session.free()
	print("[draco_trace_aim] failures=", failures)
	get_tree().quit(1 if failures else 0)
