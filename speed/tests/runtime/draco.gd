extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--cpp-draco-shake" in OS.get_cmdline_user_args():
		call_deferred("native_shake")
		return
	if "--cpp-draco-finish" in OS.get_cmdline_user_args():
		call_deferred("native_finish")
		return
	if "--cpp-draco-inhale" in OS.get_cmdline_user_args() or "--cpp-draco-inhale-pose" in OS.get_cmdline_user_args():
		call_deferred("native_inhale")
		return
	if "--cpp-draco-spiral-contact" in OS.get_cmdline_user_args():
		call_deferred("native_spiral_contact")
		return
	if "--cpp-draco-spiral" in OS.get_cmdline_user_args():
		call_deferred("native_spiral")
		return
	if "--cpp-draco-clones" in OS.get_cmdline_user_args():
		call_deferred("native_clones")
		return
	if "--cpp-draco-leap" in OS.get_cmdline_user_args():
		call_deferred("native_leap")
		return
	if "--cpp-draco-charge" in OS.get_cmdline_user_args():
		call_deferred("native_charge")
		return
	check(ResourceLoader.exists("res://data/bosses/draco.tres"), "竜のボス定義を登録する")
	if failed:
		get_tree().quit(1)
		return
	call_deferred("native_finish")

func breath_fixture(move: BossTechnique, flow_enabled := false, moves: Array = []) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg: GameConfig = load("res://data/config.tres").duplicate(true)
	var package: Dictionary = builder.draco_technique_package(load("res://data/bosses/draco.tres"),move,cfg)
	if not moves.is_empty():
		package=builder.boss_body_package(load("res://data/bosses/draco.tres"),cfg)
		var records: Dictionary=builder.draco_set_records(load("res://data/bosses/draco.tres"),moves)
		for record in records:package.records[record]=records[record]
		for part: BossTechnique in moves:
			if part.technique in [&"breath",&"meteor"]:builder.append_draco_breath_rock(package,part,cfg)
			if part.technique==&"inhale":builder.append_draco_inhale_bolt(package,part)
			if part.technique==&"picaro_wall":builder.append_draco_picaro_wall(package,part,cfg)
			if part.technique==&"star_fan":builder.append_draco_star_bolt(package,part)
			builder.append_draco_style(package,part)
	if flow_enabled:
		var rules=load("res://scripts/data_types/boss_action_rules.gd").new()
		rules.adapter=&"draco";rules.techniques.assign([move]);rules.conditions={"breath":{}}
		var flow=load("res://scripts/data_types/boss_flow_def.gd").new()
		flow.sections=[{"request":"normal","cap":2.0,"next":0,"action_count":1}]
		var compiled: Dictionary=builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
		for key in compiled: package.records[key]=compiled[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":194,"mode":1,"stage_id":"B_draco_"+str(move.technique),"profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"技の型付き定義と依存する敵を生成して読む")
	if not configured.ok: print(configured);return {}
	bridge.start(105,{"position":Vector2(700,0),"lab_mode":true})
	var captured: Array = []
	bridge.subscribe("確認",func(frame):captured.append_array(frame.events);return true)
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"level":1,"position":Vector2(700,0),"invincible":false}})
	bridge._core.set_motion_context(Vector2(700,0),Vector2(700,0),Vector2(800,450))
	var boss: int = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	return {"bridge":bridge,"boss":boss,"package":package,"captured":captured}

## 既存の移動攻撃・中断ケースへ突進の状態と表示を接続する。
func native_charge() -> void:
	await native_draco_move("charge")

func native_leap() -> void:
	await native_draco_move("leap")

func draco_move_stage(attack: Dictionary) -> int:
	return (3 if attack.get("staging_phase",0)==1 else 4) if attack.stage==0 and not attack.staging_ready else int(attack.stage)

func native_draco_move(move_id: String) -> void:
	var motion_only:= "--cpp-draco-"+move_id+"-motion" in OS.get_cmdline_user_args()
	var move: BossTechnique=load("res://data/bosses/draco_moves/%s.tres"%move_id)
	var label: String=move.display_name
	var fixture:=breath_fixture(move)
	if fixture.is_empty():get_tree().quit(1);return
	var bridge=fixture.bridge
	check(fixture.package.records["DracoChargeDefinition" if move_id=="charge" else "DracoLeapDefinition"].size()==3,label+"の実効値を3形態へ生成する")
	check(bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1}).ok,"C++の移動攻撃を開始する")
	var saved: Array=[]
	var rendered: Array=[]
	for frame in 900:
		bridge._core.step(1.0/120.0)
		var attack: Dictionary=bridge.command("dev_boss_state").value[0]
		var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
		if not attack.warning.is_empty():
			if not motion_only:check(attack.warning.size()==2,"予告の線分を出す")
		var key: int=draco_move_stage(attack)
		if not motion_only and key not in saved and key<5:
			saved.append(key)
			var held: Dictionary=bridge.checkpoint()
			check(held.ok,"退場・予告・実行・回復の値型を保持する")
			bridge._core.step(1.0/120.0)
			var future: Array=bridge.command("dev_boss_state").value
			var future_body: Array=bridge.command("dev_boss_body_state").value
			check(bridge.restore(held.value).ok,label+"の途中へ復帰する")
			bridge._core.step(1.0/120.0)
			check(bridge.command("dev_boss_state").value==future and bridge.command("dev_boss_body_state").value==future_body,"復帰後の段階・固定照準・全身点列が一致する")
			bridge.restore(held.value);bridge.release_checkpoint(held.value)
		if not motion_only and key not in rendered and key in [0,1,2]:
			rendered.append(key)
			var appearance: Dictionary={}
			for visual: Dictionary in fixture.package.visuals:
				if visual.get("boss","")=="draco":appearance=visual.appearance
			var display=load("res://scripts/render/bosses/draco.gd").new()
			add_child(display);display.apply_frame(body,attack,appearance);await get_tree().process_frame
			check(display._parts.visible,"同じ技状態から予告・攻撃軌跡・回復を描画する")
			display.free()
		if attack.stage==5:break
	if motion_only:
		bridge.dispose()
		native_draco_move_flow(move)
		return
	check(saved.size()==(4 if move_id=="charge" else 5) and rendered.size()==3,"退場から自然終了までの各段階を通る")
	var hits: Array=fixture.captured.filter(func(event):return event.type==&"combat_player_damage" and event.payload.accepted and event.payload.cause==StringName(move_id) and event.payload.source==&"draco" and event.payload.technique==StringName(move_id))
	check(hits.size()==1,"無敵を切った静止対象へ原因・出所・技名を持って1回命中する")
	for target in ([4,0,1,2] if move_id=="charge" else [4,3,0,1,2]):
		var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
		for frame in 900:
			bridge._core.step(1.0/120.0)
			var attack: Dictionary=bridge.command("dev_boss_state").value[0]
			if draco_move_stage(attack)==target:break
		var at: Vector2=bridge.command("dev_boss_body_state").value[-1].position
		check(bridge.command("dev_cancel_technique",{"ticket":started.value}).ok,"退場・予告・実行・回復の途中で取り消す")
		check(bridge.command("dev_boss_state").value[0].warning.is_empty() and bridge.command("dev_boss_state").value[0].attack_points.is_empty() and bridge.command("dev_boss_body_state").value[-1].position.is_equal_approx(at),"取消は移動先を保ち予告・攻撃線を消す")
	bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	bridge.command("dev_cancel_boss",{"entity_id":fixture.boss})
	check(bridge.command("dev_boss_state").value[0].stage==7,"本体消失で移動攻撃を取り消す")
	bridge.dispose()
	native_draco_move_flow(move)

