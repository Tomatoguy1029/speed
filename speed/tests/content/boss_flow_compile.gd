extends SceneTree
var failed := 0
func check(ok: bool, label: String) -> void:
	print("[boss-compile] ", "PASS " if ok else "FAIL ", label)
	if not ok: failed += 1
func _initialize() -> void:
	if "--cpp-shared-final-record" in OS.get_cmdline_user_args():
		call_deferred("check_cpp_shared_final_record")
		return
	if "--cpp-shared" in OS.get_cmdline_user_args():
		call_deferred("check_cpp_shared")
		return
	if "--cpp-b00" in OS.get_cmdline_user_args():
		call_deferred("check_cpp_technique")
		return
	var compiler = load("res://tools/content/build_boss_program.gd")
	check(compiler != null, "compiler available")
	if compiler == null:
		quit(1)
		return
	var source := {"techniques": [load("res://data/bosses/hydra_moves/bite_thrust.tres")], "layout": {"a": Vector2(0, 0)}}
	if FileAccess.file_exists("res://.content/tests/compiled_boss.tres"): DirAccess.remove_absolute("res://.content/tests/compiled_boss.tres")
	var result = compiler.compile(source, "res://.content/tests/compiled_boss.tres")
	check(result.error == OK and result.generated, "generate runtime program")
	source.layout.a = Vector2(900, 200)
	result = compiler.compile(source, "res://.content/tests/compiled_boss.tres")
	check(result.error == OK and not result.generated, "layout change reuses runtime data")
	check(result.program.data.techniques[0].bite_dmg == 16.0, "compiled values preserved")
	source.techniques[0] = source.techniques[0].duplicate(true)
	var compiled = compiler.compile(source, "res://.content/tests/embedded_boss.tres")
	source.techniques[0].bite_dmg = 999.0
	check(compiled.program.data.techniques[0].bite_dmg == 16.0, "runtime values are independent of editor resources")
	var rules = load("res://data/bosses/ai/hydra_action_rules.tres").duplicate(true)
	var signature: Variant = compiler.canonical({"rules": rules})
	rules.condition_groups = {"custom": {"title": "表示用の条件選択", "category": "normal", "nodes": ["bite_thrust"]}}
	check(compiler.canonical({"rules": rules}) != signature, "runtime condition categories update the signature")
	var grouped_signature: Variant = compiler.canonical({"rules": rules})
	rules.condition_groups.custom.title = "別の表示名"
	check(compiler.canonical({"rules": rules}) == grouped_signature, "display-only condition titles do not update the runtime signature")
	check(compiler.snapshot({"rules": rules}).rules.condition_groups.custom.category == "normal" and not compiler.snapshot({"rules": rules}).rules.condition_groups.custom.has("title"), "runtime retains category and membership without editor titles")
	rules.conditions.bite_thrust.min = 900.0
	rules.conditions.bite_thrust.max = 100.0
	var invalid = compiler.compile({"rules": rules}, "res://.content/tests/invalid_boss.tres")
	check(invalid.error != OK, "invalid distance interval is rejected before writing")
	rules.conditions.bite_thrust = {"half_angle": -1.0}
	check(not compiler.validate({"rules": rules}).is_empty(), "negative sector angles are rejected")
	var flow = load("res://scripts/data_types/boss_flow_def.gd").new()
	flow.sections = [{"next": 0, "action_count": 1.5, "no_candidate_timeout": 0.5}]
	check(not compiler.validate({"flow": flow}).is_empty(), "fractional attack counts cannot silently become a different battle rhythm")
	flow.sections[0].action_count = 2
	flow.sections[0].section_budget = -1.0
	check(not compiler.validate({"flow": flow}).is_empty(), "negative section budgets are rejected")
	var weighted = load("res://data/bosses/ai/monoceros_action_rules.tres").duplicate(true)
	weighted.selection_bias = {"missing": 2.0}
	check(not compiler.validate({"rules": weighted}).is_empty(), "selection policy cannot refer to a missing technique")
	quit(1 if failed else 0)

