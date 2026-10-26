extends Node
const FORM = preload("res://scripts/bosses/draco_form.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func _ready() -> void:
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":720},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var actor=sim.bosses.actor
	if actor._presentation==null:
		check(false,"renderer must compile before dimensional checks")
		session.free();get_tree().quit(1);return
	actor.selection_enabled=false
	actor.table.guard[actor.body]=0.0
	check(actor.body_rows.size()==actor.body_segments,"authored spine has one damage sample per segment")
	for angle in [0.0,PI*0.5,PI,PI*1.5,0.73]:
		actor.reset_pose()
		actor.table.pos[actor.body]=Vector2(280,-170)
		actor.table.facing[actor.body]=angle
		actor._update_body()
		var points: PackedVector2Array=actor.body_points()
		check(is_equal_approx(FORM.length(points),actor.body_length),"authored body arc length must survive every facing and wave pose")
		var base_radius: float=actor.table.r[actor.body]
		for j in actor.body_rows.size():
			var t:=float(j+1)/float(actor.body_rows.size())
			var row: int=actor.body_rows[j]
			check(actor.table.pos[row].distance_to(FORM.sample(points,t))<0.001,"drawn and colliding spine samples must agree")
			check(is_equal_approx(actor.table.r[row],actor.body_width*0.5*FORM.taper(t)),"tapered silhouette and collider widths must agree")
		actor.apply_depth(0.25,0.4)
		var depth: PackedVector2Array=actor.body_points()
		check(is_equal_approx(actor.table.r[actor.body],base_radius*0.25),"perspective must scale the head damage shape too")
		check(depth[-1].distance_to(depth[0])<points[-1].distance_to(points[0])*0.251,"perspective scales the same spine that is rendered")
		check(actor._presentation.scale==Vector2.ONE,"perspective cannot add a second render-only scale")
		actor.reset_pose()
		check(is_equal_approx(actor.table.r[actor.body],base_radius),"reset restores authored head dimensions")
		check(is_equal_approx(actor.perspective_scale,1.0),"depth resets completely")
	# A curved override must use the same length sampling for hit rows, even with a different point count.
	actor.body_override=PackedVector2Array([Vector2.ZERO,Vector2(80,0),Vector2(80,500),Vector2(900,500)])
	actor.table.pos[actor.body]=Vector2.ZERO
	actor._update_body()
	for j in actor.body_rows.size():
		var fraction:=float(j+1)/float(actor.body_rows.size())
		check(actor.table.pos[actor.body_rows[j]].distance_to(FORM.sample(actor.body_points(),fraction))<0.001,"override topology cannot desynchronize damage samples")
	actor.cancel_attack()
	check(actor.body_override.is_empty() and actor.telegraph_paths.is_empty(),"cancellation clears pose and pending tell geometry")
	# Boss aim is direct, independent of the ordinary-enemy trailing aim.
	sim.state.ship_pos=Vector2(600,320);sim.state.enemy_aim=Vector2(-900,-400)
	sim.state.ship_vel=Vector2(300,0)
	check(actor.aim_target()==sim.state.ship_pos,"boss direct aim must not inherit trailing enemy aim")
	check(actor.aim_target(0.5)==Vector2(750,320),"bounded lead uses actual craft motion")
	# The smallest authored friendly projectile (interceptor radius4) must hit through the final tail midpoint.
	actor.cancel_attack();actor.table.guard[actor.body]=0.0
	actor.table.pos[actor.body]=Vector2.ZERO;actor.table.facing[actor.body]=0.0;actor._update_body()
	sim.field.bodies.clear();sim.combat.rebuild_grid();sim.state.stats.crit_chance=0.0
	var last_row: int=actor.body_rows[-1]
	var before_row: int=actor.body_rows[-2]
	var middle: Vector2=(actor.table.pos[last_row]+actor.table.pos[before_row])*0.5
	var normal: Vector2=(actor.table.pos[last_row]-actor.table.pos[before_row]).normalized().orthogonal()
	var before_hp: float=actor.table.hp[actor.body]
	sim.projectiles.fire_shot(middle-normal*90.0,normal.angle(),50.0,{"r":4.0,"speed":450.0,"life":2.0})
	sim.projectiles._update_friendly(0.4)
	check(actor.table.hp[actor.body]<before_hp,"actual radius4 friendly projectile must hit final tail midpoint through the production broad phase")
	# Swept capsules include the previous segment and moving endpoint edges, not only the hull interior.
	sim.ship.invincible=false
	sim.state.encounter_protected=false
	actor.technique=&"bite";actor.mode=&"active"
	var prior:=PackedVector2Array([Vector2(0,0),Vector2(0,100)])
	var current:=PackedVector2Array([Vector2(100,0),Vector2(100,100)])
	for test in [{"at":Vector2(-20,50),"hit":true},{"at":Vector2(50,-20),"hit":true},{"at":Vector2(50,-50),"hit":false}]:
		sim.state.ship_pos=test.at;sim.state.ship_invuln=0.0;actor.attack_hit=false
		var hp: float=sim.state.ship_hp
		actor.hit_segment(current,10.0,prior)
		check((sim.state.ship_hp<hp)==bool(test.hit),"swept attack must include radius around prior and connecting edges, and reject clear positions")
	session.free()
	print("[draco_body_basis] failures=",failures)
	get_tree().quit(1 if failures else 0)