func native_draco_move_flow(move: BossTechnique) -> void:
	var label: String=move.display_name
	# 既存の候補選択→自然終了→次技ケースへ接続する。
	var rules=load("res://scripts/data_types/boss_action_rules.gd").new()
	rules.adapter=&"draco";rules.techniques.assign([move]);rules.conditions={str(move.technique):{}}
	var flow=load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.sections=[{"request":"major" if move.category==&"major" else "normal","cap":2.0,"weights":{"major":100.0} if move.category==&"major" else {"single":100.0},"next":0,"action_count":1}]
	var builder=load("res://tools/content/build_run_content.gd")
	var fixture:=breath_fixture(move)
	var bridge=fixture.bridge
	var package: Dictionary=fixture.package
	bridge.dispose()
	var compiled: Dictionary=builder.boss_flow_records(rules,flow,package.records.BossTechniqueDefinition)
	for k in compiled:package.records[k]=compiled[k]
	bridge=load("res://scripts/runtime/run_bridge.gd").new()
	check(bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":195,"mode":1,"stage_id":"B_draco_"+str(move.technique),"profile":{},"settings":{"hitstop":false}}).ok,label+"の候補フローを読む")
	bridge.start(105,{"position":Vector2(700,0),"lab_mode":true})
	bridge.subscribe("確認",func(_frame):return true)
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"position":Vector2(700,0),"invincible":false}})
	bridge._core.set_motion_context(Vector2(700,0),Vector2(700,0),Vector2(800,450))
	bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false})
	var first: int=-1
	var second:=false
	for frame in (2400 if move.technique==&"spiral" else 1800 if move.technique==&"clones" else 1200):
		bridge._core.step(1.0/120.0)
		var active: Array=bridge.command("dev_boss_state").value
		if not active.is_empty():
			if first<0:first=active[0].id
			elif active.any(func(t):return t.id!=first and t.stage==0):second=true;break
	check(first>0 and second,label+"を選択して自然終了後に次の行動へ進む")
	bridge.dispose()
	print("[cpp_draco_%s] failures="%move.technique,failed)
	get_tree().quit(1 if failed else 0)

## 尾の着弾・小さな波・中断を確認する。
func show_native_draco(fixture: Dictionary, body: Dictionary, attack: Dictionary) -> void:
	var appearance: Dictionary={}
	for visual: Dictionary in fixture.package.visuals:
		if visual.get("boss","")=="draco":appearance=visual.appearance
	var display=load("res://scripts/render/bosses/draco.gd").new()
	add_child(display);display.apply_frame(body,attack,appearance);await get_tree().process_frame
	check(display._parts.visible,"技の予告・攻撃・回復を状態から描く")
	display.free()

func spiral_key(attack: Dictionary) -> int:
	if attack.stage==0:return 0 if attack.departing else 1
	if attack.stage==1:return 2 if attack.stage_time<attack.coil_time else 3 if attack.stage_time<attack.coil_time+attack.pause_time else 4
	return 5 if attack.stage==2 else 6

func spiral_camera(bridge) -> void:
	bridge.command("dev_edit",{"kind":"camera","payload":{"center":Vector2(700,0),"size":Vector2(1600,900),"zoom":1.0,"bars":0.0}})

