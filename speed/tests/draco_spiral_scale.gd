extends Node
const FORM = preload("res://scripts/bosses/draco_form.gd")
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
			var fractions: PackedFloat32Array=FORM.fractions(spiral.points)
			for index in spiral.walls.size():
				var fraction := (fractions[index]+fractions[index+1])*0.5
				check(is_equal_approx(sim.projectiles.hazard_width[spiral.walls[index]],actor.body_width*FORM.taper(fraction)),"青紫の壁と胴体の先細りが一致する")
		actor.cancel_attack()
	actor.cancel_attack();actor.cycle.cancel()
	sim.state.view_half=Vector2(980,550)
	sim.state.ship_pos=Vector2.ZERO;sim.state.enemy_aim=Vector2.ZERO
	sim.state.ship_invuln=0.0;sim.ship.invincible=false
	var hp:=sim.state.ship_hp
	actor.start_attack(&"spiral")
	for frame in 558: actor.sim_tick(1.0/120.0,1.0/120.0)
	check(sim.state.ship_hp==hp,"収縮開始だけで、安全な空間の自機に即ダメージを出さない")
	for frame in 280: actor.sim_tick(1.0/120.0,1.0/120.0)
	check(sim.state.ship_hp<hp,"胴体が実際に閉じたところで挟まれた被弾を出す")
	actor.cancel_attack()
	check(is_equal_approx(actor.table.r[actor.body],baseline_radius),"技の終了時に頭の判定を元へ戻す")
	session.free()
	print("[draco_spiral_scale] failures=",failures)
	get_tree().quit(1 if failures else 0)
