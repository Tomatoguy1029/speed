extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	if "--cpp-draco-bite" in OS.get_cmdline_user_args() or "--cpp-draco-bite-hit" in OS.get_cmdline_user_args() or "--cpp-draco-bite-events" in OS.get_cmdline_user_args():
		call_deferred("native_bite")
		return
	call_deferred("native_bite")

func native_bite() -> void:
	var strict:="--semantics-strict" in OS.get_cmdline_user_args()
	var event_only := "--cpp-draco-bite-events" in OS.get_cmdline_user_args()
	var hit_only := "--cpp-draco-bite-hit" in OS.get_cmdline_user_args() or event_only
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	var definition: BossDef = load("res://data/bosses/draco.tres")
	var move: BossTechnique = load("res://data/bosses/draco_moves/bite.tres")
	var package: Dictionary = builder.draco_technique_package(definition,move,cfg)
	check(package.records.BossTechniqueDefinition.size()==3 and package.records.BossTechniqueDefinition[2].phase==3,"Sourceと同じ3形態の噛みつき値を生成する")
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled = false
	var session
	if strict:
		session=load("res://tests/draco.gd").SemanticsSession.new();session.sim=RunSimulation.new();session.sim.actor_parent=self;session.sim.options={"lab":true,"stage":stage,"stage_index":5,"seed":709,"empty":true};session.sim.setup();add_child(session)
	else:session=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":709},false)
	session.auto_step = false
	var sim: RunSimulation = session.sim
	sim.field.bodies.clear();sim.state.phase=RunIds.Phase.Play;sim.ship.invincible=false
	sim.bosses.spawn(definition,Vector2.ZERO)
	var a = sim.bosses.actor
	a.selection_enabled=false
	for angle in [0.0,PI*0.5,PI,PI*0.25]:
		var ship := Vector2.from_angle(angle)*300.0
		a.cancel_attack();a.cycle.cancel();a.clock=0.0;a.table.pos[a.body]=Vector2.ZERO;a.table.facing[a.body]=angle;a.reset_pose()
		sim.state.ship_pos=ship;sim.state.enemy_aim=Vector2(-900,-900);sim.state.ship_vel=Vector2.ZERO;sim.state.ship_invuln=0.0
		var bridge = load("res://scripts/runtime/run_bridge.gd").new()
		var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":193,"mode":1,"stage_id":"B_draco_bite","profile":{},"settings":{"hitstop":false}})
		check(configured.ok,"噛みつきの型付き定義をC++が読む")
		if not configured.ok: print(configured);get_tree().quit(1);return
		bridge.start(709,{"position":ship,"lab_mode":true})
		var captured: Array = []
		bridge.subscribe("確認",func(frame):captured.append_array(frame.events);return true)
		bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":ship,"invincible":false}})
		bridge._core.set_motion_context(ship,ship,Vector2(800,450))
		var boss: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
		var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":boss,"definition":1})
		check(started.ok and a.start_attack(&"bite"),"SourceとC++の噛みつきを四方向で開始する")
		if hit_only:
			for frame in 250:
				bridge._core.step(1.0/120.0)
				bridge.command("dev_boss_state")
			if not event_only: check(bridge.command("dev_boss_state").value[0].hit,"無敵を切った四方向の対象へ1回命中する")
			var events: Array = captured+bridge.read_frame().value.events
			check(events.any(func(event):return event.type==&"combat_player_damage" and event.payload.cause==&"bite" and event.payload.source==&"draco" and event.payload.technique==&"bite"),"原因・出所・技名を保持する")
			bridge.dispose()
			continue
		var max_position_error := 0.0
		var max_shape_error := 0.0
		var stage_equal := true
		var rendered := false
		for frame in 250:
			a.sim_tick(1.0/120.0,1.0/120.0);bridge._core.step(1.0/120.0)
			var body: Dictionary = bridge.command("dev_boss_body_state").value[-1]
			var attack: Dictionary = bridge.command("dev_boss_state").value[0]
			max_position_error=maxf(max_position_error,body.position.distance_to(a.table.pos[a.body]))
			var expected: int = {&"windup":0,&"active":1,&"recovery":2,&"idle":5}[a.mode]
			stage_equal = stage_equal and attack.stage==expected
			var source_points: PackedVector2Array = a.body_points()
			for j in source_points.size(): max_shape_error=maxf(max_shape_error,source_points[j].distance_to(body.body_points[j]))
			if not strict and frame==40:
				var held: Dictionary = bridge.checkpoint()
				check(held.ok,"予告途中の首姿勢と固定照準を保持する")
				bridge._core.step(1.0/120.0)
				var future: Array = bridge.command("dev_boss_state").value
				check(bridge.restore(held.value).ok,"予告途中へ復帰する")
				bridge._core.step(1.0/120.0)
				check(bridge.command("dev_boss_state").value==future,"復帰後も同じ首姿勢・段階・照準で進む")
				bridge.restore(held.value);bridge.release_checkpoint(held.value)
			if not strict and frame==100:
				var display = load("res://scripts/render/bosses/draco.gd").new()
				add_child(display)
				display.apply_frame(body,attack,package.visuals[-1].appearance)
				display.queue_redraw();await get_tree().process_frame
				rendered=display._parts.visible and attack.attack_points.size()==2 and attack.mouth_open==1.0
				display.free()
		check(stage_equal,"Sourceの予告→実行→回復→待機と開始・終了tickが一致する")
		check(max_position_error<=(1e-4 if strict else 0.1) and max_shape_error<=(1e-4 if strict else 0.1),"Sourceの首と全身の判定点列が一致する: %s/%s"%[max_position_error,max_shape_error])
		if strict:
			print("SEMANTICS_DRACO_BITE ",angle," errors=",[max_position_error,max_shape_error]," failures=",failures);bridge.dispose();continue
		check(rendered,"予告と同じ技状態から体と口の攻撃軌跡を描画する")
		var attack: Dictionary = bridge.command("dev_boss_state").value[0]
		check(attack.stage==5 and attack.hit,"四方向の静止対象に1回命中して自然終了する")
		var events: Array = captured+bridge.read_frame().value.events
		check(events.any(func(event):return event.type==&"combat_player_damage" and event.payload.cause==&"bite" and event.payload.source==&"draco" and event.payload.technique==&"bite"),"原因・出所・技名を保持する")
		started=bridge.command("dev_boss_technique",{"entity_id":boss,"definition":1})
		bridge._core.step(0.4)
		bridge.command("dev_ship_motion",{"position":ship+Vector2.from_angle(angle).orthogonal()*400.0,"velocity":Vector2.ZERO})
		for frame in 220: bridge._core.step(1.0/120.0)
		check(not bridge.command("dev_boss_state").value[0].hit,"横へ避けると確定した噛みつきに当たらない")
		for seconds in [0.3,0.95,1.3]:
			started=bridge.command("dev_boss_technique",{"entity_id":boss,"definition":1})
			for frame in int(seconds*120): bridge._core.step(1.0/120.0)
			check(bridge.command("dev_cancel_technique",{"ticket":started.value}).ok,"予告・実行・回復の途中で取消できる")
			check(bridge.command("dev_boss_state").value[0].warning.is_empty() and bridge.command("dev_boss_body_state").value[-1].position.is_equal_approx(Vector2.ZERO),"取消は予告を消して元の頭位置へ戻す")
		started=bridge.command("dev_boss_technique",{"entity_id":boss,"definition":1})
		bridge.command("dev_cancel_boss",{"entity_id":boss})
		check(bridge.command("dev_boss_state").value[0].stage==7,"本体消失で参加中の噛みつきを取消す")
		bridge.dispose()
	if strict:session.dispose_source()
	session.free()
	if event_only: native_bite_flow(builder,package,cfg,definition,move)
	print("[cpp_draco_bite] failures=",failures)
	get_tree().quit(1 if failures else 0)

