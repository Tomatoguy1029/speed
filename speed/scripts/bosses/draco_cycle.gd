## 初回の星採集と、通常のピカロ担当・帰還・再生成。
extends RefCounted
var actor: BossActor
var first := false
var time := 0.0
var stage: StringName = &""
var home := Vector2.ZERO
var generated := 0
var next_cycle := 12.0
func _init(a: BossActor) -> void: actor = a
func begin_initial() -> void:
	first = true
	stage = &"roar"
	time = 0.0
	generated = 0
	home = actor.table.pos[actor.body]
	actor.run_state.controls_locked = true
	actor.run_state.cinematic_bars = 1.0
	actor.run_state.drawing = false
	actor.run_state.tracing = false
func begin_deep() -> void:
	stage = &"collect"
	time = 0.0
	home = actor.run_state.ship_pos+Vector2(500,-100)
	actor.mode = &"deep"
	actor.table.guard[actor.body] = 1.0
	actor.picaro.attacking = true
func tick(dt: float) -> bool:
	var a = actor
	if stage == &"":
		if not a.selection_enabled or a.phase<2: return false
		if a.mode == &"idle":
			next_cycle -= dt
			if next_cycle<=0.0: begin_deep()
		return false
	time += dt
	match stage:
		&"roar":
			if time>=1.0: stage=&"collect"; time=0.0
		&"collect":
			a._presentation.scale = Vector2.ONE*lerpf(1.0,0.25,clampf(time,0.0,1.0))
			a._presentation.modulate.a = 0.35
			a.table.guard[a.body] = 1.0
			if time >= (2.0 if first else float(a.def.params.get("collect_time",12.0))) or (not first and a.picaro.alive().is_empty() and time>1.0):
				a.picaro.pause(false)
				stage=&"wait_beams"; time=0.0
		&"wait_beams":
			var busy := false
			for m: Dictionary in a.picaro.alive():
				for h in a.ctx.projectiles.hazard_alive.size():
					if a.ctx.projectiles.owns_hazard(h,m.row,m.id): busy=true
			if not busy: stage=&"return"; time=0.0
		&"return":
			a.table.pos[a.body] = a.table.pos[a.body].lerp(home,minf(1.0,dt*4.0))
			a._presentation.scale = Vector2.ONE*lerpf(0.25,1.0,clampf(time,0.0,1.0))
			a._presentation.modulate.a = lerpf(0.35,1.0,clampf(time,0.0,1.0))
			if time>=1.0:
				a.table.guard[a.body]=0.0
				stage=&"generate";time=0.0;generated=0
		&"generate":
			var count := int(a.def.params.get("picaro_count",3))
			if time >= 0.6+float(generated)*0.8 and generated<count:
				var choices: Array = a.def.params.get("picaro_candidates",[])
				if choices.is_empty():
					for id in ContentManager.catalog.table(&"enemies"):
						var source: EnemyDef = a.ctx.enemies.def_of(id)
						if source != null and source.rank>0 and source.gate not in [&"solid",&"immortal"]: choices.append(id)
				if choices.is_empty(): choices=[&"biter"]
				var type := StringName(choices[a.run_state.rng.randi_range(0,choices.size()-1)])
				if not type in a.def.params.get("picaro_excluded",[]): a.picaro.spawn_picaro(type,home+Vector2(150,(generated-1)*180.0))
				generated+=1
			if time>0.6+count*0.8+1.0:
				first=false;stage=&"";next_cycle=10.0
				a.run_state.controls_locked=false;a.run_state.cinematic_bars=0.0
				a.mode=&"idle";a.elapsed=0.0;a.table.guard[a.body]=0.0
				a.picaro.attacking=false
	return stage != &""
func cancel() -> void:
	stage=&"";first=false;time=0.0;next_cycle=10.0
	actor.run_state.controls_locked=false;actor.run_state.cinematic_bars=0.0
	actor._presentation.scale=Vector2.ONE;actor._presentation.modulate=Color.WHITE
