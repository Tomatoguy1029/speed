extends Node
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func _ready() -> void:
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":405},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var actor=sim.bosses.actor
	sim.state.enemy_aim=Vector2.ZERO
	var baseline_radius: float=actor.table.r[actor.body]
	for half in [Vector2(980,550),Vector2(550,550),Vector2(550,980)]:
		actor.cancel_attack();actor.cycle.cancel()
		sim.state.view_half=half
		actor.start_attack(&"spiral")
		var spiral=actor._driver
		var short_side := minf(half.x,half.y)*2.0
		check(spiral.extent<=minf(half.x,half.y)*0.9,"渦の半径を画面短辺で抑える")
		check(actor.get("body_width")!=null,"螺旋の胴体の太さを表示と判定で共有する")
		if actor.get("body_width")!=null:
			check(actor.body_width>=short_side*0.13,"胴体を画面に対して十分太くする")
			check(actor.head_scale>=1.8,"螺旋では頭部も大きくする")
			for frame in 540: actor.sim_tick(1.0/120.0,1.0/120.0)
			for h in spiral.walls: check(is_equal_approx(sim.projectiles.hazard_width[h],actor.body_width),"青紫の壁と胴体の太さが一致する")
		actor.cancel_attack()
	check(is_equal_approx(actor.table.r[actor.body],baseline_radius),"技の終了時に頭の判定を元へ戻す")
	session.free()
	print("[draco_spiral_scale] failures=",failures)
	get_tree().quit(1 if failures else 0)