## 既存の螺旋・拘束解放・中断ケースを値型と読取表示へ接続する。
func native_spiral() -> void:
	var move: BossTechnique=load("res://data/bosses/draco_moves/spiral.tres")
	var fixture:=breath_fixture(move)
	if fixture.is_empty():get_tree().quit(1);return
	var bridge=fixture.bridge
	spiral_camera(bridge)
	check(bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1}).ok,"C++で螺旋収縮を開始する")
	var saved: Array=[]
	var shown: Array=[]
	for frame in 2400:
		bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
		var attack: Dictionary=bridge.command("dev_boss_state").value[0]
		var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
		var key:=spiral_key(attack)
		if attack.stage==2 and attack.return_stage>=0:key=7+int(attack.return_stage)
		if key not in saved and (key<6 or key>=7):
			saved.append(key)
			var held: Dictionary=bridge.checkpoint()
			check(held.ok,"退場・再入場・巻き・予告・収縮・回復を保持する")
			bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
			var future: Array=bridge.command("dev_boss_state").value
			var future_body: Array=bridge.command("dev_boss_body_state").value
			var future_hazards: Array=bridge._core.hazards_snapshot()
			check(bridge.restore(held.value).ok,"螺旋の途中へ復帰する")
			bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
			check(future==bridge.command("dev_boss_state").value and future_body==bridge.command("dev_boss_body_state").value and future_hazards==bridge._core.hazards_snapshot(),"復帰後の胴・壁・カメラと拘束が同じになる")
			bridge.restore(held.value);bridge.release_checkpoint(held.value)
		var display_key:=spiral_key(attack)
		if display_key in [0,2,3,4,5] and display_key not in shown:
			shown.append(display_key);await show_native_draco(fixture,body,attack)
		if attack.stage==5:break
	check(saved.has(8) and saved.has(9) and shown.size()==5 and bridge._core.hazards_snapshot().is_empty(),"各段階の復帰と表示を通り、終了時に壁を解放する")
	for stage in [0,1,2,3,4,8,9]:check(saved.has(stage),"螺旋と復帰の各段階を巻き戻し検証する")
	check(fixture.captured.any(func(e):return e.type==&"combat_player_damage" and e.payload.cause==&"spiral" and e.payload.source==&"draco" and e.payload.technique==&"spiral"),"収縮中の接触の実HPと原因・出所・技名を記録する")
	check(fixture.captured.filter(func(e):return e.type==&"draco_roar").size()==1,"巻き終わりの咆哮を1回だけ渡す")
	var returned: Dictionary=bridge.command("dev_boss_body_state").value[-1]
	check(bridge.command("dev_boss_state").value[0].stage==5 and returned.position.distance_to(Vector2(700,0))<900.0,"螺旋終了時に自機の近くへ戻り、遠方からの通常接近を待たせない")
	bridge.dispose()
	for target in [0,1,2,3,4,5,8,9]:
		fixture=breath_fixture(move);bridge=fixture.bridge;spiral_camera(bridge)
		var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
		for frame in 2400:
			bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
			var attack: Dictionary=bridge.command("dev_boss_state").value[0]
			if (spiral_key(attack) if target<8 else 7+int(attack.return_stage) if attack.stage==2 else -1)==target:break
		bridge.command("dev_cancel_technique",{"ticket":started.value})
		var output: Dictionary=bridge.read_frame().value
		check(bridge._core.hazards_snapshot().is_empty() and not output.ui.controls_locked and not output.ui.encounter_protected and not output.ui.cinematic_camera,"螺旋の各段階取消は壁・拘束・カメラを返す")
		bridge.dispose()
	fixture=breath_fixture(move);bridge=fixture.bridge;spiral_camera(bridge)
	bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	for frame in 1500:
		bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
		if spiral_key(bridge.command("dev_boss_state").value[0])==2:break
	bridge.command("dev_cancel_boss",{"entity_id":fixture.boss})
	check(bridge._core.hazards_snapshot().is_empty() and not bridge.read_frame().value.ui.controls_locked,"本体消失でも巻き中の拘束と壁を解放する")
	bridge.dispose()
	# At either field edge, the return must remain reachable even when the view straddles the boundary.
	for ship_at in [Vector2(9900,0),Vector2(0,9900)]:
		fixture=breath_fixture(move);bridge=fixture.bridge
		bridge.command("dev_edit",{"kind":"ship","payload":{"position":ship_at,"velocity":Vector2.ZERO}})
		bridge.command("dev_edit",{"kind":"camera","payload":{"center":ship_at,"size":Vector2(1600,900),"zoom":1.0,"bars":0.0}})
		bridge._core.set_motion_context(ship_at,ship_at,Vector2(800,450))
		bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
		for frame in 3600:
			bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
			if bridge.command("dev_boss_state").value[0].stage==5:break
		var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
		check(bridge.command("dev_boss_state").value[0].stage==5 and body.position.length()<10000.0 and body.position.distance_to(ship_at)<900.0,"外周付近でも螺旋の後にフィールド内・自機の近くへ復帰する")
		bridge.dispose()
	native_draco_move_flow(move)

func native_spiral_contact() -> void:
	var move: BossTechnique=load("res://data/bosses/draco_moves/spiral.tres")
	var fixture:=breath_fixture(move)
	var bridge=fixture.bridge
	spiral_camera(bridge)
	bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	# 共通壁の先行被弾と分け、収縮が受け付けた実HPだけを確認する。
	for frame in 2200:
		bridge._core.step_ship(1.0/120.0,1.0/120.0,{"touch":true})
		bridge._core.step(1.0/120.0)
		var attack: Dictionary=bridge.command("dev_boss_state").value[0]
		if spiral_key(attack)==4 and not attack.trapped_hit:
			var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
			bridge.command("dev_ship_motion",{"position":body.body_points[64],"velocity":Vector2.ZERO})
		if attack.trapped_hit:break
	var hits: Array=fixture.captured.filter(func(e):return e.type==&"combat_player_damage" and e.payload.accepted and e.payload.cause==&"spiral")
	if hits.size()!=1:print("収縮の被弾=",fixture.captured.filter(func(e):return e.type==&"combat_player_damage"))
	check(hits.size()==1 and hits[0].payload.source==&"draco" and hits[0].payload.technique==&"spiral" and absf(float(hits[0].payload.hp_before-hits[0].payload.hp_after)-35.0)<=35.0*1e-9,"収縮中の接触は1回だけ実HPを減らし、原因・出所・技名を記録する")
	bridge.dispose()
	print("[cpp_draco_spiral_contact] failures=",failed);get_tree().quit(1 if failed else 0)