func check_cpp_technique() -> void:
	var builder = load("res://tools/content/build_run_content.gd")
	var compiler = load("res://tools/content/build_boss_program.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var actor = load("res://data/enemies/drifter.tres").duplicate(true)
	actor.speed = 0.0
	actor.radius = 96.0
	var boss = load("res://data/bosses/monoceros.tres")
	var move = load("res://data/bosses/monoceros_moves/charge.tres").duplicate(true)
	move.warn = 0.4
	move.active = 0.2
	move.recover = 0.3
	move.distance = 400.0
	move.track_during_warn = false
	var records: Dictionary = builder.chase_records(actor,cfg)
	var compiled: Dictionary = builder.boss_technique_records(boss,move)
	check(compiled.BossTechniqueDefinition[0].warn==0.4 and compiled.BossTechniqueDefinition[1].active==move.active_p2,"編集値と第2形態の実効値を生成する")
	check(is_equal_approx(compiled.BossTechniqueStage[0].at,0.18) and compiled.BossTechniqueStage[1].at==0.4 and is_equal_approx(compiled.BossTechniqueStage[2].at,0.6),"静的Animationを使わず予告・固定・発進・終了時刻を生成する")
	check(compiler.registered_stage_commands([{"at":0.1,"method":&"unknown","args":[]}]).is_empty(),"未登録methodを拒否する")
	check(compiler.registered_stage_commands([{"at":0.1,"method":&"launch_strike","args":[1]}]).is_empty(),"段階命令の未登録引数を拒否する")
	for key in compiled: records[key] = compiled[key]
	var bytes: PackedByteArray = builder.Schema.write_content(records,"0".repeat(64).hex_decode())
	check(not bytes.is_empty(),"型付きボス技を共通バイナリへ書く")
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var configured: Dictionary = bridge.configure(bytes,{"api_version":1,"run_id":142,"mode":1,"stage_id":"B00","profile":{},"settings":{"hitstop":false}})
	check(configured.ok,"C++が技定義と登録命令を検査して読む")
	if not configured.ok:
		print("[cpp_b00] failed=%d"%failed)
		quit(1)
		return
	check(bridge.start(142,{"position":Vector2(300,0)}).ok,"固定場面を開始する")
	bridge.command("dev_ship_motion",{"position":Vector2(300,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(300,0),Vector2(300,0),Vector2(640,360))
	var id: int = bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2.ZERO}).value
	bridge._core.set_enemy_motion(id,{"facing":0.0})
	var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":id,"definition":1})
	check(started.ok,"一角獣の突進を型付きチケットで開始する")
	check(bridge._core.step(0.2),"段階の世界更新を実行する")
	var state: Array = bridge.command("dev_boss_state").value
	check(state[0].stage==0 and state[0].locked and state[0].cursor==1,"編集した固定時刻で予告の照準を止める")
	var held: Dictionary = bridge.checkpoint()
	check(held.ok,"予告途中の段階・カーソル・対象を保持する")
	check(bridge._core.step(0.2),"段階の世界更新を実行する")
	state = bridge.command("dev_boss_state").value
	check(state[0].stage==1 and state[0].position==Vector2.ZERO,"発進tickでは移動せず次の固定更新を待つ")
	check(bridge._core.step(0.1),"突進の世界更新を実行する")
	state = bridge.command("dev_boss_state").value
	check(state[0].position.is_equal_approx(Vector2(200,0)) and state[0].hit,"実効速度で進み角の掃引を一回命中させる")
	var events: Array = bridge.read_frame().value.events
	check(events.any(func(event): return event.type==&"combat_player_damage" and event.payload.cause==&"horn" and event.payload.source==&"monoceros" and event.payload.technique==&"charge"),"被弾の原因と出所・技名を記録へ渡す")
	var render: Dictionary = bridge.read_render(Rect2(-100,-200,1000,500)).value
	var view = load("res://scripts/render/run_frame_view.gd").new()
	for visual in records.ResourceKey: view.visuals[visual.id] = visual
	check(view._valid(render) and render.boss_techniques[0].horn==state[0].horn,"戦闘の角と予告を同じ表示接続へ渡す")
	view.free()
	check(bridge._core.step(0.1),"突進の世界更新を実行する")
	state = bridge.command("dev_boss_state").value
	check(state[0].stage==2 and is_equal_approx(state[0].remaining,0.3),"生成した終了時刻で回復へ進む")
	check(bridge._core.step(0.3),"回復の世界更新を実行する")
	check(bridge.command("dev_boss_state").value[0].stage==5,"回復の後に技を完了する")
	check(bridge.restore(held.value).ok,"予告途中へ復帰する")
	check(bridge._core.step(0.2),"段階の世界更新を実行する")
	check(bridge._core.step(0.1),"突進の世界更新を実行する")
	check(bridge.command("dev_boss_state").value==[render.boss_techniques[0]],"復帰後に同じ段階・位置・一回命中へ進む")
	check(bridge.command("dev_cancel_technique",{"ticket":started.value}).ok,"技の途中取消を区別する")
	check(bridge._core.step(0.2),"段階の世界更新を実行する")
	check(bridge.command("dev_boss_state").value[0].stage==7,"取消後に段階命令を再実行しない")
	bridge.release_checkpoint(held.value)
	bridge.dispose()
	print("[cpp_b00] failed=%d"%failed)
	quit(1 if failed else 0)

func shared_fixture(kind: String) -> Dictionary:
	var builder = load("res://tools/content/build_run_content.gd")
	var cfg = load("res://data/config.tres").duplicate(true)
	cfg.planet_radius = 0.0
	var definition = load("res://data/bosses/%s.tres"%kind).duplicate(true)
	definition.params.initial_wait = 0.0
	definition.params.entrance_time = 0.1
	definition.params.phase_time = 0.06
	var package: Dictionary = builder.boss_body_package(definition,cfg)
	var data: Dictionary = package.records
	if kind=="monoceros":
		var move = load("res://data/bosses/monoceros_moves/charge.tres").duplicate(true)
		var techniques: Dictionary = builder.boss_technique_records(definition,move)
		for key in techniques: data[key] = techniques[key]
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var bytes: PackedByteArray = builder.Schema.write_content(data,"0".repeat(64).hex_decode())
	if not bridge.configure(bytes,{"api_version":1,"run_id":147,"mode":1,"stage_id":"B_shared","profile":{},"settings":{"hitstop":false}}).ok: return {}
	bridge.start(147,{"position":Vector2(1000,0)})
	bridge.command("dev_ship_motion",{"position":Vector2(1000,0),"velocity":Vector2.ZERO})
	bridge._core.set_motion_context(Vector2(1000,0),Vector2(0,0),Vector2(640,360))
	var spawned: Dictionary = bridge.command("dev_spawn_boss",{"definition":1,"position":Vector2.ZERO,"entrance":true})
	if not spawned.ok: return {}
	return {"bridge":bridge,"id":spawned.value}

func shared_body(bridge) -> Dictionary: return bridge.command("dev_boss_body_state").value[0]
func shared_damage(bridge, id: int, amount: float) -> Dictionary:
	return bridge.command("dev_damage",{"entity_id":id,"amount":amount,"cause":"bullet"}).value

func check_cpp_shared() -> void:
	for kind in ["monoceros","centaurus"]:
		var fixture := shared_fixture(kind)
		check(not fixture.is_empty(),"共通入口から%s本体を生成する"%kind)
		if fixture.is_empty():
			quit(1)
			return
		var bridge = fixture.bridge
		var state := shared_body(bridge)
		check(state.mode==0 and state.position==Vector2(-1280,0) and state.boss_spawned,"実際の登場確定で出現済みを保持する")
		var damage := shared_damage(bridge,fixture.id,state.max_hp*0.6)
		state = shared_body(bridge)
		check(is_equal_approx(state.hp,state.max_hp*0.4) and state.pending and state.mode==0,"登場中も被弾し閾値を跨ぐ超過分を保持する")
		bridge._core.step(0.1)
		check(shared_body(bridge).mode==1 and shared_body(bridge).phase==1,"登場が自然に終わるtickでは形態を変えない")
		bridge._core.step(0.02)
		state = shared_body(bridge)
		check(state.phase==2 and state.mode==2 and is_equal_approx(state.hp,state.max_hp*0.4),"待機へ戻った次tickで同じ共通形態境界へ進む")
		var held: Dictionary = bridge.checkpoint()
		check(held.ok,"登場と形態の値状態を保持する")
		bridge._core.step(0.04)
		var expected := shared_body(bridge)
		bridge.restore(held.value)
		bridge._core.step(0.04)
		check(shared_body(bridge)==expected,"形態途中から同じ時計と残り時間へ復帰する")
		bridge.release_checkpoint(held.value)
		bridge._core.step(0.03)
		check(shared_body(bridge).mode==1,"形態移行を自然に終える")
		if kind=="monoceros":
			var started: Dictionary = bridge.command("dev_boss_technique",{"entity_id":fixture.id,"definition":1})
			check(started.ok and bridge.command("dev_boss_state").value[0].definition==2,"共通本体の現在形態から技の実効値を選ぶ")
		shared_damage(bridge,fixture.id,state.max_hp*2)
		bridge.command("dev_cancel_boss",{"entity_id":fixture.id})
		state = shared_body(bridge)
		var frame: Dictionary = bridge.read_frame()
		check(state.mode==4 and state.boss_spawned and shared_body(bridge).boss_dead and frame.ok,"自然撃破を先に確定し出現済みを戻さず通知を配信する")
		check(frame.value.events.filter(func(event): return event.type==&"boss_defeated").size()==1 and not frame.value.events.any(func(event): return event.type==&"boss_cancelled"),"撃破後の取消は決着を上書きしない")
		bridge.dispose()
		fixture = shared_fixture(kind)
		bridge = fixture.bridge
		bridge.command("dev_cancel_boss",{"entity_id":fixture.id})
		var position: Vector2 = shared_body(bridge).position
		bridge._core.step(0.3)
		shared_damage(bridge,fixture.id,shared_body(bridge).max_hp*2)
		frame = bridge.read_frame()
		check(shared_body(bridge).mode==5 and shared_body(bridge).position==position and not shared_body(bridge).boss_dead and frame.ok,"登場取消を先に確定した本体は後から決着を起こさない")
		bridge.dispose()
	var fixture := shared_fixture("monoceros")
	var bridge = fixture.bridge
	check(bridge.command("dev_boss_final",{"entity_id":fixture.id,"charge":0.1}).ok and not bridge.command("dev_boss_final",{"entity_id":fixture.id,"charge":0.1}).ok,"決着時計を一度だけ開始する")
	bridge._core.step(0.1)
	shared_body(bridge)
	var frame: Dictionary = bridge.read_frame()
	check(shared_body(bridge).final_landed and bridge._core.ship_snapshot().ship_hp<0.0 and frame.ok,"共通の決着時計が自然終了して強制一撃を一度だけ配信する")
	check(frame.value.events.any(func(event): return event.type==&"combat_player_damage" and event.payload.cause==&"final_strike" and event.payload.source==&"boss"),"決着の原因と出所を既存の記録契約へ渡す")
	bridge.dispose()
	fixture = shared_fixture("monoceros")
	bridge = fixture.bridge
	bridge.command("dev_boss_final",{"entity_id":fixture.id,"charge":0.1})
	bridge._core.step(0.05)
	bridge.command("dev_cancel_boss",{"entity_id":fixture.id})
	bridge._core.step(0.1)
	check(not shared_body(bridge).final_landed and bridge._core.ship_snapshot().ship_hp>0 and bridge.read_frame().ok,"取消後には決着時計を進めず強制一撃を出さない")
	bridge.dispose()
	print("[cpp_shared] failed=%d"%failed)
	quit(1 if failed else 0)

## 失敗した通知条件だけを同じ固定場面で確認し直す。
func check_cpp_shared_final_record() -> void:
	var fixture := shared_fixture("monoceros")
	var bridge = fixture.bridge
	bridge.command("dev_boss_final",{"entity_id":fixture.id,"charge":0.1})
	bridge._core.step(0.1)
	shared_body(bridge)
	var frame: Dictionary = bridge.read_frame()
	check(frame.ok and frame.value.events.any(func(event): return event.type==&"combat_player_damage" and event.payload.cause==&"final_strike" and event.payload.source==&"boss"),"決着の原因と出所を既存の記録契約へ渡す")
	bridge.dispose()
	print("[cpp_shared_final_record] failed=%d"%failed)
	quit(1 if failed else 0)
