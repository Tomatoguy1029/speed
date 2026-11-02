extends Node
var failed:=0
func check(ok: bool,label: String)->void:
	print("[hydra-collision] ","PASS " if ok else "FAIL ",label)
	if not ok:failed+=1
func _ready()->void:
	var lab=load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[-200,0]})
	lab.run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a=lab.run.bosses.actors.back()
	var field=a.attack_field
	lab.run.ship.invincible=false
	var hp: float=lab.run.state.ship_hp
	field.add_shape(PackedVector2Array([Vector2(0,-100),Vector2(0,100)]),20.0,0.5,1.0,10.0,&"beam")
	field.ship_previous=Vector2(-200,0)
	lab.run.state.ship_pos=Vector2(200,0)
	field.tick(0.1)
	check(lab.run.state.ship_hp==hp,"warning has no damage even when crossed")
	lab.run.state.ship_invuln=0.0
	lab.run.state.ship_pos=Vector2(-200,0)
	field.tick(0.5)
	check(lab.run.state.ship_hp<hp,"active line catches a fast full-frame crossing")
	field.clear_effects()
	lab.run.state.ship_invuln=0.0
	hp=lab.run.state.ship_hp
	field.ship_previous=Vector2(-200,300)
	lab.run.state.ship_pos=Vector2(200,300)
	field.add_shape(PackedVector2Array([Vector2(0,-100),Vector2(0,100)]),20.0,0.0,1.0,10.0,&"beam")
	field.tick(0.1)
	check(lab.run.state.ship_hp==hp,"finite beam endpoints leave the advertised safe gap")
	field.clear_effects()
	field.ship_previous=Vector2.ZERO
	lab.run.state.ship_pos=Vector2.ZERO
	field.add_shape(PackedVector2Array([Vector2(-200,0),Vector2(-170,0)]),20.0,0.0,1.0,10.0,&"bolt",-1,Vector2(4000,0))
	field.tick(0.1)
	check(lab.run.state.ship_hp<hp,"moving rod sweeps its full flight between frames")
	field.clear_effects()
	lab.run.state.ship_invuln=0.0
	hp=lab.run.state.ship_hp
	field.ship_previous=Vector2.ZERO
	lab.run.state.ship_pos=Vector2.ZERO
	var moving: Dictionary=field.add_shape(PackedVector2Array([Vector2(-100,-100),Vector2(-100,100)]),20.0,0.0,1.0,10.0,&"beam")
	field.tick(0.01)
	moving.points=PackedVector2Array([Vector2(100,-100),Vector2(100,100)])
	field.tick(0.01)
	check(lab.run.state.ship_hp<hp,"moving beam sweeps its interior between old and new polylines")
	field.clear_effects()
	var radius: float=a.table.r[a.body]
	var replacement:=Shader.new()
	replacement.code="shader_type canvas_item; void fragment(){ COLOR=vec4(0.2,1.0,0.3,1.0); }"
	a.energy_shader=replacement
	a.body_texture=field.white
	a.neck_texture=field.white
	a.compass_texture=field.white
	var expected:=PackedVector2Array([Vector2(500,500),Vector2(800,500)])
	var swapped: Dictionary=field.add_shape(expected,40.0,0.5,1.0,10.0,&"beam")
	check(field.visuals[swapped.id].material.shader==replacement and swapped.points==expected and is_equal_approx(swapped.width,40.0),"artist shader swap preserves shared collision geometry")
	check(a.table.r[a.body]==radius,"artwork textures preserve body collision radius")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