func native_inhale() -> void:
	var move: BossTechnique=load("res://data/bosses/draco_moves/inhale.tres")
	var fixture:=breath_fixture(move)
	if fixture.is_empty():get_tree().quit(1);return
	var bridge=fixture.bridge
	check(bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1}).ok,"C++で吸引と吐き出しを開始する")
	var native_frame_checked:=false
	var remaining_pose:= "--cpp-draco-inhale-pose" in OS.get_cmdline_user_args()
	var saved: Array=[]
	var shown: Array=[]
	var away: Vector2=bridge._core.ship_snapshot().ship_pos
	for frame in 1500:
		bridge.command("dev_ship_motion",{"position":away,"velocity":Vector2.ZERO})
		bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
		var attack: Dictionary=bridge.command("dev_boss_state").value[0]
		var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
		var key: int=0 if attack.stage==0 else 4 if attack.stage==2 else 3 if attack.spent else 1
		if not remaining_pose and key not in saved and attack.stage<3:
			saved.append(key)
			var held: Dictionary=bridge.checkpoint()
			check(held.ok,"横入り・吸引・吐き出し・回復を保持する")
			bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
			var future: Array=bridge.command("dev_boss_state").value
			var future_body: Array=bridge.command("dev_boss_body_state").value
			var future_shots: Array=bridge._core.hostiles_snapshot()
			check(bridge.restore(held.value).ok,"吸引の途中へ復帰する")
			bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
			check(future==bridge.command("dev_boss_state").value and future_body==bridge.command("dev_boss_body_state").value and future_shots==bridge._core.hostiles_snapshot(),"復帰後の吸引・停止時計・ビーム・彗星が同じになる")
			bridge.restore(held.value);bridge.release_checkpoint(held.value)
		if not remaining_pose and key in [0,1,3,4] and key not in shown:
			shown.append(key);await show_native_draco(fixture,body,attack)
		if not remaining_pose and attack.spent and attack.stage==1 and not 5 in shown:
			var rendered: Dictionary=bridge.read_render(Rect2(-3000,-3000,6000,6000)).value
			var beams: Array=rendered.shapes.filter(func(row):return row.get("draco_beam",false))
			if not beams.is_empty():
				shown.append(5)
				var display=load("res://scripts/render/attacks/beam_draco.gd").new()
				add_child(display);display.frame_apply(beams[0],1.0);await get_tree().process_frame
				check(display.material.shader!=null and is_equal_approx(display.material.get_shader_parameter("half0"),float(move.width)*0.5),"口元の溜めと伸びる光線を既存の専用shaderで描く")
				display.free()
		if remaining_pose and attack.beam_alive and not native_frame_checked:
			var render: Dictionary=bridge.read_render(Rect2(-3000,-3000,6000,6000)).value
			var view=load("res://scripts/render/run_frame_view.gd").new()
			for visual: Dictionary in fixture.package.visuals:view.visuals[int(visual.id)]=visual
			check(view._valid(render),"専用光線の読取値を通常描画の入口が受け付ける")
			view.free();native_frame_checked=true
		if attack.stage==5:break
	if remaining_pose:
		check(native_frame_checked,"専用光線の読取値を通常描画へ渡す")
		bridge.dispose()
		print("[cpp_draco_inhale_pose] failures=",failed);get_tree().quit(1 if failed else 0);return
	check(saved.size()==4 and shown.size()==5 and bridge._core.hazards_snapshot().is_empty(),"全段階の復帰・表示を通り、終了時にビームを解放する")
	check(bridge._core.hostiles_snapshot().size()==24,"実験場の12星から弧ごとの割当と上限24発を生成し、終了後も彗星を残す")
	bridge.dispose()
	fixture=breath_fixture(move);bridge=fixture.bridge
	check(bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1}).ok,"口へ届く吸引を開始する")
	var bitten: bool=false
	for frame in 1500:
		bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
		var attack: Dictionary=bridge.command("dev_boss_state").value[0]
		bitten = bitten or attack.caught
		check(not attack.spent and bridge._core.hazards_snapshot().is_empty(),"口に届いた機体へビームを撃たない")
		if attack.stage==5:break
	check(bitten and bridge._core.hostiles_snapshot().is_empty(),"口に届いたら噛みつきだけで技を終える")
	check(fixture.captured.any(func(e):return e.type==&"combat_player_damage" and e.payload.accepted and e.payload.cause==&"inhale_bite" and e.payload.source==&"draco" and e.payload.technique==&"inhale" and is_equal_approx(e.payload.hp_before-e.payload.hp_after,30.0)),"吸引の噛みつきの実HPと専用原因・出所・技名を記録する")
	bridge.dispose()
	for operation in ["windup","pull","caught","spent","recovery","dev_cancel_boss"]:
		fixture=breath_fixture(move);bridge=fixture.bridge
		var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
		var hold_at: Vector2=bridge._core.ship_snapshot().ship_pos
		for frame in 1400:
			if operation in ["spent","recovery","dev_cancel_boss"]:bridge.command("dev_ship_motion",{"position":hold_at,"velocity":Vector2.ZERO})
			bridge._core.step(1.0/120.0);bridge._core.step_hazards(1.0/120.0)
			var attack: Dictionary=bridge.command("dev_boss_state").value[0]
			if operation=="windup" or operation=="pull" and attack.stage==1 or operation=="caught" and attack.caught or operation in ["spent","dev_cancel_boss"] and attack.spent or operation=="recovery" and attack.stage==2:break
		if operation=="dev_cancel_boss":bridge.command(operation,{"entity_id":fixture.boss})
		else:bridge.command("dev_cancel_technique",{"ticket":started.value})
		var attack: Dictionary=bridge.command("dev_boss_state").value[0]
		check(bridge._core.hazards_snapshot().is_empty() and not attack.steering_locked,"各段階の取消・本体消失でビームと操舵制限を解放する")
		if operation in ["spent","recovery","dev_cancel_boss"]:check(bridge._core.hostiles_snapshot().size()==24,"吐き出した彗星は取消と本体消失でも自然寿命まで残す")
		bridge.dispose()
	native_draco_move_flow(move)

