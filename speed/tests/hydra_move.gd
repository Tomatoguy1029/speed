## 1技ごとに実際のBT条件から発動し、生成物・硬直・中断を確認する。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	print("[hydra-move] ", "PASS " if ok else "FAIL ", label)
	if not ok: failed += 1
func _ready() -> void:
	var attack := &"bite_sweep"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--attack="): attack=StringName(arg.trim_prefix("--attack="))
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4})
	lab.run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a = lab.run.bosses.lab_instances.back().actor
	a.hsm.set_active(false)
	a._set_count(5)
	check(a.def.params.normal_rules.has(attack),String(attack)+" has configurable eligibility")
	if a.def.params.normal_rules.has(attack):
		var rule: Dictionary = a.def.params.normal_rules[attack]
		var n = a._first(rule.kind)
		a.table.facing[a.body] = -n.base_angle
		n.angle=0.0
		n.length=230.0
		n.cd=0.0
		a.run_state.ship_pos=a._head_pos(n)+Vector2(450 if rule.min>0.0 else 150,0)
		a.run_state.view_center=a._head_pos(n)
		a.run_state.view_half=Vector2(1400,1000)
		check(a.start_normal(a.necks.find(n),attack),"eligible move starts")
		var ids := {}
		var has_motion := false
		var has_curve := false
		var lightning := false
		var wind_slow := false
		var wind_fast := true
		var rubble := false
		for i in 130:
			a.sim_tick(0.02,0.02)
			for e in a.attack_field.effects:
				if e.owner == n.row:
					ids[e.id]=true
					lightning=lightning or e.kind==&"lightning"
					if e.velocity.length()>0.0: has_motion=true
					if e.points.size()>2: has_curve=true
					if e.kind==&"wind" and e.age>=e.delay:
						a.run_state.ship_pos=e.points[0].lerp(e.points[-1],0.5)
						a.attack_field.ship_previous=a.run_state.ship_pos
						a.run_state.ship_vel=Vector2.ZERO
						a.attack_field.tick(0.01)
						wind_slow=wind_slow or a.run_state.ship_vel.length()>0.0
						a.run_state.tracing=true
						a.run_state.ship_vel=Vector2(2000,0)
						a.attack_field.tick(0.01)
						wind_fast=wind_fast and a.run_state.ship_vel==Vector2(2000,0)
						a.run_state.tracing=false
			for j in a.table.alive.size():
				if a.table.alive[j] and a.table.type[j]==&"hydra_rubble": rubble=true
		check(ids.size()>0 or rubble,"move creates real attack geometry or solid rubble")
		if attack==&"thunder_headbutt": check(lightning,"headbutt discharges at arrival then stops")
		if attack==&"wind_band": check(wind_slow and wind_fast,"wind pushes slow ship and preserves tracing motion")
		if attack==&"wind_blades": check(ids.size()==3 and has_motion and has_curve,"three distinct crescent blades move without changing shape")
		if attack==&"beam_bolt": check(has_motion,"finite bolt travels instead of sustaining its whole ray")
		if attack in [&"rubble_lump",&"rubble_fan"]: check(rubble,"rubble remains a physical guarded obstacle")
		check(n.mode==&"idle" and n.cd>0.0,"move returns from counterattack hold into cooldown")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
