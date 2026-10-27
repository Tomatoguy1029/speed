## 共通フローを止めず、登場からHP三段階・決着まで進む結合確認。
extends Node
const DT := 1.0/60.0
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)
func _ready() -> void:
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled = false
	var session := RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":84205,"hud":false},false)
	session.auto_step = false
	var sim := session.sim
	sim.field.bodies.clear()
	sim.field.rocks.clear()
	sim.state.ship_hp = 100000.0
	sim.state.ship_vel = Vector2.ZERO
	sim.state.ship_pos = Vector2(300,0)
	sim.state.phase = RunState.Phase.PLAY
	sim.state.camera_zoom = 720.0/1100.0
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var actor = sim.bosses.actor
	actor.selection_enabled = true
	actor.entrance.begin()
	var previous: StringName = &""
	var selections: Array = []
	var phase_times := [0.0,0.0,0.0]
	for frame in 18000:
		var s := sim.state
		s.sim_time += DT
		s.world_time += DT
		s.time += DT
		phase_times[actor.phase-1] += DT
		var velocity := Vector2.from_angle(s.sim_time*0.17)*500.0 if not s.controls_locked else Vector2.ZERO
		s.ship_vel = velocity
		s.ship_pos += velocity*DT
		s.ship_invuln = maxf(0.0,s.ship_invuln-DT)
		if sim.projectiles.director != null:
			sim.projectiles.director.advance(s.world_time,sim.enemies)
		sim.enemies.tick(DT,DT)
		sim.bosses.tick(DT,DT)
		sim.combat.rebuild_grid()
		sim.projectiles.tick(DT,DT)
		sim.enemies.cleanup()
		sim._update_camera(DT)
		if actor.technique != previous:
			previous = actor.technique
			if previous != &"":
				selections.append({"t":s.sim_time,"phase":actor.phase,"move":previous})
				check(actor.phase>=2 or previous not in [&"clones",&"picaro_wall"],"序盤へ中盤専用技が漏れない")
				check(actor.phase>=3 or previous!=&"inhale","終盤まで吸引を選ばない")
		var duration := 45.0 if actor.phase==1 else 65.0
		if phase_times[actor.phase-1] >= duration and sim.enemies.table.guard[actor.body] == 0.0:
			sim.combat.damage_enemy(actor.body,1000000.0,{"cause":&"shot"})
			if actor.mode==&"finale": break
	check(actor.phase==3 and actor.mode==&"finale","共通フローの戦闘が三段階を順に通って決着へ渡る")
	check(selections.size()>=12,"選択と休息を繰り返して一戦を進める")
	for frame in 2400:
		var intent := Intent.new()
		if actor.finale.stage==&"input":
			intent.press=not actor.finale.began
			intent.has_cursor=true
			intent.pen=sim.state.ship_pos+Vector2(50,0)
			intent.pen_release=actor.finale.began
		actor.advance_finale(DT,intent)
		if actor.finale.completed: break
	check(actor.finale.completed and sim.state.draco_finish_done,"決着入力から完了までつながる")
	check(not sim.state.controls_locked and not sim.state.cinematic_camera and sim.state.world_scale>0.0,"決着後の操作・世界・カメラ所有を解放する")
	var output := FileAccess.open("/tmp/draco-qa-evidence/final-flow-selections.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"selections":selections,"phase_seconds":phase_times,"failures":failures},"\t"))
	output.close()
	session.free()
	print("[draco_flow_encounter] choices=",selections.size()," failures=",failures)
	get_tree().quit(1 if failures else 0)