func native_clones() -> void:
	var move: BossTechnique=load("res://data/bosses/draco_moves/clones.tres")
	var group := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--clones-group="):group=argument.trim_prefix("--clones-group=")
	if group in ["all","motion"]:
		var before := failed
		await native_clones_motion(move)
		print("[cpp_draco_clones_motion] failures=",failed-before)
	if group in ["all","interrupt"]:
		var before := failed
		await native_clones_interrupt(move)
		print("[cpp_draco_clones_interrupt] failures=",failed-before)
	pass
	if group in ["all","shapes","remaining"]:native_clones_shapes(move)
	if group in ["remove","pending"]:native_clones_remove(move)
	if group in ["all","flow","pending"]:native_draco_move_flow(move);return
	print("[cpp_draco_clones_%s] failures="%group,failed)
	get_tree().quit(1 if failed else 0)

func native_clones_motion(move: BossTechnique) -> void:
	var fixture:=breath_fixture(move)
	if fixture.is_empty():return
	var bridge=fixture.bridge
	check(fixture.package.records.DracoClonesDefinition.size()==3 and fixture.package.records.HydraNormalDefinition.size()==5,"複製の3形態と5通常技の値・参照を同じスキーマから生成する")
	bridge.command("set_recording",{"active":true})
	check(bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1}).ok,"C++で全身複製を開始する")
	var current: Dictionary=bridge.command("dev_boss_state").value[0]
	var saved: Array=[]
	var shown: Array=[]
	var clones_seen:=false
	var initial_hp: float=bridge._core.ship_snapshot().ship_hp
	for frame in 1250:
		# Hostは既存effectsを進めてから、そのtickの新しい判定を足す。
		bridge._core.step_hazards(1.0/120.0);bridge._core.step(1.0/120.0)
		current=bridge.command("dev_boss_state").value[0]
		var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
		clones_seen=clones_seen or body.clones.size()==2
		if current.stage not in saved and current.stage in [0,1,2]:
			saved.append(current.stage)
			var held: Dictionary=bridge.checkpoint()
			check(held.ok,"予告・飛び込み・回復の複製とinnerRunnerを値型で保持する")
			bridge._core.step_hazards(1.0/120.0);bridge._core.step(1.0/120.0)
			var future: Array=bridge.command("dev_boss_state").value
			var future_body: Array=bridge.command("dev_boss_body_state").value
			check(bridge.restore(held.value).ok,"全身複製の途中へ復帰する")
			bridge._core.step_hazards(1.0/120.0);bridge._core.step(1.0/120.0)
			check(bridge.command("dev_boss_state").value==future and bridge.command("dev_boss_body_state").value==future_body,"復帰後の時計・割当・部位・判定・表示が一致する")
			bridge.restore(held.value);bridge.release_checkpoint(held.value)
		if current.stage not in shown and current.stage in [0,1,2]:
			shown.append(current.stage)
			var display=load("res://scripts/render/bosses/draco.gd").new();add_child(display)
			display.apply_frame(body,current,{})
			await get_tree().process_frame
			check(display._parts.visible and display._clones.size()==body.clones.size(),"本体と複製2体を正式な全身素材で予告・実行・回復へ描く")
			display.free()
		if current.stage==5:break
	check(clones_seen and saved.size()==3 and shown.size()==3 and bridge.command("dev_boss_body_state").value[-1].clones.is_empty(),"自然終了で複製と全部位を回収し3段階の表示・復帰を通る")
	check(bridge._core.ship_snapshot().ship_hp<initial_hp and fixture.captured.any(func(e):return e.type=="combat_player_damage" and e.payload.accepted and e.payload.cause=="clone_leap" and e.payload.source=="draco" and e.payload.technique=="clones"),"飛び込みが実HPとclone_leap・draco・clonesの通知へ届く")
	bridge.dispose()

func native_clones_interrupt(move: BossTechnique) -> void:
	var fixture:=breath_fixture(move)
	if fixture.is_empty():return
	var bridge=fixture.bridge
	var started: Dictionary=bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	var body: Dictionary=bridge.command("dev_boss_body_state").value[-1]
	var units: Array=bridge.command("dev_boss_state").value[0].clones
	var clone: Dictionary=units[1]
	var body_hp: float=body.hp
	var part: int=clone.parts[clone.parts.size()/2]
	check(bridge.command("dev_damage",{"entity_id":part,"amount":25.0,"cause":"shot"}).ok,"複製の胴部位へ命中する")
	check(bridge.command("dev_boss_body_state").value[-1].hp==body_hp and is_equal_approx(bridge.command("dev_boss_state").value[0].clones[1].hp,float(move.clone_hp)-25.0),"複製への命中は複製HPへ転送し本体HPから独立する")
	var saved: Dictionary=bridge.checkpoint()
	check(saved.ok,"複製部位へ命中した後の転送先を保持する")
	bridge.command("dev_damage",{"entity_id":part,"amount":100000.0,"cause":"shot"});bridge._core.step(float(move.warn));bridge._core.step(1.0/120.0)
	check(not bridge.command("dev_boss_state").value[0].clones[1].alive and bridge.command("dev_boss_state").value[0].stage<5 and bridge.command("dev_boss_body_state").value[-1].clones.size()==1,"参加複製の消失は全部位を消し、生きている体の攻撃を続ける")
	bridge.restore(saved.value)
	check(bridge.command("dev_cancel_technique",{"ticket":started.value}).ok,"予告中の複製を取り消す")
	body=bridge.command("dev_boss_body_state").value[-1]
	check(body.clones.size()==2 and not body.picaro_attacking and body.clones.map(func(u):return u.id)==[units[1].id,units[2].id],"取消した生存複製は同じ役者と部位のPicaroとして残る")
	var display=load("res://scripts/render/bosses/draco.gd").new();add_child(display);display.apply_frame(body,{},{});await get_tree().process_frame
	check(display._clones.size()==2,"取消後のPicaroも全身の正式表示を保つ");display.free()
	var adopted: Dictionary=bridge.checkpoint();bridge._core.step(1.0/120.0);var expected: Dictionary=bridge.command("dev_boss_body_state").value[-1]
	check(adopted.ok and bridge.restore(adopted.value).ok,"Picaro変換後を保持して復帰する");bridge._core.step(1.0/120.0);check(bridge.command("dev_boss_body_state").value[-1]==expected,"復帰後も複製胴の形とPicaro時計が一致する")
	bridge.restore(saved.value);bridge.command("dev_remove",{"entity_id":fixture.boss});bridge._core.step(1.0/120.0)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[-1].clones.is_empty(),"本体の消失は複製と部位を回収して技を中断する")
	bridge.restore(saved.value)
	for frame in 500:
		bridge._core.step_hazards(1.0/120.0);bridge._core.step(1.0/120.0)
		if bridge.command("dev_boss_state").value[0].stage==1 and bridge.command("dev_boss_state").value[0].stage_time>3.0:break
	var active: Dictionary=bridge.checkpoint()
	body=bridge.command("dev_boss_body_state").value[-1]
	var persistent: Array=body.effects.filter(func(e):return e.kind=="rubble")
	bridge.command("dev_cancel_technique",{"ticket":started.value})
	body=bridge.command("dev_boss_body_state").value[-1]
	check(body.effects.all(func(e):return e.kind=="rubble") and body.effects.size()==persistent.size(),"取消は非persistent判定を消し、投石の持続攻撃を残す")
	bridge.command("dev_cancel_boss",{"entity_id":fixture.boss})
	check(bridge.command("dev_boss_body_state").value[-1].clones.is_empty() and bridge.command("dev_boss_body_state").value[-1].effects.is_empty(),"本体取消はPicaroと残留攻撃を回収する")
	bridge.release_checkpoint(saved.value);bridge.release_checkpoint(adopted.value);bridge.release_checkpoint(active.value);bridge.dispose()

