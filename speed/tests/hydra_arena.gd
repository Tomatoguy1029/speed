extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	print("[hydra-arena] ", "PASS " if ok else "FAIL ", label)
	if not ok: failed += 1
func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[400,0]})
	lab.run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a = lab.run.bosses.lab_instances.back().actor
	a.hsm.set_active(false)
	var arena = a.get("arena")
	check(arena != null,"encounter creates fixed rubble arena immediately")
	if arena != null:
		var bounds: Rect2 = arena.bounds
		var center := bounds.get_center()
		var field: FieldSystem = lab.run.field
		var r: float = lab.run.cfg.ship_radius
		check(field.boundary_accel(Vector2(lab.run.cfg.field_radius+100.0,0))==Vector2.ZERO,"encounter boundary replaces distant world-edge force")
		for dir in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized()]:
			var hit = field.first_body_hit(center,center+dir*10000.0,r)
			check(hit != null and bounds.grow(-r+0.1).has_point(hit.point),"swept boundary blocks " + str(dir))
		lab.run.state.ship_pos=center+Vector2(bounds.size.x,0)
		lab.run.state.ship_vel=Vector2(10000,0)
		check(lab.run.combat.wall_bounce(center) and lab.run.state.ship_vel.x<0.0,"high speed travel bounces inside fixed wall")
		var body := FieldSystem.Body.new()
		body.pos=Vector2(bounds.end.x-80.0,center.y)
		body.r=120.0
		field.bodies.append(body)
		lab.run.state.ship_pos=Vector2(bounds.end.x-40.0,center.y)
		lab.run.ship._collide_bodies()
		check(bounds.grow(-r+0.1).has_point(lab.run.state.ship_pos),"terrain correction cannot push ship outside barricade")
		field.bodies.erase(body)
		lab.run.state.ship_pos=center
		lab.run.state.drawing=true
		lab.run.state.draw_points=PackedVector2Array([center])
		lab.run.state.draw_limit=20000.0
		lab.run.state.draw_length=0.0
		lab.run.draw._extend(center+Vector2(10000,0))
		check(lab.run.state.draw_blocked and bounds.grow(-r).has_point(lab.run.state.draw_points[-1]),"drawn route stops at rubble boundary")
		var outside := bounds.end+Vector2(500,500)
		check(field.arena_hit(outside,outside-Vector2(10,10),r).point==outside,"outside objects are not teleported through rubble")
		lab.run.state.drawing=false
		a._set_count(8)
		a.begin_separation()
		a.separation_t=0.0
		for n in a.necks:n.cd=1e6
		lab.run.state.ship_pos=bounds.end-Vector2(80,80)
		for step in 300:a.sim_tick(0.025,0.025)
		check(arena.bounds==bounds,"rubble remains fixed across movement and separation")
		check(bounds.grow(-20).has_point(a.immortal_neck.free_pos),"compass bearer stays inside arena")
		check(a.necks.all(func(n):return bounds.has_point(a._head_pos(n)) and Array(n.segs).all(func(p):return bounds.has_point(p))),"guards and their bodies stay inside arena")
		a.interrupt_tech()
		a._tech_cd=0.0
		check(a.try_start_tech(&"swarm",1.0),"separated lunge can start near boundary")
		check(a.special.state.slots.all(func(p):return bounds.grow(-r).has_point(p)),"formation slots stay inside arena")
		a.interrupt_tech()
		lab.run.state.ship_pos=bounds.end-Vector2(260,260)
		lab.run.state.view_center=lab.run.state.ship_pos
		var plan: Dictionary=a.grid_plan()
		check(not plan.is_empty(),"grid finds inward route at arena corner")
		if not plan.is_empty():
			check(Array(plan.path).all(func(p):return bounds.grow(-r).has_point(p)),"grid path remains inside arena")
			a.recovery_t=0.0
			a._tech_cd=0.0
			check(a.try_start_tech(&"grid",1.0),"grid starts with bounded layout")
			for step in 500:
				a.sim_tick(0.025,0.025)
				if not a.busy or not a.special.positioning:break
			check(a.tech==&"grid" and not a.special.positioning,"guards and bearer actually reach bounded grid formation")
		a.manager.remove_boss()
		await get_tree().process_frame
		check(field.first_body_hit(center,center+Vector2(10000,0),r)==null,"removing encounter releases boundary collision")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
