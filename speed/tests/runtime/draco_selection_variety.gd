extends Node
var failures := 0
var evidence: Array = []
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func _ready() -> void:
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	for phase in [1,2,3]:
		for situation in [{"name":"near_front","pos":Vector2(100,0)},{"name":"mid_front","pos":Vector2(650,0)},{"name":"far_front","pos":Vector2(1300,0)},{"name":"offscreen","pos":Vector2(2200,0)},{"name":"rear","pos":Vector2(-650,0)}]:
			var session := RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":9100+phase,"hud":false},false)
			session.auto_step=false
			var sim := session.sim
			sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
			var actor = sim.bosses.actor
			actor.phase=phase;actor.selection_enabled=false
			# This fixture controls choice boundaries, without replaying already tested attack motions.
			sim.projectiles.director=null
			var choices: Array = []
			var candidate_rows: Array = []
			for frame in 1600:
				actor.table.pos[actor.body]=Vector2.ZERO
				actor.table.facing[actor.body]=0.0
				sim.state.ship_pos=situation.pos
				sim.state.enemy_aim=Vector2(-9000,9000)
				var candidates: Array = actor.flow_adapter.candidates({"request":"any"}).candidates
				actor.flow_runner.tick(0.1,{"player":sim.state.ship_pos},actor.flow_adapter)
				if actor.technique!=&"":
					var id := String(actor.technique)
					var available := candidates.map(func(c): return String(c.id))
					check(id in available,"Selection must respect actual distance/facing/phase candidates")
					choices.append(id)
					candidate_rows.append({"eligible":candidates,"stamina_after":actor.flow_runner.stamina,"selected":id})
					actor.cancel_attack()
					sim.enemies.cleanup()
				if choices.size()>=24: break
			var unique := {}
			var repeats := 0
			for j in choices.size():
				unique[choices[j]]=true
				if j>0 and choices[j]==choices[j-1]: repeats+=1
			check(choices.size()==24 and unique.size()>=3,"A rich situational pool must produce varied techniques: phase%d %s"%[phase,situation.name])
			check(repeats==0,"Distinct eligible alternatives prevent immediate repeats, including after rest")
			var eligible: Array = candidate_rows[0].eligible.map(func(c): return String(c.id))
			check(("inhale" in eligible)==(phase==3),"Absorption remains final-phase only")
			if phase==1: check("clones" not in eligible and "picaro_wall" not in eligible,"Middle-phase moves cannot leak into phase1")
			if situation.name=="rear": check("tail_sweep" in eligible and "star_fan" not in eligible and "breath" not in eligible,"Rear sensor chooses rear moves instead of forward cone moves")
			if situation.name=="offscreen": check("bite" not in eligible and "tail_slam" not in eligible,"Close-range attacks remain excluded at long distance")
			evidence.append({"phase":phase,"situation":situation.name,"choices":choices,"unique":unique.keys(),"repeats":repeats,"candidate_snapshots":candidate_rows})
			session.free()
	var file := FileAccess.open("/tmp/draco-qa-evidence/feedback-variety/draco-selection.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"scenarios":evidence},"\t"))
	print("[draco_selection_variety] scenarios=",evidence.size()," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)