func native_clones_remove(move: BossTechnique) -> void:
	var fixture:=breath_fixture(move)
	if fixture.is_empty():return
	var bridge=fixture.bridge
	bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1})
	bridge.command("dev_remove",{"entity_id":fixture.boss});bridge._core.step(1.0/120.0)
	check(bridge.command("dev_boss_state").value[0].stage==7 and bridge.command("dev_boss_body_state").value[-1].clones.is_empty(),"本体の消失は複製と部位を回収して技を中断する")
	bridge.dispose()

func native_clones_shapes(move: BossTechnique) -> void:
	var fixture:=breath_fixture(move)
	if fixture.is_empty():return
	var bridge=fixture.bridge
	check(bridge.command("dev_boss_technique",{"entity_id":fixture.boss,"definition":1}).ok,"分身Hostの判定生成を始める")
	var count:=0
	for tick in 800:
		bridge._core.step_hazards(1.0/120.0);bridge._core.step(1.0/120.0)
		var emitted: Array=bridge.command("dev_boss_body_state").value[-1].effects.filter(func(e):return is_zero_approx(e.age))
		count+=emitted.size()
		if bridge.command("dev_boss_state").value[0].clone_ended:break
	check(count>0,"分身Hostが通常技の判定を生成する")
	bridge.dispose()

## 全技を持つ本番パッケージから、条件・費用・区間予算を通して進む。
func finish_fixture(name := "", phase := 1, limit := -1.0) -> Dictionary:
	var builder=load("res://tools/content/build_run_content.gd")
	var cfg: GameConfig=load("res://data/config.tres").duplicate(true)
	cfg.planet_radius=0.0
	cfg.time_up_charge_time=0.3
	for key in ["death_freeze_time","death_explosion_time","death_game_over_time"]:cfg.set(key,0.01)
	for key in ["boss_finish_slow_time","boss_finish_blast_time","boss_finish_relic_appear_time","boss_finish_relic_hold_time","boss_finish_relic_collect_time","boss_finish_clear_time"]:cfg.set(key,0.02)
	var definition: BossDef=load("res://data/bosses/draco.tres").duplicate(true)
	var rules=load("res://data/bosses/ai/draco_action_rules.tres").duplicate(true)
	var flow=load("res://data/bosses/ai/draco_flow.tres").duplicate(true)
	if not name.is_empty():
		for section: Dictionary in flow.sections:
			if section.get("request","")!="rest":section.allowed_techniques=[name]
	var stage:=RuntimeStage.new();stage.time_limit=limit
	var package: Dictionary=builder.boss_package(definition,cfg,stage,{"rules":rules,"flow":flow})
	if package.is_empty():check(false,"全13技の本番パッケージを生成する: "+name);return {}
	var bridge=load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary=bridge.configure(builder.Schema.write_content(package.records,"0".repeat(64).hex_decode()),{"api_version":1,"run_id":449,"mode":1,"stage_id":"B_draco_finish","profile":{},"settings":{"hitstop":false}})
	if not configured.ok:check(false,"全13技の型付き定義を読む: "+str(configured));return {}
	bridge.start(105,{"position":Vector2(300,0)})
	bridge._core.set_motion_context(Vector2(300,0),Vector2.ZERO,Vector2(1400,1000))
	bridge._core.set_run_guards({"invincible":true})
	var events: Array=[];bridge.subscribe("全技の進行",func(packet):events.append_array(packet.events);return true)
	bridge.command("set_recording",{"active":true})
	var id: int=bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false}).value
	var f: Dictionary={"bridge":bridge,"boss":id,"package":package,"captured":events,"rules":rules,"flow":flow}
	for target_phase in range(2,phase+1):
		var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
		bridge.command("dev_damage",{"entity_id":id,"amount":body.max_hp,"cause":"shot"})
		for tick in 800:
			check(bridge._core.step(0.02),"形態移行の世界更新を受理する");bridge._core.step_hazards(0.02)
			body=bridge.command("dev_boss_body_state").value[0]
			if body.mode==1 and body.phase==target_phase:break
		check(body.phase==target_phase and body.mode==1,"実HPの閾値から形態を進め、戦闘へ戻る: %d"%target_phase)
	return f

