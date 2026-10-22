## 本番の線入力と戦闘更新で、一戦と共通の勝利入口を確認する。
extends Node
var failed:=0
func check(ok: bool,label: String)->void:
	print("[hydra-battle] ","PASS " if ok else "FAIL ",label)
	if not ok:failed+=1
func line(run: RunManager,points: PackedVector2Array)->void:
	run.state.gauge=1.0
	run.state.ship_pos=points[0]
	run.state.ship_vel=Vector2.ZERO
	run.state.glide=false
	var it:=Intent.new()
	it.press=true
	it.pen=points[0]
	run.draw.intent=it
	run.draw.handle_input()
	for j in range(1,points.size()):
		it=Intent.new()
		it.pen=points[j]
		it.has_cursor=true
		run.draw.intent=it
		run.draw.handle_input()
	it.press=true
	run.draw._first_point_msec-=ceili(run.cfg.draw_confirm_delay*1000.0)
	run.draw.handle_input()
func _ready()->void:
	var saved:=JSON.stringify(SaveManager.data)
	var lab=load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"stage":4,"ship_pos":[400,0],"invincible":true,"config":{"base_attack":5000.0}})
	lab.run.bosses.spawn_lab(&"hydra",Vector2.ZERO)
	var a=lab.run.bosses.lab_instances.back().actor
	var counts: Dictionary={3:true}
	var split_seen:=false
	for attempt in 18:
		if not a.manager.has_boss():break
		var at: Vector2=a.table.pos[a.immortal_row] if a.separated else a.table.pos[a.body]
		line(lab.run,PackedVector2Array([at-Vector2(160,0),at+Vector2(160,0)]))
		for frame in 100:
			lab.step()
			if not a.manager.has_boss():break
			counts[a.count]=true
			split_seen=split_seen or a.separated
	check(counts.has(5) and counts.has(8),"line attacks traverse both HP growth thresholds")
	check(split_seen,"line attacks destroy core and enter separation")
	check(not lab.run.bosses.lab_instances.back().has_boss(),"line attack defeats compass bearer and ends lab encounter")
	check(JSON.stringify(SaveManager.data)==saved,"full lab battle leaves save data untouched")
	await lab.reset({"empty":true,"stage":4})
	lab.run.state.lab_mode=false
	lab.run.bosses.spawn(ConfigManager.bosses[&"hydra"],Vector2.ZERO)
	a=lab.run.bosses.actor
	a.hsm.set_active(false)
	a._set_count(8)
	a.begin_separation()
	a.separation_t=0.0
	a.table.guard[a.immortal_row]=0.0
	lab.run.combat.damage_enemy(a.immortal_row,100000.0,{"cause":&"weapon"})
	lab.run.enemies.cleanup()
	a.sim_tick(0.01,0.01)
	check(lab.run.state.boss_dead,"campaign bearer defeat raises final victory")
	lab.run._begin_finish()
	check(lab.run.state.phase==RunState.Phase.FINISHING and lab.run.finish_legendary()!=null,"final victory enters common finish with stage legendary module")
	lab.run._finish_blast()
	check(not lab.run.bosses.has_boss(),"common final blast cleans remaining encounter")
	check(JSON.stringify(SaveManager.data)==saved,"finish preview does not grant or persist duplicate rewards")
	lab.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
