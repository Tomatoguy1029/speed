extends Node
var failures := 0
var session: RunSession
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func fresh() -> RunSimulation:
	if session != null: session.free()
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled = false
	session = RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":5405,"hud":false},false)
	session.auto_step = false
	var sim := session.sim
	sim.state.phase = RunState.Phase.PLAY
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	sim.bosses.actor.selection_enabled = false
	sim.enemies.table.guard[sim.bosses.actor.body] = 0.0
	return sim
func white(actor: BossActor, id := -1) -> float:
	return float(actor.hit_feedback.sample(actor.body_id if id < 0 else id).white)
func _ready() -> void:
	var sim := fresh()
	var actor = sim.bosses.actor
	var before: Vector2 = actor.table.pos[actor.body]
	var facing: float = actor.table.facing[actor.body]
	sim.combat.damage_enemy(actor.body_rows[5],10.0,{"cause":&"shot"})
	check(white(actor)>0.0,"Actual damage through a body segment flashes its owner")
	check(actor.table.pos[actor.body]==before and actor.table.facing[actor.body]==facing,"Damage feedback cannot move or rotate physics")
	check(actor.mode==&"idle","Damage feedback does not start or cancel an attack")
	actor.start_attack(&"bite")
	var active_mode: StringName=actor.mode
	before=actor.table.pos[actor.body];facing=actor.table.facing[actor.body]
	sim.combat.damage_enemy(actor.body,10.0,{"cause":&"shot"})
	check(actor.mode==active_mode and actor.technique==&"bite","A non-threshold hit preserves an attack already in progress")
	check(actor.table.pos[actor.body]==before and actor.table.facing[actor.body]==facing,"Visual reaction cannot perturb active attack origin or aim")
	actor.cancel_attack()
	var material_a: ShaderMaterial = actor.hit_feedback.make_material()
	var material_b: ShaderMaterial = actor.hit_feedback.make_material()
	check(material_a!=material_b,"Each renderer owns an independent feedback material")
	material_a.set_shader_parameter("boss_hit_white",0.25)
	check(float(material_b.get_shader_parameter("boss_hit_white"))==0.0,"One body's flash cannot leak through a shared material")
	for frame in 120:
		sim.combat.damage_enemy(actor.body,0.01,{"cause":&"shot"})
		actor.hit_feedback.tick(1.0/240.0)
		var sample: Dictionary = actor.hit_feedback.sample(actor.body_id)
		check(sample.white<=0.28 and sample.offset.length()<=2.5 and absf(sample.angle)<=0.0035,"Rapid hits refresh a bounded pulse without additive shake")
	actor.hit_feedback.tick(0.13)
	check(white(actor)==0.0 and actor.hit_feedback.sample(actor.body_id).offset==Vector2.ZERO,"Pulse returns exactly to neutral without new hits")
	for blocked in ["zero","negative","guard","locked","protected","paused"]:
		sim = fresh(); actor = sim.bosses.actor
		if blocked=="guard": actor.table.guard[actor.body]=1.0
		if blocked=="locked": sim.state.controls_locked=true
		if blocked=="protected": sim.state.encounter_protected=true
		if blocked=="paused": sim.state.phase=RunState.Phase.PAUSED
		var hp: float = actor.table.hp[actor.body]
		sim.combat.damage_enemy(actor.body,0.0 if blocked=="zero" else -5.0 if blocked=="negative" else 10.0,{"cause":&"shot"})
		check(actor.table.hp[actor.body]==hp and white(actor)==0.0,"Blocked or zero damage has no feedback: "+blocked)
	sim=fresh(); actor=sim.bosses.actor
	actor.table.hp[actor.body]=actor.table.max_hp[actor.body]*0.7
	sim.combat.damage_enemy(actor.body,100.0,{"cause":&"shot"})
	check(white(actor)==0.0,"Discarded threshold excess with no final HP decrease cannot flash")
	sim=fresh(); actor=sim.bosses.actor
	actor.table.hp[actor.body]=actor.table.max_hp[actor.body]*0.8
	sim.combat.damage_enemy(actor.body,actor.table.max_hp[actor.body],{"cause":&"shot"})
	check(actor.phase==2 and white(actor)>0.0,"Real decrease up to a phase threshold flashes despite discarded excess")
	sim=fresh(); actor=sim.bosses.actor
	actor.phase=2
	actor.start_attack(&"clones")
	var unit: Dictionary = actor._driver.units[1]
	var part: int = unit.parts[0].row
	check(is_equal_approx(actor.table.max_hp[unit.row],float(actor.rule().clone_hp)*sim.cfg.enemy_hp_mult),"Independent copy must use its authored HP instead of the ordinary rank1 table")
	sim.combat.damage_enemy(part,10.0,{"cause":&"shot"})
	check(white(actor,unit.id)>0.0 and white(actor)==0.0,"An independent whole-body copy flashes without lighting the main boss")
	check(actor.table.dead[unit.row]==0,"A small actual hit leaves the authored durable copy visible for its feedback")
	sim.state.cinematic_hide_enemies=true
	unit.visual._process(0.0)
	check(not unit.visual.visible,"A retained whole-body copy obeys cinematic enemy visibility")
	sim.state.cinematic_hide_enemies=false
	unit.visual._process(0.0)
	check(unit.visual.visible,"Leaving a cinematic restores a living whole-body copy")
	actor.cancel_attack()
	actor.hit_feedback.tick(0.13)
	check(actor.hit_feedback.remaining.is_empty(),"Disposed copy feedback expires without retained rows")
	sim=fresh();actor=sim.bosses.actor
	actor.phase=3;actor.table.hp[actor.body]=10.0
	sim.combat.damage_enemy(actor.body,20.0,{"cause":&"shot"})
	check(actor.mode==&"finale" and white(actor)>0.0,"Fatal real damage starts a pulse before the actual finale")
	sim.input_source=func(): return Intent.new()
	for frame in 10:
		sim._play_tick(0.02)
		session._process(0.02)
	check(white(actor)==0.0,"Finale early return cannot freeze the damage flash or shake")
	sim=fresh();actor=sim.bosses.actor
	sim.combat.damage_enemy(actor.body,10.0,{"cause":&"shot"})
	sim.state.hitstop=0.3
	sim.input_source=func(): return Intent.new()
	for frame in 10:
		sim._play_tick(0.02)
		session._process(0.02)
	check(white(actor)==0.0,"Hitstop early return cannot freeze the visual pulse")
	sim.combat.damage_enemy(actor.body,10.0,{"cause":&"shot"})
	check(white(actor)>0.0,"Cleanup fixture has a live feedback pulse")
	sim.bosses.remove_actor(actor)
	check(actor.hit_feedback.remaining.is_empty(),"Removing an actor clears all feedback before row reuse")
	session.free()
	print("[boss_hit_feedback] failures=",failures)
	get_tree().quit(1 if failures>0 else 0)