func finish_target(f: Dictionary, gate: Dictionary) -> void:
	var active: Array=f.bridge.command("dev_boss_state").value
	if active.any(func(attack):return attack.actor==f.boss and attack.stage<5):return
	var body: Dictionary=f.bridge.command("dev_boss_body_state").value[0]
	var distance: float=(float(gate.get("min",0.0))+minf(float(gate.get("max",600.0)),800.0))*0.5
	var at: Vector2=body.position+Vector2.from_angle(body.facing+deg_to_rad(float(gate.get("angle",0.0))))*distance
	f.bridge.command("dev_ship_motion",{"position":at,"velocity":Vector2.ZERO})
	f.bridge._core.set_motion_context(at,at,Vector2(1400,1000))

func finish_tick(f: Dictionary, dt := 0.02) -> void:
	f.bridge._core.step(dt);f.bridge._core.step_hazards(dt);f.bridge.command("dev_boss_body_state")

func finish_frame(f: Dictionary, input: Dictionary = {}) -> bool:
	var fields: Dictionary=f.bridge.pack_intent(Intent.new())
	fields.merge(input,true)
	return f.bridge.step(1.0/120.0,fields,{"logical_size":Vector2(1400,1000)}).ok

func native_finish() -> void:
	var group: String="all"
	var only_move: String=""
	var only_phase: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--finish-group="):group=arg.trim_prefix("--finish-group=")
		if arg.begins_with("--finish-move="):only_move=arg.trim_prefix("--finish-move=")
		if arg.begins_with("--finish-phase="):only_phase=arg.trim_prefix("--finish-phase=")
	if group in ["all","moves","remaining"]:
		var phases: Dictionary={"bite":1,"tail_sweep":1,"star_fan":1,"breath":1,"meteor":1,"charge":1,"leap":1,"rifts":1,"spiral":1,"clones":2,"picaro_wall":2,"inhale":3}
		var activated: Array[String]=[]
		for name: String in phases:
			if not only_move.is_empty() and not name in only_move.split(","):continue
			var f:=finish_fixture(name,phases[name])
			if f.is_empty():continue
			check(f.package.records.BossTechniqueDefinition.filter(func(row):return row.boss==1 and row.phase==1).size()==13,"全技を持つ同じパッケージから選ぶ: "+name)
			check(f.package.records.DracoFlowGateDefinition.all(func(row):return row.maximum_phase==3),"省略を含む形態上限3を生成する: "+name)
			var emitted:=false
			for tick in 2000:
				finish_target(f,f.rules.conditions.get(name,{}));finish_tick(f)
				emitted=f.captured.any(func(event):return event.type=="boss_action" and event.payload.action==name and event.payload.step=="execute")
				if emitted:break
			if not emitted:print("[cpp_draco_finish] 未発動=",name," flow=",f.bridge.command("dev_boss_flow_state").value)
			check(emitted,"本番条件・費用・予算から選んだ実発動を記録する: "+name)
			if emitted:
				activated.append(name)
				print("[cpp_draco_finish] 実発動=",name)
			var body: Dictionary=f.bridge.command("dev_boss_body_state").value[0]
			var attacks: Array=f.bridge.command("dev_boss_state").value
			var own: Array=attacks.filter(func(attack):return attack.actor==f.boss)
			if not own.is_empty():await show_native_draco(f,body,own[0])
			check(body.phase==phases[name],"通常HP・低HPの形態で技を選ぶ: "+name)
			f.bridge.dispose()
		print("[cpp_draco_finish] 本番フローの実発動=",activated)
	if group in ["all","selection","remaining"]:
		for phase in [1,2,3]:
			if not only_phase.is_empty() and not str(phase) in only_phase.split(","):continue
			var f:=finish_fixture("",phase)
			if f.is_empty():continue
			var selected: Array[String]=[]
			for tick in 1800:
				finish_target(f,{"min":250.0,"max":600.0});finish_tick(f)
				for event: Dictionary in f.captured:
					if event.type=="boss_action" and event.payload.step=="execute" and not event.payload.action in selected:selected.append(event.payload.action)
				if selected.size()>=3:break
			check(selected.size()>=3,"候補制限のない本番プログラムが形態ごとの複数技を選ぶ: %d"%phase)
			check(phase>=2 or (not "clones" in selected and not "picaro_wall" in selected),"第1形態で低HP専用技を選ばない")
			check(phase>=3 or not "inhale" in selected,"第3形態前に吸引を選ばない")
			print("[cpp_draco_finish] 候補制限なし phase=",phase," 実発動=",selected)
			f.bridge.dispose()
	if group in ["all","end","timeout","remaining"]:
		var f:=finish_fixture("",1,0.01)
		if not f.is_empty():
			for tick in 4:check(finish_frame(f),"時間切れの固定更新を受理する")
			var body: Dictionary=f.bridge.command("dev_boss_body_state").value[0]
			check(f.captured.any(func(e):return e.type=="time_limit_reached") and f.bridge.read_frame().value.ui.phase==RunIds.Phase.Dying,"時間切れの一撃は溜めを挟まず機体を倒す")
			for tick in 8:finish_frame(f)
			var result: Variant=f.bridge.read_frame().value.result
			check(result!=null and result.kind=="Death" and not f.captured.any(func(e):return e.type=="clear_banner"),"時間切れは勝利を付けず敗北で確定する")
			f.bridge.dispose()
	if group in ["all","end","abort"]:
		var f:=finish_fixture("rifts")
		if not f.is_empty():
			for tick in 1500:
				finish_target(f,f.rules.conditions.rifts);finish_tick(f)
				if f.captured.any(func(e):return e.type=="boss_action" and e.payload.action=="rifts" and e.payload.step=="execute"):break
			check(f.bridge.command("abort",{"reason":0}).ok and f.bridge.read_frame().value.result.kind=="Abort","技の途中中断は勝利を付けず終了する")
			var body: Dictionary=f.bridge.command("dev_boss_body_state").value[0]
			check(body.mode==5 and body.rift_walls.is_empty() and body.closing_walls==0,"途中中断で持続攻撃を回収する")
			f.bridge.dispose()
	if group=="clear":
		var f:=finish_fixture("",3)
		if not f.is_empty():
			var bridge=f.bridge
			var body: Dictionary=bridge.command("dev_boss_body_state").value[0]
			bridge.command("dev_damage",{"entity_id":f.boss,"amount":body.hp+1.0,"cause":"shot"})
			body=bridge.command("dev_boss_body_state").value[0]
			check(body.finale.active and body.finale.stage=="release","第3形態の実HPを削り切ると決着が始まる")
			for tick in 800:
				finish_frame(f)
				body=bridge.command("dev_boss_body_state").value[0]
				if body.finale.stage=="input":break
			check(body.finale.stage=="input","実撃破から決着専用入力へ進む")
			finish_frame(f,{"has_cursor":true,"pen":body.finale.center,"finale_pen":body.finale.center,"finale_pressed":true})
			finish_frame(f,{"has_cursor":true,"pen":body.finale.center+Vector2(100,0),"finale_pen":body.finale.center+Vector2(100,0),"finale_released":true})
			for tick in 1200:
				finish_frame(f)
				if bridge.read_frame().value.result!=null:break
			var frame: Dictionary=bridge.read_frame().value
			check(frame.result!=null and frame.result.kind=="Clear","最後の決着から通常のCLEAR結果を一度だけ確定する")
			check(f.captured.filter(func(e):return e.type=="boss_defeated").size()==1 and f.captured.filter(func(e):return e.type=="clear_banner").size()==1 and f.captured.filter(func(e):return e.type=="run_finished").size()==1,"撃破・CLEAR・結果確定の通知を各1回届ける")
			var count: int=f.captured.size()
			for tick in 5:finish_frame(f)
			check(f.captured.size()==count,"完了後の固定更新で勝利通知を繰り返さない")
			print("[cpp_draco_finish] 最終通知=",f.captured.filter(func(e):return e.type in ["boss_defeated","clear_banner","run_finished"]))
			bridge.dispose()
	print("[cpp_draco_finish] group=",group," failures=",failed)
	get_tree().quit(1 if failed else 0)