func native_bite_flow(builder, package: Dictionary, _cfg: GameConfig, _definition: BossDef, move: BossTechnique) -> void:
	var rules = load("res://scripts/data_types/boss_action_rules.gd").new()
	rules.adapter=&"draco";rules.techniques.assign([move]);rules.conditions={"bite":{"max":700.0}}
	var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.sections=[{"request":"normal","cap":2.0,"next":0,"action_count":1}]
	var compiled: Dictionary = builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
	check(not compiled.is_empty(),"登録済みの噛みつきからSourceの条件付きフローを生成する")
	for key in compiled: package.records[key]=compiled[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	check(bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":194,"mode":1,"stage_id":"B_draco_bite_flow","profile":{},"settings":{"hitstop":false}}).ok,"噛みつきのフローと3形態定義を一緒に読み込む")
	bridge.start(709,{"position":Vector2(300,0),"lab_mode":true})
	bridge.subscribe("確認",func(_frame):return true)
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":Vector2(300,0)}})
	bridge._core.set_motion_context(Vector2(300,0),Vector2(300,0),Vector2(800,450))
	bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false})
	var first := -1
	var second := false
	for frame in 600:
		bridge._core.step(1.0/120.0)
		var active: Array = bridge.command("dev_boss_state").value
		if not active.is_empty():
			if first<0: first=active[0].id
			elif active.any(func(t):return t.id!=first and t.stage==0): second=true;break
	check(first>0 and second,"候補選択から実行・回復を終えて次の噛みつきを選べる")
	bridge.dispose()