## 通知の検証失敗で入力取得とフレーム配信が止まらないことを確認する。
func native_shake() -> void:
	var index=JSON.parse_string(FileAccess.get_file_as_string("res://.content/run/stage_5.json"))
	if not index is Dictionary:
		check(false,"生成済みステージ5の索引を読む");get_tree().quit(1);return
	var bridge=load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary=bridge.configure(FileAccess.get_file_as_bytes(index.binary),{"api_version":1,"run_id":194,"mode":1,"stage_id":"5","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"ステージ5の正規生成データを読む")
	if not configured.ok:bridge.dispose();get_tree().quit(1);return
	check(bridge.start(105,{"position":Vector2(700,0),"lab_mode":true}).ok,"ステージ5のランを開始する")
	bridge.command("dev_set_scenario",{"kind":"lab","params":{"empty":true,"invincible":true,"auto_spawn":false,"auto_boss":false}})
	var spawned: Dictionary=bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":false})
	check(spawned.ok,"ステージ5のボスを出す")
	if not spawned.ok:bridge.dispose();get_tree().quit(1);return
	check(bridge.boss_trial(spawned.value,"prepare",{"phase":1,"origin":Vector2.ZERO,"target":Vector2(700,0),"selection":false,"steering_locked":false,"guard":1.0,"logical_size":Vector2(800,450)}).ok,"尻尾振りの試行条件を準備する")
	check(bridge.boss_trial(spawned.value,"start",{"technique":"tail_sweep"}).ok,"尻尾振りを開始する")
	var captured: Array=[]
	bridge.subscribe("揺れ通知",func(frame):captured.append_array(frame.events);return true)
	var polls: Array=[]
	var packets: Array=[]
	bridge.subscribe("揺れ後の画面更新",func(frame):packets.append(frame);return true)
	var provider:=func() -> Intent:
		polls.append(true)
		var intent:=Intent.new()
		intent.has_cursor=true
		intent.cursor=Vector2(700,-1000)
		return intent
	var received:=false
	for tick in 900:
		var result: Dictionary=bridge.poll_and_step(1.0/120.0,provider,Vector2(800,450))
		if not result.ok or (not bridge.delivery_error.is_empty() and not bridge.delivery_error.ok):
			check(false,"尻尾振りの通知を含む更新を受理する: "+str(bridge.delivery_error if result.ok else result))
			break
		received=captured.any(func(event):return event.type==&"draco_shake")
		if received:break
	check(received,"尻尾振りの揺れ通知を配信する")
	if received:
		var shake: Dictionary=captured.filter(func(event):return event.type==&"draco_shake")[0]
		check(shake.payload.has("amount") and is_finite(shake.payload.amount),"揺れの強さamountを配信する")
		check(bridge.command("dev_ship_motion",{"position":Vector2(700,0),"velocity":Vector2(120,0)}).ok,"静止させた実験機を操舵できる速さへ戻す")
		var before: Dictionary=bridge.read_frame().value
		polls.clear();packets.clear()
		for tick in 30:
			check(bridge.poll_and_step(1.0/120.0,provider,Vector2(800,450)).ok,"揺れ後の更新を受理する")
		var after: Dictionary=bridge.read_frame().value
		check(polls.size()==30 and packets.size()==30,"揺れ後も30回すべて入力を取得し画面へ配信する")
		check(after.ui.ship_vel.y<0,"揺れ後の上向き入力で機体が旋回する: velocity=%s/%s"%[before.ui.ship_vel,after.ui.ship_vel])
		check(after.tick==before.tick+30 and after.camera.center!=before.camera.center,"揺れ後も時計とカメラを更新する: ticks=%s/%s camera=%s/%s"%[before.tick,after.tick,before.camera.center,after.camera.center])
	bridge.dispose()
	print("[cpp_draco_shake] failures=",failed)
	get_tree().quit(1 if failed else 0)
